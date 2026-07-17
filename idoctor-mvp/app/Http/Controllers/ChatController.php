<?php

namespace App\Http\Controllers;

use App\Models\ChatSession;
use App\Models\Message;
use App\Services\AuditLogger;
use App\Services\ChatOrchestrator;
use App\Services\TriageService;
use Illuminate\Http\Request;
use Illuminate\Support\Facades\RateLimiter;
use Illuminate\Support\Str;
use Symfony\Component\HttpFoundation\StreamedResponse;
use Throwable;

class ChatController extends Controller
{
    public function __construct(
        private readonly TriageService $triage,
        private readonly ChatOrchestrator $orchestrator,
        private readonly AuditLogger $audit,
    ) {}

    /**
     * The full chat pipeline (Rule #2 ordering):
     * rate-limit → triage → [emergency? 112 + STOP] → route → RAG → stream → audit
     */
    public function send(Request $request): StreamedResponse
    {
        $data = $request->validate([
            'session_id' => ['required', 'uuid'],
            'message' => ['required', 'string', 'max:4000'],
        ]);

        $session = ChatSession::findOrFail($data['session_id']);
        $text = trim($data['message']);

        return response()->stream(function () use ($session, $text) {
            // --- consent gate ----------------------------------------------
            if (! $session->consent_given) {
                $this->sse('error', ['message' => 'consent_required']);

                return;
            }

            // --- rate limit -------------------------------------------------
            $perMin = (int) config('idoctor.rate_limit.messages_per_minute', 12);
            $key = 'chat:'.$session->id;
            if (RateLimiter::tooManyAttempts($key, $perMin)) {
                $this->audit->event($session->id, 'chat.rate_limited', ['scope' => 'minute']);
                $this->sse('error', ['message' => 'rate_limited', 'retry_after' => RateLimiter::availableIn($key)]);

                return;
            }
            RateLimiter::hit($key, 60);

            // --- persist user message (encrypted at rest) -------------------
            $userMsg = $session->messages()->create([
                'role' => 'user',
                'content' => $text,
            ]);

            // --- Rule #2: TRIAGE BEFORE CLAUDE ------------------------------
            $verdict = $this->triage->detect($text);
            if ($verdict['emergency']) {
                $template = $this->emergencyTemplate($verdict['matched']);

                $session->messages()->create([
                    'role' => 'assistant',
                    'content' => $template,
                    'is_emergency' => true,
                    'triage_reason' => $verdict['reason'],
                ]);

                $this->audit->event($session->id, 'chat.emergency', [
                    'layer' => $verdict['layer'],
                    'reason' => $verdict['reason'],
                ]);

                // Emit the 112 screen and STOP — Claude is never called.
                $this->sse('emergency', ['text' => $template]);
                $this->sse('done', ['emergency' => true]);
                $this->touchSession($session, emergency: true);

                return;
            }

            // --- normal path: stream Claude --------------------------------
            $history = $this->recentHistory($session);
            $this->sse('start', ['message_id' => (string) Str::uuid()]);

            $full = '';
            try {
                $full = $this->orchestrator->streamReply(
                    $session,
                    $history,
                    $text,
                    fn (string $delta) => $this->sse('delta', ['text' => $delta]),
                );
            } catch (Throwable $e) {
                $this->audit->event($session->id, 'chat.llm_error', [
                    'error' => substr($e->getMessage(), 0, 120),
                ]);
                $this->sse('error', ['message' => 'llm_unavailable']);

                return;
            }

            // --- disclaimer on EVERY medical answer ------------------------
            $disclaimer = (string) config('idoctor.disclaimer');
            $this->sse('disclaimer', ['text' => $disclaimer]);

            $assistantMsg = $session->messages()->create([
                'role' => 'assistant',
                'content' => $full."\n\n".$disclaimer,
                'model_used' => $this->orchestrator->lastModel,
            ]);

            $this->audit->event($session->id, 'chat.reply', [
                'chars' => mb_strlen($full),
            ]);

            $this->touchSession($session);
            $this->sse('done', [
                'emergency' => false,
                'message_id' => $assistantMsg->id,
                'show_visit_card' => $session->anamnesis_stage === 'ready',
            ]);
        }, 200, [
            'Content-Type' => 'text/event-stream',
            'Cache-Control' => 'no-cache, no-transform',
            'X-Accel-Buffering' => 'no',
            'Connection' => 'keep-alive',
        ]);
    }

    private function emergencyTemplate(?string $category): string
    {
        $base = (string) config('idoctor.triage.emergency_template');

        // Suicide/self-harm phrasings get the crisis hotline addendum.
        $suicideHints = ['ცხოვრება', 'მოკვლა', 'tavis mokvla', 'cxovreba'];
        foreach ($suicideHints as $hint) {
            if ($category && Str::contains(Str::lower($category), Str::lower($hint))) {
                return $base."\n\n".config('idoctor.triage.crisis_hotline_template');
            }
        }

        return $base;
    }

    /**
     * @return array<int,array{role:string,content:string}>
     */
    private function recentHistory(ChatSession $session): array
    {
        return $session->messages()
            ->where('is_emergency', false)
            ->orderByDesc('created_at')
            ->limit(10)
            ->get()
            ->reverse()
            ->map(fn (Message $m) => ['role' => $m->role, 'content' => $m->content])
            ->values()
            ->all();
    }

    /**
     * Advance the lightweight anamnesis state machine and bookkeeping.
     */
    private function touchSession(ChatSession $session, bool $emergency = false): void
    {
        $session->message_count = $session->messages()->where('role', 'user')->count();
        $session->last_seen_at = now();

        // After a few substantive user turns (and not an emergency), the
        // visit card becomes available.
        if (! $emergency && $session->message_count >= 3 && $session->anamnesis_stage !== 'ready') {
            $session->anamnesis_stage = 'ready';
        }

        $session->save();
    }

    private function sse(string $event, array $data): void
    {
        echo 'event: '.$event."\n";
        echo 'data: '.json_encode($data, JSON_UNESCAPED_UNICODE)."\n\n";

        if (ob_get_level() > 0) {
            @ob_flush();
        }
        @flush();
    }
}

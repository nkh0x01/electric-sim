<?php

namespace App\Console\Commands;

use App\Models\ChatSession;
use App\Models\Feedback;
use App\Models\LabUpload;
use App\Models\Message;
use App\Models\MessageKbReference;
use App\Models\VisitCard;
use Illuminate\Console\Command;

/**
 * Content-free product metrics (Rule #3 friendly): every number here is a
 * count or rate — never message content. Useful for the closed-beta
 * MAU / triage-rate / NPS-proxy tracking called for in the strategy.
 *
 *   php artisan idoctor:metrics --days=7
 */
class Metrics extends Command
{
    protected $signature = 'idoctor:metrics {--days=7 : Window in days}';

    protected $description = 'Report content-free product metrics for iDoctor.';

    public function handle(): int
    {
        $days = max(1, (int) $this->option('days'));
        $since = now()->subDays($days);

        $sessions = ChatSession::where('created_at', '>=', $since)->count();
        $active = ChatSession::where('last_seen_at', '>=', $since)->count();
        $consented = ChatSession::where('consent_given', true)
            ->where('created_at', '>=', $since)->count();

        $userMsgs = Message::where('role', 'user')->where('created_at', '>=', $since)->count();
        $emergencies = Message::where('is_emergency', true)->where('created_at', '>=', $since)->count();

        $labs = LabUpload::where('created_at', '>=', $since)->count();
        $labsParsed = LabUpload::where('status', 'parsed')->where('created_at', '>=', $since)->count();
        $cards = VisitCard::where('created_at', '>=', $since)->count();

        $fbUp = Feedback::where('kind', 'up')->where('created_at', '>=', $since)->count();
        $fbDown = Feedback::where('kind', 'down')->where('created_at', '>=', $since)->count();
        $fbRep = Feedback::where('kind', 'report')->where('created_at', '>=', $since)->count();

        $emergencyRate = $userMsgs > 0 ? $emergencies / $userMsgs : 0.0;
        $consentRate = $sessions > 0 ? $consented / $sessions : 0.0;
        $satisfaction = ($fbUp + $fbDown) > 0 ? $fbUp / ($fbUp + $fbDown) : 0.0;

        // --- value loop: response time -------------------------------------
        $assistant = Message::where('role', 'assistant')
            ->where('created_at', '>=', $since);
        $avgLatency = (float) (clone $assistant)->whereNotNull('latency_ms')->avg('latency_ms');

        // --- value loop: model mix + estimated API cost --------------------
        $cheapModel = (string) config('idoctor.models.cheap');
        $premiumModel = (string) config('idoctor.models.premium');
        $cheapReplies = (clone $assistant)->where('model_used', $cheapModel)->count();
        $premiumReplies = (clone $assistant)->where('model_used', $premiumModel)->count();
        $costCheap = (float) config('idoctor.costs.per_reply_usd.cheap', 0.0);
        $costPremium = (float) config('idoctor.costs.per_reply_usd.premium', 0.0);
        $estCost = $cheapReplies * $costCheap + $premiumReplies * $costPremium;
        $costPerSession = $sessions > 0 ? $estCost / $sessions : 0.0;

        $this->info("iDoctor metrics — last {$days} day(s)");
        $this->table(['metric', 'value'], [
            ['sessions created',       $sessions],
            ['active sessions',        $active],
            ['consent rate',           sprintf('%.1f%%', $consentRate * 100)],
            ['user messages',          $userMsgs],
            ['emergency screens',      $emergencies],
            ['triage activation rate', sprintf('%.2f%%', $emergencyRate * 100)],
            ['lab uploads',            "$labsParsed/$labs parsed"],
            ['visit cards',            $cards],
            ['feedback 👍/👎/⚠',        "$fbUp / $fbDown / $fbRep"],
            ['satisfaction (👍 share)',  sprintf('%.1f%%', $satisfaction * 100)],
            ['avg response time',      $avgLatency > 0 ? sprintf('%.0f ms', $avgLatency) : '—'],
            ['replies cheap/premium',  "$cheapReplies / $premiumReplies"],
            ['est. API cost',          sprintf('$%.2f', $estCost)],
            ['est. cost / session',    sprintf('$%.4f', $costPerSession)],
        ]);

        $this->renderTopSpecialties($since);

        return self::SUCCESS;
    }

    /**
     * Content-free "most common topics": which KB specialties the retriever
     * surfaced most. Derived entirely from KB reference ids — no message text.
     */
    private function renderTopSpecialties(\DateTimeInterface $since): void
    {
        $rows = MessageKbReference::query()
            ->where('created_at', '>=', $since)
            ->whereNotNull('specialty')
            ->selectRaw('specialty, count(*) as c')
            ->groupBy('specialty')
            ->orderByDesc('c')
            ->limit(10)
            ->get();

        if ($rows->isEmpty()) {
            return;
        }

        $this->line('');
        $this->info('Top topics (by KB specialty retrieved):');
        $this->table(
            ['specialty', 'retrievals'],
            $rows->map(fn ($r) => [$r->specialty, (int) $r->c])->all(),
        );
    }
}

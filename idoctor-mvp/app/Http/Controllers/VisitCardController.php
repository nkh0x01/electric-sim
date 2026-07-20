<?php

namespace App\Http\Controllers;

use App\Models\ChatSession;
use App\Models\Message;
use App\Models\VisitCard;
use App\Services\AuditLogger;
use App\Services\ClaudeClient;
use Barryvdh\DomPDF\Facade\Pdf;
use Illuminate\Http\JsonResponse;
use Illuminate\Http\Request;
use Symfony\Component\HttpFoundation\Response;

class VisitCardController extends Controller
{
    public function __construct(
        private readonly ClaudeClient $claude,
        private readonly AuditLogger $audit,
    ) {}

    /**
     * Summarise the anamnesis into a structured visit card the patient can
     * take to a doctor.
     */
    public function generate(Request $request): JsonResponse
    {
        $data = $request->validate(['session_id' => ['required', 'uuid']]);
        $session = ChatSession::findOrFail($data['session_id']);
        abort_unless($session->consent_given, 403, 'consent_required');

        $transcript = $session->messages()
            ->where('is_emergency', false)
            ->orderBy('created_at')
            ->get()
            ->map(fn (Message $m) => strtoupper($m->role).': '.$m->content)
            ->implode("\n");

        $system = <<<'PROMPT'
        You produce a concise "visit card" (ვიზიტის ბარათი) in Georgian from a health
        chat transcript, to hand to a doctor. You are NOT a doctor and give no diagnosis.
        Return ONLY JSON:
        {"summary":"<2-4 sentence chief complaint + anamnesis, Georgian>",
         "symptoms":["<symptom>", ...],
         "questions_for_doctor":["<question the patient should ask>", ...],
         "suggested_specialty":"<one of: gynecology, urology, sti, endocrinology, general>"}
        PROMPT;

        $raw = $this->claude->complete(
            system: $system,
            messages: [['role' => 'user', 'content' => $transcript]],
            model: (string) config('idoctor.models.premium'),
            maxTokens: 900,
        );

        $parsed = [];
        if (preg_match('/\{.*\}/s', $raw, $m)) {
            $parsed = json_decode($m[0], true) ?: [];
        }

        $card = $session->visitCards()->create([
            'summary' => (string) ($parsed['summary'] ?? ''),
            'symptoms' => (array) ($parsed['symptoms'] ?? []),
            'questions_for_doctor' => (array) ($parsed['questions_for_doctor'] ?? []),
            'suggested_specialty' => (string) ($parsed['suggested_specialty'] ?? 'general'),
        ]);

        $this->audit->event($session->id, 'visit_card.generated');

        return response()->json([
            'id' => $card->id,
            'summary' => $card->summary,
            'symptoms' => $card->symptoms,
            'questions_for_doctor' => $card->questions_for_doctor,
            'suggested_specialty' => $card->suggested_specialty,
            'pdf_url' => route('visit-card.pdf', $card),
        ]);
    }

    /**
     * Render the visit card as a Georgian-capable PDF (DejaVu Sans).
     */
    public function pdf(VisitCard $card): Response
    {
        $pdf = Pdf::loadView('pdf.visit-card', [
            'card' => $card,
            'disclaimer' => config('idoctor.disclaimer'),
            'generated' => $card->created_at,
        ])->setOptions([
            'defaultFont' => 'DejaVu Sans', // ships Georgian glyphs
            'isRemoteEnabled' => false,
        ]);

        return $pdf->download('visit-card-'.$card->id.'.pdf');
    }
}

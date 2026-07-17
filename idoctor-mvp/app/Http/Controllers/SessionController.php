<?php

namespace App\Http\Controllers;

use App\Models\ChatSession;
use App\Services\AuditLogger;
use Illuminate\Http\JsonResponse;
use Illuminate\Http\Request;
use Illuminate\Support\Str;

class SessionController extends Controller
{
    public function __construct(private readonly AuditLogger $audit) {}

    /**
     * Create an anonymous session (no registration).
     */
    public function store(Request $request): JsonResponse
    {
        $session = new ChatSession([
            'locale' => $request->input('locale', 'ka'),
            'anamnesis_stage' => 'intake',
            'last_seen_at' => now(),
        ]);
        $session->id = (string) Str::uuid();
        $session->session_hash = AuditLogger::hash($session->id);
        $session->save();

        $this->audit->event($session->id, 'session.created');

        return response()->json([
            'session_id' => $session->id,
            'consent_given' => false,
        ]);
    }

    /**
     * Record informed consent before any medical exchange.
     */
    public function consent(Request $request, ChatSession $session): JsonResponse
    {
        $session->update([
            'consent_given' => true,
            'consent_at' => now(),
        ]);
        $this->audit->event($session->id, 'session.consent');

        return response()->json(['consent_given' => true]);
    }

    /**
     * GDPR erasure — deletes the session and every child row (messages,
     * uploads, visit cards cascade). DELETE /api/session/{session}/data
     */
    public function destroyData(ChatSession $session): JsonResponse
    {
        $id = $session->id;

        // Cascade delete handles messages / lab_uploads / visit_cards.
        $session->delete();

        $this->audit->event($id, 'session.erased');

        return response()->json(['deleted' => true]);
    }
}

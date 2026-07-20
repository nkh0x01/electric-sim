<?php

namespace App\Services;

use App\Models\Message;
use App\Models\TriageMiss;

/**
 * Safety loop: when a user is unhappy with a NON-emergency answer (a 👎 or a
 * report), the message triage cleared may be a false negative — an emergency
 * it missed. Capture it (pseudonymised session, encrypted text) for human
 * review; idoctor:triage-harvest folds reviewed misses into the red-flag test
 * suite so the same miss cannot recur.
 */
class TriageMissRecorder
{
    public function captureFromFeedback(string $sessionId, ?string $messageId): void
    {
        if ($messageId === null) {
            return;
        }

        $msg = Message::find($messageId);
        // Only assistant answers that triage did NOT flag are candidate misses.
        if ($msg === null || $msg->role !== 'assistant' || $msg->is_emergency) {
            return;
        }

        // The user message that triage cleared is the one just before the answer.
        $userMsg = Message::query()
            ->where('chat_session_id', $msg->chat_session_id)
            ->where('role', 'user')
            ->where('created_at', '<=', $msg->created_at)
            ->latest('created_at')
            ->first();
        if ($userMsg === null) {
            return;
        }

        $messageHash = AuditLogger::hash($userMsg->id);
        if (TriageMiss::where('message_hash', $messageHash)->exists()) {
            return; // already captured
        }

        TriageMiss::create([
            'session_hash' => AuditLogger::hash($sessionId),
            'message_hash' => $messageHash,
            'text' => $userMsg->content,   // encrypted at rest by the model cast
            'expected_category' => null,   // a human assigns this on review
            'source' => 'feedback',
            'status' => 'new',
        ]);
    }
}

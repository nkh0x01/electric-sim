<?php

namespace App\Http\Controllers;

use App\Models\Feedback;
use App\Services\AuditLogger;
use App\Services\TriageMissRecorder;
use Illuminate\Http\JsonResponse;
use Illuminate\Http\Request;

class FeedbackController extends Controller
{
    public function __construct(
        private readonly AuditLogger $audit,
        private readonly TriageMissRecorder $misses,
    ) {}

    public function store(Request $request): JsonResponse
    {
        $data = $request->validate([
            'session_id' => ['required', 'uuid'],
            'message_id' => ['nullable', 'uuid'],
            'kind' => ['required', 'in:up,down,report'],
            'note' => ['nullable', 'string', 'max:1000'],
        ]);

        $feedback = Feedback::create([
            'chat_session_id' => $data['session_id'],
            'message_id' => $data['message_id'] ?? null,
            'kind' => $data['kind'],
            'note' => $data['note'] ?? null,
        ]);

        $this->audit->event($data['session_id'], 'feedback.'.$data['kind']);

        // Safety loop: a 👎/report on a non-emergency answer may be a triage miss.
        if (in_array($data['kind'], ['down', 'report'], true)) {
            $this->misses->captureFromFeedback($data['session_id'], $data['message_id'] ?? null);
        }

        return response()->json(['id' => $feedback->id, 'ok' => true]);
    }
}

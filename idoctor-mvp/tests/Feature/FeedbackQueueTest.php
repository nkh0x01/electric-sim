<?php

namespace Tests\Feature;

use App\Models\ChatSession;
use App\Models\Feedback;
use App\Models\KbDocument;
use App\Models\MessageKbReference;
use App\Services\AuditLogger;
use Illuminate\Foundation\Testing\RefreshDatabase;
use Illuminate\Support\Str;
use PHPUnit\Framework\Attributes\Group;
use Tests\TestCase;

/**
 * Quality loop: the review queue surfaces unreviewed 👎/report feedback and can
 * mark items reviewed. It shows content-free KB grounding (doc slugs), never
 * the encrypted conversation.
 */
#[Group('feedback')]
class FeedbackQueueTest extends TestCase
{
    use RefreshDatabase;

    private function makeSession(): ChatSession
    {
        $id = (string) Str::uuid();

        return ChatSession::create([
            'id' => $id,
            'session_hash' => AuditLogger::hash($id),
            'consent_given' => true,
        ]);
    }

    public function test_queue_lists_unreviewed_down_and_report(): void
    {
        $s = $this->makeSession();
        $answer = $s->messages()->create(['role' => 'assistant', 'content' => 'reply', 'model_used' => 'claude-haiku-4-5']);

        Feedback::create(['chat_session_id' => $s->id, 'message_id' => $answer->id, 'kind' => 'down']);
        Feedback::create(['chat_session_id' => $s->id, 'message_id' => $answer->id, 'kind' => 'report']);
        // 👍 must never appear in the review queue.
        Feedback::create(['chat_session_id' => $s->id, 'message_id' => $answer->id, 'kind' => 'up']);

        $this->artisan('idoctor:feedback-queue')
            ->expectsOutputToContain('2 item(s) to review')
            ->assertExitCode(0);
    }

    public function test_queue_flags_unreviewed_kb_docs_used_by_a_bad_answer(): void
    {
        $s = $this->makeSession();
        $answer = $s->messages()->create(['role' => 'assistant', 'content' => 'reply']);

        // A placeholder KB doc (reviewed_by null) grounded the downvoted answer.
        $doc = KbDocument::create([
            'slug' => 'endo-testosterone', 'title' => 'ტესტოსტერონი',
            'specialty' => 'endocrinology', 'body' => '...', 'reviewed_by' => null,
        ]);
        MessageKbReference::create([
            'message_id' => $answer->id, 'kb_document_id' => $doc->id,
            'specialty' => 'endocrinology', 'score' => 0.42,
        ]);

        Feedback::create(['chat_session_id' => $s->id, 'message_id' => $answer->id, 'kind' => 'down']);

        $this->artisan('idoctor:feedback-queue')
            ->expectsOutputToContain('endo-testosterone')
            ->assertExitCode(0);
    }

    public function test_mark_reviewed_removes_item_from_default_queue(): void
    {
        $s = $this->makeSession();
        $answer = $s->messages()->create(['role' => 'assistant', 'content' => 'reply']);
        $fb = Feedback::create(['chat_session_id' => $s->id, 'message_id' => $answer->id, 'kind' => 'down']);

        $this->artisan('idoctor:feedback-queue', ['--mark' => $fb->id])->assertExitCode(0);
        $this->assertNotNull($fb->fresh()->reviewed_at);

        $this->artisan('idoctor:feedback-queue')
            ->expectsOutputToContain('queue is empty')
            ->assertExitCode(0);
    }
}

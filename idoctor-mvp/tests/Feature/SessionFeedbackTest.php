<?php

namespace Tests\Feature;

use App\Models\ChatSession;
use App\Models\Feedback;
use App\Models\Message;
use App\Services\AuditLogger;
use Illuminate\Foundation\Testing\RefreshDatabase;
use Illuminate\Support\Str;
use PHPUnit\Framework\Attributes\Group;
use Tests\TestCase;

#[Group('session')]
class SessionFeedbackTest extends TestCase
{
    use RefreshDatabase;

    public function test_anonymous_session_is_created_without_consent(): void
    {
        $res = $this->postJson('/api/session', []);

        $res->assertOk()
            ->assertJsonPath('consent_given', false)
            ->assertJsonStructure(['session_id', 'consent_given']);

        $this->assertDatabaseCount('chat_sessions', 1);
        // session_hash is the HMAC of the id — never the id itself.
        $session = ChatSession::first();
        $this->assertSame(AuditLogger::hash($session->id), $session->session_hash);
        $this->assertNotSame($session->id, $session->session_hash);
    }

    public function test_consent_is_recorded(): void
    {
        $id = (string) Str::uuid();
        $session = ChatSession::create([
            'id' => $id, 'session_hash' => AuditLogger::hash($id), 'consent_given' => false,
        ]);

        $this->postJson("/api/session/{$session->id}/consent")
            ->assertOk()
            ->assertJsonPath('consent_given', true);

        $this->assertTrue($session->fresh()->consent_given);
        $this->assertNotNull($session->fresh()->consent_at);
    }

    public function test_gdpr_delete_removes_session_and_all_child_rows(): void
    {
        $id = (string) Str::uuid();
        $session = ChatSession::create([
            'id' => $id, 'session_hash' => AuditLogger::hash($id), 'consent_given' => true,
        ]);
        $session->messages()->create(['role' => 'user', 'content' => 'secret content']);
        $session->messages()->create(['role' => 'assistant', 'content' => 'reply']);

        $this->assertDatabaseCount('messages', 2);

        $this->deleteJson("/api/session/{$session->id}/data")
            ->assertOk()
            ->assertJsonPath('deleted', true);

        // Cascade: the session and every message are gone (right to erasure).
        $this->assertDatabaseCount('chat_sessions', 0);
        $this->assertDatabaseCount('messages', 0);
    }

    public function test_message_content_is_encrypted_at_rest(): void
    {
        $id = (string) Str::uuid();
        $session = ChatSession::create([
            'id' => $id, 'session_hash' => AuditLogger::hash($id), 'consent_given' => true,
        ]);
        $plain = 'ორსული ვარ და მაწუხებს';
        $msg = $session->messages()->create(['role' => 'user', 'content' => $plain]);

        // The accessor decrypts...
        $this->assertSame($plain, $msg->fresh()->content);
        // ...but the raw column value is ciphertext, not the plaintext.
        $raw = \DB::table('messages')->where('id', $msg->id)->value('content');
        $this->assertNotSame($plain, $raw);
        $this->assertStringNotContainsString('ორსული', $raw);
    }

    #[Group('feedback')]
    public function test_feedback_is_stored_for_each_kind(): void
    {
        $id = (string) Str::uuid();
        $session = ChatSession::create([
            'id' => $id, 'session_hash' => AuditLogger::hash($id), 'consent_given' => true,
        ]);
        $msg = $session->messages()->create(['role' => 'assistant', 'content' => 'hi']);

        foreach (['up', 'down', 'report'] as $kind) {
            $this->postJson('/api/feedback', [
                'session_id' => $session->id,
                'message_id' => $msg->id,
                'kind' => $kind,
                'note' => $kind === 'report' ? 'არასწორია' : null,
            ])->assertOk()->assertJsonPath('ok', true);
        }

        $this->assertSame(3, Feedback::count());
        $this->assertSame(1, Feedback::where('kind', 'report')->count());
    }

    public function test_feedback_rejects_unknown_kind(): void
    {
        $id = (string) Str::uuid();
        ChatSession::create(['id' => $id, 'session_hash' => AuditLogger::hash($id), 'consent_given' => true]);

        $this->postJson('/api/feedback', [
            'session_id' => $id,
            'kind' => 'sideways',
        ])->assertStatus(422);
    }
}

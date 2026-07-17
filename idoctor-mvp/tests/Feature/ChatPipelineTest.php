<?php

namespace Tests\Feature;

use App\Models\ChatSession;
use App\Services\AuditLogger;
use Illuminate\Foundation\Testing\RefreshDatabase;
use Illuminate\Support\Str;
use PHPUnit\Framework\Attributes\Group;
use Tests\TestCase;

/**
 * HTTP-layer tests for the chat pipeline. These deliberately run WITHOUT an
 * Anthropic key: the emergency path (Rule #2) short-circuits before Claude,
 * and the consent/rate-limit gates never reach the model — so they prove the
 * safety-critical behaviour deterministically.
 */
#[Group('pipeline')]
class ChatPipelineTest extends TestCase
{
    use RefreshDatabase;

    private function consentedSession(): ChatSession
    {
        $id = (string) Str::uuid();

        return ChatSession::create([
            'id' => $id,
            'session_hash' => AuditLogger::hash($id),
            'consent_given' => true,
            'consent_at' => now(),
            'anamnesis_stage' => 'intake',
            'last_seen_at' => now(),
        ]);
    }

    public function test_emergency_message_returns_112_and_never_calls_claude(): void
    {
        // No ANTHROPIC_API_KEY on purpose: if the pipeline tried to call Claude
        // it would error. A clean 112 screen proves triage stopped first (Rule #2).
        config(['services.anthropic.key' => '']);
        $session = $this->consentedSession();

        $response = $this->postJson('/api/chat', [
            'session_id' => $session->id,
            'message' => 'ძლიერი გულმკერდის ტკივილი მაქვს რა ვქნა?',
        ]);

        $response->assertOk();
        $body = $response->streamedContent();

        $this->assertStringContainsString('event: emergency', $body);
        $this->assertStringContainsString('112', $body);
        $this->assertStringNotContainsString('event: delta', $body, 'Claude must not stream on an emergency');

        // An emergency assistant message is persisted and flagged.
        $this->assertDatabaseHas('messages', [
            'chat_session_id' => $session->id,
            'role' => 'assistant',
            'is_emergency' => true,
        ]);
    }

    public function test_suicide_message_adds_crisis_hotline(): void
    {
        config(['services.anthropic.key' => '']);
        $session = $this->consentedSession();

        $body = $this->postJson('/api/chat', [
            'session_id' => $session->id,
            'message' => 'აღარ მინდა ცხოვრება',
        ])->streamedContent();

        $this->assertStringContainsString('event: emergency', $body);
        // Crisis addendum references a mental-health crisis line.
        $this->assertStringContainsString('კრიზისულ', $body);
    }

    public function test_unconsented_session_is_blocked_before_any_processing(): void
    {
        $id = (string) Str::uuid();
        $session = ChatSession::create([
            'id' => $id,
            'session_hash' => AuditLogger::hash($id),
            'consent_given' => false,
            'anamnesis_stage' => 'intake',
        ]);

        $body = $this->postJson('/api/chat', [
            'session_id' => $session->id,
            'message' => 'გამარჯობა',
        ])->streamedContent();

        $this->assertStringContainsString('consent_required', $body);
        $this->assertDatabaseCount('messages', 0);
    }

    public function test_rate_limit_kicks_in_after_configured_threshold(): void
    {
        config(['services.anthropic.key' => '', 'idoctor.rate_limit.messages_per_minute' => 2]);
        $session = $this->consentedSession();

        // Two emergency messages are allowed (they don't call Claude)...
        for ($i = 0; $i < 2; $i++) {
            $this->postJson('/api/chat', [
                'session_id' => $session->id,
                'message' => 'ძლიერი გულმკერდის ტკივილი მაქვს',
            ])->streamedContent();
        }
        // ...the third is rate-limited.
        $body = $this->postJson('/api/chat', [
            'session_id' => $session->id,
            'message' => 'ძლიერი გულმკერდის ტკივილი მაქვს',
        ])->streamedContent();

        $this->assertStringContainsString('rate_limited', $body);
    }

    public function test_invalid_payload_is_rejected(): void
    {
        $this->postJson('/api/chat', ['session_id' => 'not-a-uuid'])
            ->assertStatus(422);
    }
}

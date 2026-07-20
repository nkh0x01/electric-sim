<?php

namespace Tests\Feature;

use App\Models\ChatSession;
use App\Models\TriageMiss;
use App\Services\AuditLogger;
use Illuminate\Foundation\Testing\RefreshDatabase;
use Illuminate\Support\Str;
use PHPUnit\Framework\Attributes\Group;
use Tests\TestCase;

/**
 * Safety loop: a 👎/report on a non-emergency answer captures the preceding
 * user message as a candidate triage miss — pseudonymised and encrypted.
 */
#[Group('triage')]
class TriageMissTest extends TestCase
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

    public function test_down_on_non_emergency_answer_records_a_miss(): void
    {
        $s = $this->makeSession();
        $s->messages()->create(['role' => 'user', 'content' => 'ძლიერი გულმკერდის ტკივილი მაქვს']);
        $asst = $s->messages()->create(['role' => 'assistant', 'content' => 'reply', 'is_emergency' => false]);

        $this->postJson('/api/feedback', [
            'session_id' => $s->id, 'message_id' => $asst->id, 'kind' => 'down',
        ])->assertOk();

        $this->assertSame(1, TriageMiss::count());
        $miss = TriageMiss::first();
        $this->assertSame('feedback', $miss->source);
        $this->assertSame('new', $miss->status);
        // text decrypts back to the user message; session_hash is not the raw id.
        $this->assertStringContainsString('გულმკერდის', $miss->text);
        $this->assertNotSame($s->id, $miss->session_hash);
    }

    public function test_no_miss_when_answer_was_an_emergency(): void
    {
        $s = $this->makeSession();
        $s->messages()->create(['role' => 'user', 'content' => 'გამარჯობა']);
        $asst = $s->messages()->create(['role' => 'assistant', 'content' => '112', 'is_emergency' => true]);

        $this->postJson('/api/feedback', [
            'session_id' => $s->id, 'message_id' => $asst->id, 'kind' => 'report',
        ])->assertOk();

        $this->assertSame(0, TriageMiss::count());
    }

    public function test_harvest_dry_run_runs(): void
    {
        $this->artisan('idoctor:triage-harvest')->assertExitCode(0);
    }
}

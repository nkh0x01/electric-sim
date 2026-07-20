<?php

namespace Tests\Feature;

use App\Models\ChatSession;
use App\Models\LabUpload;
use App\Models\User;
use App\Services\AuditLogger;
use Illuminate\Foundation\Testing\RefreshDatabase;
use Illuminate\Support\Facades\Hash;
use Illuminate\Support\Str;
use PHPUnit\Framework\Attributes\Group;
use Tests\TestCase;

/**
 * Prompt 4: optional accounts + lab history/trends. Accounts never gate the
 * anonymous flow; they only add persistent, deterministic lab history.
 */
#[Group('account')]
class AccountTest extends TestCase
{
    use RefreshDatabase;

    private function register(string $email = 'a@b.ge'): string
    {
        return $this->postJson('/api/account/register', [
            'email' => $email, 'password' => 'password123',
        ])->assertCreated()->json('token');
    }

    private function auth(string $token): array
    {
        return ['Authorization' => "Bearer {$token}"];
    }

    private function anonSession(): ChatSession
    {
        $id = (string) Str::uuid();

        return ChatSession::create([
            'id' => $id,
            'session_hash' => AuditLogger::hash($id),
            'consent_given' => true,
        ]);
    }

    private function parsedUpload(ChatSession $s, string $date, float $glu, string $flag): LabUpload
    {
        return LabUpload::create([
            'id' => (string) Str::uuid(),
            'chat_session_id' => $s->id,
            'user_id' => $s->user_id,
            'original_name' => 'labs.jpg', 'mime' => 'image/jpeg',
            'storage_path' => 'x', 'status' => 'parsed',
            'created_at' => $date, 'updated_at' => $date,
            'classified' => [[
                'code' => 'GLU', 'name' => 'გლუკოზა', 'value' => $glu, 'unit' => 'mmol/L',
                'value_in_ref_unit' => $glu, 'ref_low' => 3.9, 'ref_high' => 5.5,
                'flag' => $flag, 'needs_review' => false,
            ]],
        ]);
    }

    public function test_register_then_protected_route_requires_token(): void
    {
        $token = $this->register();

        $this->getJson('/api/account')->assertUnauthorized();
        $this->getJson('/api/account', $this->auth($token))
            ->assertOk()->assertJsonPath('user.email', 'a@b.ge');
    }

    public function test_login_rejects_wrong_password(): void
    {
        User::create(['name' => '', 'email' => 'c@d.ge', 'password' => Hash::make('password123')]);

        $this->postJson('/api/account/login', ['email' => 'c@d.ge', 'password' => 'nope'])
            ->assertStatus(422);
        $this->postJson('/api/account/login', ['email' => 'c@d.ge', 'password' => 'password123'])
            ->assertOk()->assertJsonStructure(['token', 'user']);
    }

    public function test_claim_session_links_labs_into_history(): void
    {
        $token = $this->register();
        $session = $this->anonSession();
        $this->parsedUpload($session, '2026-01-01', 5.0, 'normal');

        $this->postJson('/api/account/claim-session', ['session_id' => $session->id], $this->auth($token))
            ->assertOk()->assertJsonPath('labs', 1);

        $this->getJson('/api/account/labs', $this->auth($token))
            ->assertOk()->assertJsonCount(1, 'uploads')
            ->assertJsonPath('uploads.0.analytes', 1);
    }

    public function test_cannot_claim_a_session_owned_by_another_account(): void
    {
        $mine = $this->register('me@x.ge');
        $other = $this->register('other@x.ge');

        $session = $this->anonSession();
        $this->postJson('/api/account/claim-session', ['session_id' => $session->id], $this->auth($other))->assertOk();
        $this->postJson('/api/account/claim-session', ['session_id' => $session->id], $this->auth($mine))
            ->assertStatus(409);
    }

    public function test_trends_are_deterministic_and_carry_rule1_flags(): void
    {
        $token = $this->register();
        $user = User::where('email', 'a@b.ge')->first();
        $s = $this->anonSession();
        $s->update(['user_id' => $user->id]);

        $this->parsedUpload($s, '2026-01-01', 5.0, 'normal');
        $this->parsedUpload($s, '2026-03-01', 6.4, 'high');

        $trends = $this->getJson('/api/account/labs/trends', $this->auth($token))
            ->assertOk()->json('trends');

        $this->assertCount(1, $trends);          // one analyte (GLU)
        $this->assertSame('GLU', $trends[0]['code']);
        $this->assertCount(2, $trends[0]['points']);
        // Oldest→newest, flags copied straight from the stored classification.
        $this->assertSame('normal', $trends[0]['points'][0]['flag']);
        $this->assertSame('high', $trends[0]['points'][1]['flag']);
        $this->assertEqualsWithDelta(5.0, $trends[0]['points'][0]['value'], 0.001);
    }

    public function test_account_labs_survive_session_erasure(): void
    {
        $token = $this->register();
        $user = User::where('email', 'a@b.ge')->first();
        $s = $this->anonSession();
        $s->update(['user_id' => $user->id]);
        $this->parsedUpload($s, '2026-01-01', 5.0, 'normal');

        // GDPR erase the session — the account's lab history must remain.
        $this->deleteJson("/api/session/{$s->id}/data")->assertOk();

        $this->getJson('/api/account/labs', $this->auth($token))
            ->assertOk()->assertJsonCount(1, 'uploads');
    }
}

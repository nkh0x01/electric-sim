<?php

namespace Tests\Feature;

use App\Models\ChatSession;
use App\Models\MessageKbReference;
use App\Services\AuditLogger;
use Illuminate\Foundation\Testing\RefreshDatabase;
use Illuminate\Support\Str;
use PHPUnit\Framework\Attributes\Group;
use Tests\TestCase;

/**
 * Value loop: idoctor:metrics reports content-free product signals including
 * response time, model mix / estimated cost, and the most-retrieved KB
 * specialties. It must run cleanly on both empty and populated data.
 */
#[Group('metrics')]
class MetricsTest extends TestCase
{
    use RefreshDatabase;

    public function test_metrics_runs_on_empty_data(): void
    {
        $this->artisan('idoctor:metrics')->assertExitCode(0);
    }

    public function test_metrics_reports_latency_and_top_specialties(): void
    {
        $id = (string) Str::uuid();
        $s = ChatSession::create([
            'id' => $id, 'session_hash' => AuditLogger::hash($id), 'consent_given' => true,
        ]);

        $answer = $s->messages()->create([
            'role' => 'assistant', 'content' => 'reply',
            'model_used' => config('idoctor.models.premium'), 'latency_ms' => 1200,
        ]);
        MessageKbReference::create([
            'message_id' => $answer->id, 'specialty' => 'endocrinology', 'score' => 0.5,
        ]);

        $this->artisan('idoctor:metrics')
            ->expectsOutputToContain('Top topics')
            ->assertExitCode(0);
    }
}

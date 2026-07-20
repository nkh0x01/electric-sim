<?php

namespace Tests\Feature;

use App\Models\KbDocument;
use Database\Seeders\KbSeeder;
use Database\Seeders\LabReferenceRangeSeeder;
use Illuminate\Foundation\Testing\RefreshDatabase;
use PHPUnit\Framework\Attributes\Group;
use Tests\TestCase;

#[Group('mvp')]
class HealthAndKbTest extends TestCase
{
    use RefreshDatabase;

    public function test_health_is_ok_once_lab_ranges_are_seeded(): void
    {
        $this->seed(LabReferenceRangeSeeder::class);

        $res = $this->getJson('/api/health');
        $res->assertOk()
            ->assertJsonPath('status', 'ok')
            ->assertJsonPath('checks.db', true)
            ->assertJsonPath('checks.lab_ranges', true)
            ->assertJsonPath('checks.triage_layer_a', true);
    }

    public function test_health_is_degraded_without_lab_ranges(): void
    {
        // No seed → Rule #1 source missing → core degraded.
        $this->getJson('/api/health')
            ->assertStatus(503)
            ->assertJsonPath('status', 'degraded')
            ->assertJsonPath('checks.lab_ranges', false);
    }

    public function test_kb_starter_pack_seeds_all_documents(): void
    {
        $this->seed(KbSeeder::class);

        // The starter pack ships 45 clinician-review-pending documents.
        $this->assertSame(45, KbDocument::count());

        // Every phase-1 specialty is represented.
        foreach (['gynecology', 'urology', 'sti', 'endocrinology', 'general_labs'] as $spec) {
            $this->assertTrue(
                KbDocument::where('specialty', $spec)->exists(),
                "KB should contain at least one {$spec} document"
            );
        }
    }
}

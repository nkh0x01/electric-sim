<?php

namespace Tests\Feature;

use App\Services\TriageService;
use PHPUnit\Framework\Attributes\Group;
use Tests\TestCase;

/**
 * LAUNCH BLOCKER: the full Layer A + Layer B triage must reach recall = 1.0
 * over the 623-scenario red-flag suite. This exercises the REAL LLM, so it
 * is skipped unless ANTHROPIC_API_KEY is configured and Layer B is enabled.
 *
 * Run with: php artisan test --group=triage-integration
 */
#[Group('triage-integration')]
class TriageIntegrationTest extends TestCase
{
    public function test_full_triage_reaches_100_percent_recall(): void
    {
        if (! config('services.anthropic.key')) {
            $this->markTestSkipped('ANTHROPIC_API_KEY not set — Layer B cannot run.');
        }

        // Force Layer B on for this run regardless of .env.
        config(['idoctor.triage.llm_enabled' => true]);

        $triage = $this->app->make(TriageService::class);
        $rows = $this->loadSuite();
        $emergencies = array_filter($rows, fn ($r) => $r['expected_emergency'] === '1');
        $this->assertNotEmpty($emergencies, 'red-flag suite CSV missing');

        $missed = [];
        foreach ($emergencies as $r) {
            if (! $triage->detect($r['text'])['emergency']) {
                $missed[] = $r['id'].' ['.$r['category'].']: '.$r['text'];
            }
        }

        $recall = 1 - count($missed) / count($emergencies);
        fwrite(STDERR, sprintf("\n[Layer A+B] recall=%.4f  missed=%d/%d\n",
            $recall, count($missed), count($emergencies)));
        foreach (array_slice($missed, 0, 40) as $m) {
            fwrite(STDERR, "  MISS $m\n");
        }

        $this->assertSame(0, count($missed),
            'Missed emergencies must be zero for launch. Extend redflag_phrases '
            .'or tune Layer B threshold in config/idoctor.php.');
    }

    /**
     * @return array<int,array<string,string>>
     */
    private function loadSuite(): array
    {
        $path = database_path('data/redflag_test_suite.csv');
        if (! is_file($path)) {
            return [];
        }
        $handle = fopen($path, 'r');
        $header = fgetcsv($handle);
        $rows = [];
        while (($row = fgetcsv($handle)) !== false) {
            $rows[] = array_combine($header, $row);
        }
        fclose($handle);

        return $rows;
    }
}

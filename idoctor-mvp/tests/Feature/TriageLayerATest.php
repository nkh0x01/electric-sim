<?php

namespace Tests\Feature;

use App\Services\TriageService;
use PHPUnit\Framework\Attributes\Group;
use Tests\TestCase;

#[Group('triage')]
class TriageLayerATest extends TestCase
{
    private function triage(): TriageService
    {
        return $this->app->make(TriageService::class);
    }

    public function test_obvious_cardiac_emergency_is_flagged(): void
    {
        $v = $this->triage()->layerA('ძლიერი გულმკერდის ტკივილი მაქვს რა ვქნა?');
        $this->assertTrue($v['emergency']);
        $this->assertSame('A', $v['layer']);
    }

    public function test_transliterated_emergency_is_flagged(): void
    {
        $v = $this->triage()->layerA('ver vsuntqav damexmaret');
        $this->assertTrue($v['emergency']);
    }

    public function test_informational_question_is_not_flagged(): void
    {
        $v = $this->triage()->layerA('რას ნიშნავს TSH-ის მომატება? დეტალურად ამიხსენით.');
        $this->assertFalse($v['emergency']);
    }

    public function test_benign_headache_is_not_flagged(): void
    {
        $v = $this->triage()->layerA('ხანდახან თავი მტკივა საღამოობით, რა ვქნა?');
        $this->assertFalse($v['emergency']);
    }

    /**
     * Layer A recall baseline over the full red-flag suite. The project's
     * own conclusion is that keyword-only tops out around ~0.89 and that
     * 100% requires Layer B — so this asserts the configured baseline, not 1.0.
     */
    public function test_layer_a_recall_meets_baseline(): void
    {
        $rows = $this->loadSuite();
        $this->assertNotEmpty($rows, 'red-flag suite CSV missing');

        $triage = $this->triage();
        $emergencies = array_filter($rows, fn ($r) => $r['expected_emergency'] === '1');
        $negatives = array_filter($rows, fn ($r) => $r['expected_emergency'] === '0');

        $caught = 0;
        $missed = [];
        foreach ($emergencies as $r) {
            if ($triage->layerA($r['text'])['emergency']) {
                $caught++;
            } else {
                $missed[] = $r['category'].': '.$r['text'];
            }
        }
        $recall = $caught / max(1, count($emergencies));

        // Specificity: how many negatives correctly stay non-emergency.
        $tn = 0;
        foreach ($negatives as $r) {
            if (! $triage->layerA($r['text'])['emergency']) {
                $tn++;
            }
        }
        $specificity = $tn / max(1, count($negatives));

        fwrite(STDERR, sprintf(
            "\n[Layer A] recall=%.3f (%d/%d)  specificity=%.3f (%d/%d)  missed=%d\n",
            $recall, $caught, count($emergencies), $specificity, $tn, count($negatives), count($missed)
        ));
        if ($missed !== []) {
            fwrite(STDERR, "  first missed: ".implode("\n  first missed: ", array_slice($missed, 0, 8))."\n");
        }

        $baseline = (float) config('idoctor.triage.layer_a_min_recall', 0.85);
        $this->assertGreaterThanOrEqual($baseline, $recall,
            "Layer A recall $recall below baseline $baseline");
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

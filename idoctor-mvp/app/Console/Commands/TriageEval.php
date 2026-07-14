<?php

namespace App\Console\Commands;

use App\Services\TriageService;
use Illuminate\Console\Command;

/**
 * Offline/online triage evaluation harness. Prints recall, specificity and
 * the list of missed emergencies so keywords / Layer B can be tuned toward
 * the 100% recall launch gate.
 *
 *   php artisan idoctor:triage-eval            # Layer A only
 *   php artisan idoctor:triage-eval --llm      # Layer A + B (needs key)
 */
class TriageEval extends Command
{
    protected $signature = 'idoctor:triage-eval {--llm : Enable Layer B (LLM)} {--limit=0 : Limit rows}';

    protected $description = 'Evaluate triage recall against the red-flag suite.';

    public function handle(TriageService $triage): int
    {
        if ($this->option('llm')) {
            config(['idoctor.triage.llm_enabled' => true]);
        }
        $useLlm = (bool) config('idoctor.triage.llm_enabled');

        $path = database_path('data/redflag_test_suite.csv');
        if (! is_file($path)) {
            $this->error("Suite not found: $path");

            return self::FAILURE;
        }

        $handle = fopen($path, 'r');
        $header = fgetcsv($handle);
        $rows = [];
        while (($row = fgetcsv($handle)) !== false) {
            $rows[] = array_combine($header, $row);
        }
        fclose($handle);

        $limit = (int) $this->option('limit');
        if ($limit > 0) {
            $rows = array_slice($rows, 0, $limit);
        }

        $emerg = 0; $caught = 0; $neg = 0; $tn = 0;
        $missed = [];
        foreach ($rows as $r) {
            $isEmerg = $r['expected_emergency'] === '1';
            $verdict = $useLlm ? $triage->detect($r['text']) : $triage->layerA($r['text']);
            $flagged = $verdict['emergency'];

            if ($isEmerg) {
                $emerg++;
                $flagged ? $caught++ : $missed[] = $r;
            } else {
                $neg++;
                if (! $flagged) {
                    $tn++;
                }
            }
        }

        $recall = $caught / max(1, $emerg);
        $spec = $tn / max(1, $neg);

        $this->newLine();
        $this->info(sprintf('Layer %s', $useLlm ? 'A+B' : 'A'));
        $this->line(sprintf('Recall      : %.4f  (%d/%d emergencies caught)', $recall, $caught, $emerg));
        $this->line(sprintf('Specificity : %.4f  (%d/%d negatives kept safe)', $spec, $tn, $neg));
        $this->line(sprintf('Missed      : %d', count($missed)));

        if ($missed !== []) {
            $this->newLine();
            $this->warn('Missed emergencies (extend config/idoctor.php redflag_phrases):');
            foreach ($missed as $m) {
                $this->line(sprintf('  [%s/%s] %s', $m['category'], $m['style'], $m['text']));
            }
        }

        return $recall >= 1.0 ? self::SUCCESS : self::FAILURE;
    }
}

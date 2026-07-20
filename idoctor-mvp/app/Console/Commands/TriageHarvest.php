<?php

namespace App\Console\Commands;

use App\Models\TriageMiss;
use Illuminate\Console\Command;

/**
 * Fold human-reviewed triage misses into the red-flag test suite, so a missed
 * emergency becomes a permanent regression guard.
 *
 *   php artisan idoctor:triage-harvest           # dry run: show counts
 *   php artisan idoctor:triage-harvest --write    # append reviewed misses
 *
 * Only misses a human has marked `reviewed` are harvested. The reviewer must
 * de-identify the text first — it becomes a committed fixture.
 */
class TriageHarvest extends Command
{
    protected $signature = 'idoctor:triage-harvest {--write : Append reviewed misses to the red-flag suite CSV}';

    protected $description = 'Harvest human-reviewed triage misses into the red-flag test suite.';

    public function handle(): int
    {
        $byStatus = TriageMiss::query()
            ->selectRaw('status, count(*) as c')
            ->groupBy('status')
            ->pluck('c', 'status');

        $this->info('Triage misses by status:');
        foreach (['new', 'reviewed', 'added_to_suite'] as $s) {
            $this->line(sprintf('  %-16s %d', $s, (int) ($byStatus[$s] ?? 0)));
        }

        $reviewed = TriageMiss::where('status', 'reviewed')->get();

        if (! $this->option('write')) {
            $this->line('');
            $this->comment($reviewed->count().' reviewed miss(es) ready. Re-run with --write to harvest.');
            $this->warn('De-identify each miss before harvesting — it becomes a committed test fixture.');

            return self::SUCCESS;
        }

        if ($reviewed->isEmpty()) {
            $this->info('Nothing to harvest.');

            return self::SUCCESS;
        }

        $path = database_path('data/redflag_test_suite.csv');
        $n = 0;
        foreach (file($path, FILE_IGNORE_NEW_LINES) ?: [] as $line) {
            if (preg_match('/^HV(\d+),/', $line, $m)) {
                $n = max($n, (int) $m[1]);
            }
        }

        $fh = fopen($path, 'a');
        $added = 0;
        foreach ($reviewed as $miss) {
            $n++;
            fputcsv($fh, [
                'HV'.str_pad((string) $n, 4, '0', STR_PAD_LEFT),
                $miss->text,
                1,
                $miss->expected_category ?: 'harvested',
                'harvested',
            ]);
            $miss->update(['status' => 'added_to_suite']);
            $added++;
        }
        fclose($fh);

        $this->info("Appended $added reviewed miss(es) to the red-flag suite.");

        return self::SUCCESS;
    }
}

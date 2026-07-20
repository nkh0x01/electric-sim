<?php

namespace App\Console\Commands;

use App\Models\KbChunk;
use App\Models\KbDocument;
use Illuminate\Console\Command;

/**
 * Knowledge-base health at a glance: how many documents exist, how many a
 * clinician has reviewed (reviewed_by set), and how many chunks still lack an
 * embedding. The review count is a launch gate — unreviewed docs are seed
 * placeholders, not vetted content.
 *
 *   php artisan idoctor:kb-status
 */
class KbStatus extends Command
{
    protected $signature = 'idoctor:kb-status';

    protected $description = 'Report KB document count, clinician-review status, and embedding coverage.';

    public function handle(): int
    {
        $docs = KbDocument::count();
        $reviewed = KbDocument::whereNotNull('reviewed_by')->count();
        $pending = $docs - $reviewed;

        $chunks = KbChunk::count();
        $embedded = KbChunk::whereNotNull('embedding')->count();
        $missing = $chunks - $embedded;

        $this->info('iDoctor KB status');
        $this->table(['metric', 'value'], [
            ['documents',            $docs],
            ['clinician-reviewed',   sprintf('%d / %d', $reviewed, $docs)],
            ['review pending',       $pending],
            ['chunks',               $chunks],
            ['chunks embedded',      sprintf('%d / %d', $embedded, $chunks)],
            ['embedding missing',    $missing],
        ]);

        // Per-specialty breakdown, so clinicians can see coverage by area.
        $bySpecialty = KbDocument::query()
            ->selectRaw('specialty, count(*) as total, count(reviewed_by) as reviewed')
            ->groupBy('specialty')
            ->orderBy('specialty')
            ->get();

        if ($bySpecialty->isNotEmpty()) {
            $this->line('');
            $this->table(
                ['specialty', 'docs', 'reviewed'],
                $bySpecialty->map(fn ($r) => [
                    $r->specialty,
                    (int) $r->total,
                    sprintf('%d / %d', (int) $r->reviewed, (int) $r->total),
                ])->all()
            );
        }

        if ($pending > 0) {
            $this->warn("⚠ {$pending} document(s) not yet clinician-reviewed — not launch-ready.");
        }
        if ($missing > 0) {
            $this->warn("⚠ {$missing} chunk(s) missing an embedding — run: php artisan idoctor:embed-kb");
        }

        return self::SUCCESS;
    }
}

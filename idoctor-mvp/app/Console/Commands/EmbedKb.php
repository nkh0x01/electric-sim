<?php

namespace App\Console\Commands;

use App\Models\KbChunk;
use App\Services\EmbeddingClient;
use Illuminate\Console\Command;
use Illuminate\Support\Facades\DB;
use Throwable;

class EmbedKb extends Command
{
    protected $signature = 'idoctor:embed-kb {--batch=32 : Chunks per embedding request}';

    protected $description = 'Generate Voyage embeddings for KB chunks and store them in pgvector.';

    public function handle(EmbeddingClient $embeddings): int
    {
        if (! config('idoctor.rag.enabled')) {
            $this->warn('RAG is disabled (IDOCTOR_EMBEDDINGS_ENABLED=false). Nothing to do.');

            return self::SUCCESS;
        }

        $pgsql = DB::connection()->getDriverName() === 'pgsql';
        $batchSize = (int) $this->option('batch');
        $total = 0;

        KbChunk::query()->orderBy('id')->chunkById($batchSize, function ($chunks) use ($embeddings, $pgsql, &$total) {
            $inputs = $chunks->pluck('content')->all();

            try {
                $vectors = $embeddings->embed($inputs, 'document');
            } catch (Throwable $e) {
                $this->error('Embedding failed: '.$e->getMessage());

                return false; // stop chunking
            }

            foreach ($chunks->values() as $i => $chunk) {
                $vector = $vectors[$i] ?? null;
                if ($vector === null) {
                    continue;
                }

                if ($pgsql) {
                    $literal = '['.implode(',', array_map(fn ($v) => (float) $v, $vector)).']';
                    DB::update('UPDATE kb_chunks SET embedding = ?::vector WHERE id = ?', [$literal, $chunk->id]);
                } else {
                    $chunk->update(['embedding' => json_encode($vector)]);
                }
                $total++;
            }

            $this->info("Embedded $total chunks so far...");

            return true;
        });

        $this->info("Done. Embedded $total KB chunks.");

        return self::SUCCESS;
    }
}

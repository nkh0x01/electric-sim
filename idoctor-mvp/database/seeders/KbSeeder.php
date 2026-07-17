<?php

namespace Database\Seeders;

use App\Models\KbChunk;
use App\Models\KbDocument;
use Illuminate\Database\Seeder;

/**
 * Loads the KB starter pack from database/data/kb_starter_pack.md and splits
 * each document into chunks. Embeddings are populated separately by
 * `php artisan idoctor:embed-kb` (needs a Voyage key).
 */
class KbSeeder extends Seeder
{
    public function run(): void
    {
        $path = database_path('data/kb_starter_pack.md');
        if (! is_file($path)) {
            $this->command?->warn("kb_starter_pack.md not found at $path");

            return;
        }

        $raw = file_get_contents($path);
        // Drop the leading HTML comment block if present.
        $raw = preg_replace('/^<!--.*?-->\s*/s', '', $raw) ?? $raw;

        $blocks = preg_split('/^===DOC===\s*$/m', $raw) ?: [];

        KbChunk::query()->delete();
        KbDocument::query()->delete();

        $docs = 0;
        $chunks = 0;
        foreach ($blocks as $block) {
            $block = trim($block);
            if ($block === '') {
                continue;
            }

            [$meta, $body] = $this->splitMeta($block);
            if (($meta['slug'] ?? '') === '' || $body === '') {
                continue;
            }

            $doc = KbDocument::create([
                'slug' => $meta['slug'],
                'title' => $meta['title'] ?? $meta['slug'],
                'specialty' => $meta['specialty'] ?? 'general_labs',
                'source' => $meta['source'] ?? null,
                'body' => $body,
            ]);
            $docs++;

            foreach ($this->chunk($body) as $i => $piece) {
                KbChunk::create([
                    'kb_document_id' => $doc->id,
                    'specialty' => $doc->specialty,
                    'ordinal' => $i,
                    'content' => $piece,
                ]);
                $chunks++;
            }
        }

        $this->command?->info("Seeded $docs KB documents / $chunks chunks (embeddings pending).");
    }

    /**
     * @return array{0:array<string,string>,1:string}
     */
    private function splitMeta(string $block): array
    {
        $lines = preg_split('/\r?\n/', $block);
        $meta = [];
        $bodyStart = 0;
        foreach ($lines as $i => $line) {
            if (trim($line) === '') {
                $bodyStart = $i + 1;
                break;
            }
            if (preg_match('/^(slug|title|specialty|source):\s*(.+)$/', trim($line), $m)) {
                $meta[$m[1]] = trim($m[2]);
            }
        }

        $body = trim(implode("\n", array_slice($lines, $bodyStart)));

        return [$meta, $body];
    }

    /**
     * Naive paragraph-based chunking (KB docs are short in phase 1).
     *
     * @return array<int,string>
     */
    private function chunk(string $body): array
    {
        $paras = preg_split('/\n\s*\n/', $body) ?: [$body];

        return array_values(array_filter(array_map('trim', $paras), fn ($p) => $p !== ''));
    }
}

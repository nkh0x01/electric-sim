<?php

namespace App\Services;

use Illuminate\Support\Facades\DB;
use Throwable;

/**
 * Retrieval over the knowledge base using pgvector cosine similarity.
 *
 * Returns an empty result set (never throws) when RAG is disabled, no keys
 * are configured, or the driver is not Postgres — the chat pipeline then
 * simply proceeds without retrieved context.
 */
class RagService
{
    public function __construct(private readonly EmbeddingClient $embeddings) {}

    /**
     * @return array<int,array{content:string,title:string,specialty:string,score:float}>
     */
    public function search(string $query, ?string $specialty = null): array
    {
        if (! config('idoctor.rag.enabled')) {
            return [];
        }
        if (DB::connection()->getDriverName() !== 'pgsql') {
            return [];
        }

        try {
            $vector = $this->embeddings->embedQuery($query);
        } catch (Throwable) {
            return [];
        }
        if ($vector === []) {
            return [];
        }

        $literal = '['.implode(',', array_map(static fn ($v) => (float) $v, $vector)).']';
        $topK = (int) config('idoctor.rag.top_k', 5);
        $minScore = (float) config('idoctor.rag.min_score', 0.25);

        $bindings = [$literal, $literal];
        $specialtyClause = '';
        if ($specialty !== null) {
            $specialtyClause = 'WHERE c.specialty = ?';
            $bindings[] = $specialty;
        }
        $bindings[] = $topK;

        // Cosine similarity = 1 - cosine distance (<=>).
        $rows = DB::select(
            "SELECT c.content, d.title, c.specialty,
                    1 - (c.embedding <=> ?::vector) AS score
             FROM kb_chunks c
             JOIN kb_documents d ON d.id = c.kb_document_id
             $specialtyClause
             ORDER BY c.embedding <=> ?::vector
             LIMIT ?",
            $bindings
        );

        return collect($rows)
            ->map(fn ($r) => [
                'content' => $r->content,
                'title' => $r->title,
                'specialty' => $r->specialty,
                'score' => (float) $r->score,
            ])
            ->filter(fn ($r) => $r['score'] >= $minScore)
            ->values()
            ->all();
    }
}

<?php

namespace App\Services;

use Illuminate\Support\Facades\Http;
use RuntimeException;

/**
 * Voyage AI embeddings client (voyage-3, 1536-dim by default).
 */
class EmbeddingClient
{
    /**
     * @param  array<int,string>  $inputs
     * @return array<int,array<int,float>>  one vector per input
     */
    public function embed(array $inputs, string $inputType = 'document'): array
    {
        $key = (string) config('services.voyage.key');
        if ($key === '') {
            throw new RuntimeException('VOYAGE_API_KEY is not configured.');
        }

        $response = Http::withToken($key)
            ->timeout((int) config('services.voyage.timeout', 30))
            ->post(rtrim((string) config('services.voyage.base_url'), '/').'/embeddings', [
                'model'      => config('idoctor.embeddings.model'),
                'input'      => $inputs,
                'input_type' => $inputType, // 'document' | 'query'
            ]);

        if ($response->failed()) {
            throw new RuntimeException('Voyage API error: '.$response->status().' '.$response->body());
        }

        return collect($response->json('data', []))
            ->sortBy('index')
            ->pluck('embedding')
            ->values()
            ->all();
    }

    /**
     * Convenience for a single query string.
     *
     * @return array<int,float>
     */
    public function embedQuery(string $text): array
    {
        return $this->embed([$text], 'query')[0] ?? [];
    }
}

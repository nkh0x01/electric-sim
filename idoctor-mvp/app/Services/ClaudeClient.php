<?php

namespace App\Services;

use Closure;
use Illuminate\Support\Facades\Http;
use RuntimeException;

/**
 * Thin Anthropic Messages API client: blocking completion, vision (image
 * blocks), and SSE token streaming.
 */
class ClaudeClient
{
    private function config(): array
    {
        $key = (string) config('services.anthropic.key');
        if ($key === '') {
            throw new RuntimeException('ANTHROPIC_API_KEY is not configured.');
        }

        return [
            'key' => $key,
            'base' => rtrim((string) config('services.anthropic.base_url'), '/'),
            'version' => (string) config('services.anthropic.version'),
            'timeout' => (int) config('services.anthropic.timeout', 60),
        ];
    }

    private function headers(array $c): array
    {
        return [
            'x-api-key' => $c['key'],
            'anthropic-version' => $c['version'],
            'content-type' => 'application/json',
        ];
    }

    /**
     * Blocking completion. Returns the concatenated text output.
     *
     * @param  array<int,array{role:string,content:mixed}>  $messages
     */
    public function complete(
        string $system,
        array $messages,
        ?string $model = null,
        int $maxTokens = 1024,
    ): string {
        $c = $this->config();

        $response = Http::withHeaders($this->headers($c))
            ->timeout($c['timeout'])
            ->post($c['base'].'/v1/messages', [
                'model' => $model ?? config('idoctor.models.cheap'),
                'max_tokens' => $maxTokens,
                'system' => $system,
                'messages' => $messages,
            ]);

        if ($response->failed()) {
            throw new RuntimeException('Anthropic API error: '.$response->status().' '.$response->body());
        }

        return collect($response->json('content', []))
            ->where('type', 'text')
            ->pluck('text')
            ->implode('');
    }

    /**
     * Vision completion for OCR/lab extraction. $image is raw bytes.
     */
    public function vision(
        string $system,
        string $prompt,
        string $image,
        string $mime,
        ?string $model = null,
        int $maxTokens = 1500,
    ): string {
        $block = [
            'type' => 'image',
            'source' => [
                'type' => 'base64',
                'media_type' => $mime,
                'data' => base64_encode($image),
            ],
        ];

        return $this->complete(
            system: $system,
            messages: [[
                'role' => 'user',
                'content' => [
                    $block,
                    ['type' => 'text', 'text' => $prompt],
                ],
            ]],
            model: $model ?? config('idoctor.models.vision'),
            maxTokens: $maxTokens,
        );
    }

    /**
     * SSE streaming. Invokes $onDelta($text) for each token delta.
     *
     * @param  array<int,array{role:string,content:mixed}>  $messages
     */
    public function stream(
        string $system,
        array $messages,
        Closure $onDelta,
        ?string $model = null,
        int $maxTokens = 1024,
    ): void {
        $c = $this->config();

        $response = Http::withHeaders($this->headers($c))
            ->timeout($c['timeout'])
            ->withOptions(['stream' => true])
            ->post($c['base'].'/v1/messages', [
                'model' => $model ?? config('idoctor.models.cheap'),
                'max_tokens' => $maxTokens,
                'system' => $system,
                'messages' => $messages,
                'stream' => true,
            ]);

        if ($response->failed()) {
            throw new RuntimeException('Anthropic stream error: '.$response->status());
        }

        $body = $response->toPsrResponse()->getBody();
        $buffer = '';
        while (! $body->eof()) {
            $buffer .= $body->read(1024);

            while (($nl = strpos($buffer, "\n")) !== false) {
                $line = trim(substr($buffer, 0, $nl));
                $buffer = substr($buffer, $nl + 1);

                if (! str_starts_with($line, 'data:')) {
                    continue;
                }
                $payload = trim(substr($line, 5));
                if ($payload === '' || $payload === '[DONE]') {
                    continue;
                }
                $event = json_decode($payload, true);
                if (($event['type'] ?? null) === 'content_block_delta') {
                    $text = $event['delta']['text'] ?? '';
                    if ($text !== '') {
                        $onDelta($text);
                    }
                }
            }
        }
    }
}

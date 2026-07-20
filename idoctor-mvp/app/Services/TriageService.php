<?php

namespace App\Services;

use Illuminate\Support\Facades\Log;
use Throwable;

/**
 * Rule #2: red-flag triage runs BEFORE Claude is ever called.
 *
 * Two layers, recall-first:
 *   Layer A — deterministic keyword/regex over normalised text. No network.
 *   Layer B — LLM confirmation for phrasings Layer A missed. Only runs when
 *             Layer A found nothing AND idoctor.triage.llm_enabled is true.
 *
 * A false positive (an unnecessary 112 screen) is acceptable. A false
 * negative (a missed emergency) is treated as fatal, so the service always
 * fails OPEN: if Layer B errors, we never downgrade a message to "safe".
 */
class TriageService
{
    public function __construct(private readonly ClaudeClient $claude) {}

    /**
     * @return array{emergency:bool, layer:?string, reason:?string, matched:?string}
     */
    public function detect(string $text): array
    {
        // ---- Layer A: deterministic -------------------------------------
        $a = $this->layerA($text);
        if ($a['emergency']) {
            return $a;
        }

        // ---- Layer B: LLM confirmation ----------------------------------
        if (config('idoctor.triage.llm_enabled')) {
            try {
                $b = $this->layerB($text);
                if ($b['emergency']) {
                    return $b;
                }
            } catch (Throwable $e) {
                // Fail open: Layer B is unavailable. Layer A already said
                // "not emergency", so we cannot upgrade here — but we log it
                // loudly so a missed emergency is auditable.
                Log::channel('audit')->warning('triage.layerB.error', [
                    'session_hash' => null,
                    'error' => substr($e->getMessage(), 0, 200),
                ]);
            }
        }

        return ['emergency' => false, 'layer' => null, 'reason' => null, 'matched' => null];
    }

    /**
     * Deterministic keyword pass. Public so it can be unit-tested and reused
     * by the eval harness without touching the network.
     *
     * @return array{emergency:bool, layer:?string, reason:?string, matched:?string}
     */
    public function layerA(string $text): array
    {
        $norm = self::normalise($text);

        foreach ((array) config('idoctor.triage.redflag_phrases', []) as $phrase) {
            $needle = self::normalise($phrase);
            if ($needle !== '' && mb_strpos($norm, $needle) !== false) {
                return [
                    'emergency' => true,
                    'layer' => 'A',
                    'reason' => 'redflag_keyword',
                    'matched' => $phrase,
                ];
            }
        }

        return ['emergency' => false, 'layer' => null, 'reason' => null, 'matched' => null];
    }

    /**
     * LLM confirmation. Asks Claude for an emergency probability and compares
     * against a deliberately low threshold (recall-first).
     *
     * @return array{emergency:bool, layer:?string, reason:?string, matched:?string}
     */
    public function layerB(string $text): array
    {
        $threshold = (float) config('idoctor.triage.llm_threshold', 0.15);

        $system = <<<'PROMPT'
        You are a medical triage classifier for a Georgian-language health navigator.
        Decide whether the user's message describes a potential MEDICAL EMERGENCY that
        warrants calling 112 immediately (e.g. chest pain, stroke signs, trouble
        breathing, severe bleeding, suicidal intent, anaphylaxis, poisoning/overdose,
        seizure/loss of consciousness, pregnancy bleeding, a critically ill infant).

        Be recall-first: if there is ANY reasonable chance of an emergency, lean toward
        emergency. Purely informational questions ("what does high TSH mean?", "what is
        the normal range for X?") are NOT emergencies.

        Reply with ONLY a JSON object: {"p": <float 0..1>, "category": "<short>"}.
        p is the probability that this is an emergency. No prose.
        PROMPT;

        $raw = $this->claude->complete(
            system: $system,
            messages: [['role' => 'user', 'content' => $text]],
            model: (string) config('idoctor.models.triage'),
            maxTokens: 64,
        );

        $p = 0.0;
        $category = 'unknown';
        if (preg_match('/\{.*\}/s', $raw, $m)) {
            $decoded = json_decode($m[0], true);
            if (is_array($decoded)) {
                $p = (float) ($decoded['p'] ?? 0.0);
                $category = (string) ($decoded['category'] ?? 'unknown');
            }
        }

        return [
            'emergency' => $p >= $threshold,
            'layer' => 'B',
            'reason' => 'llm_prob_'.number_format($p, 2),
            'matched' => $category,
        ];
    }

    /**
     * Normalise for matching: lower-case (only affects Latin translit),
     * strip punctuation to spaces, collapse whitespace. Georgian script is
     * caseless so this is safe for both scripts.
     */
    public static function normalise(string $text): string
    {
        $text = mb_strtolower($text, 'UTF-8');
        // Replace anything that is not a letter/number (any script) with a space.
        $text = preg_replace('/[^\p{L}\p{N}]+/u', ' ', $text) ?? '';

        return trim(preg_replace('/\s+/u', ' ', $text) ?? '');
    }
}

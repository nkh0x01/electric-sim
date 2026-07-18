<?php

namespace App\Services;

/**
 * Chooses the cheap (Haiku) vs premium (Sonnet) model based on unit
 * economics: default to Haiku, escalate only when the task genuinely
 * benefits (long prompts, lab interpretation, structured reasoning).
 */
class RouterService
{
    /**
     * @param  array{has_lab?:bool,has_rag?:bool,medical?:bool}  $signals
     */
    public function pick(string $prompt, array $signals = []): string
    {
        $threshold = (int) config('idoctor.router.escalate_char_threshold', 900);

        // Medical content and lab interpretation always get the premium model:
        // the cheap model hallucinates Georgian medical terminology and invents
        // reference ranges. Cost is secondary to clinical wording quality here.
        $escalate = ($signals['has_lab'] ?? false)
            || ($signals['medical'] ?? false)
            || mb_strlen($prompt) > $threshold;

        return $escalate
            ? (string) config('idoctor.models.premium')
            : (string) config('idoctor.models.cheap');
    }
}

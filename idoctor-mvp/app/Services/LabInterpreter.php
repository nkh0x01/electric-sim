<?php

namespace App\Services;

/**
 * Turns deterministically-classified lab results into a Georgian, plain
 * language interpretation plus "questions to ask your doctor".
 *
 * The flags (low/normal/high) are ALREADY decided by LabParser::classify
 * (Rule #1). This service is told to explain them, never to re-judge them.
 */
class LabInterpreter
{
    public function __construct(private readonly ClaudeClient $claude) {}

    /**
     * @param  array<int,array<string,mixed>>  $classified
     */
    public function interpret(array $classified): string
    {
        $table = collect($classified)->map(function ($r) {
            $range = ($r['ref_low'] ?? null) !== null || ($r['ref_high'] ?? null) !== null
                ? trim(($r['ref_low'] ?? '').'–'.($r['ref_high'] ?? ''))
                : 'N/A';

            return sprintf(
                '- %s: %s %s | ნორმა: %s | FLAG=%s',
                $r['name'], $r['value'], $r['unit'] ?? '', $range, $r['flag']
            );
        })->implode("\n");

        $system = <<<'PROMPT'
        You are a Georgian-language health navigator (NOT a doctor). You are given
        lab results that have ALREADY been flagged as low/normal/high by a
        deterministic rule engine. You MUST NOT change any flag. Do not recalculate
        whether a value is normal — trust the provided FLAG exactly.

        Write in Georgian, warm and plain. For each out-of-range value, briefly explain
        in lay terms what that analyte reflects and what "low"/"high" can commonly mean,
        WITHOUT diagnosing. Then give a short bulleted list titled "კითხვები ექიმისთვის"
        (questions to ask the doctor). Never tell the user they are healthy or sick —
        only that values are in/out of the reference range and a doctor should interpret.
        PROMPT;

        $prompt = "შედეგები (FLAG უცვლელია):\n".$table
            ."\n\nდაწერე ინტერპრეტაცია ქართულად ზემოთ მოცემული წესებით.";

        return $this->claude->complete(
            system: $system,
            messages: [['role' => 'user', 'content' => $prompt]],
            model: (string) config('idoctor.models.premium'),
            maxTokens: 1200,
        );
    }
}

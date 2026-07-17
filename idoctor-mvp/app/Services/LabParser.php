<?php

namespace App\Services;

use App\Models\LabReferenceRange;
use Illuminate\Support\Str;

/**
 * Rule #1: lab reference ranges come ONLY from the lab_reference_ranges
 * table, and whether a value is in range is decided HERE, deterministically.
 * The LLM is allowed to OCR raw numbers off an image, but never to judge
 * "normal vs abnormal" — that is classify()'s job alone.
 */
class LabParser
{
    public function __construct(private readonly ClaudeClient $claude) {}

    /**
     * OCR raw analyte values from an image/PDF page using vision. Returns
     * ONLY raw readings — no interpretation.
     *
     * @return array<int,array{code:?string,name:string,value:float,unit:?string}>
     */
    public function extract(string $bytes, string $mime): array
    {
        $knownCodes = LabReferenceRange::query()
            ->select('analyte_code', 'analyte_name_ka')
            ->distinct()
            ->get()
            ->map(fn ($r) => "{$r->analyte_code} = {$r->analyte_name_ka}")
            ->implode("\n");

        $system = 'You are an OCR engine for Georgian lab reports. Extract only the '
            .'measured analyte values. Do NOT judge whether values are normal. '
            .'Map each analyte to one of the known codes when possible.';

        $prompt = "Known analyte codes:\n$knownCodes\n\n"
            .'Return ONLY a JSON array of objects: '
            .'[{"code": "<known code or null>", "name": "<as printed>", '
            .'"value": <number>, "unit": "<as printed or null>"}]. No prose.';

        $raw = $this->claude->vision($system, $prompt, $bytes, $mime);

        return $this->parseExtraction($raw);
    }

    /**
     * @return array<int,array{code:?string,name:string,value:float,unit:?string}>
     */
    public function parseExtraction(string $raw): array
    {
        if (! preg_match('/\[.*\]/s', $raw, $m)) {
            return [];
        }
        $decoded = json_decode($m[0], true);
        if (! is_array($decoded)) {
            return [];
        }

        $out = [];
        foreach ($decoded as $row) {
            if (! isset($row['value']) || ! is_numeric($row['value'])) {
                continue;
            }
            $out[] = [
                'code' => isset($row['code']) && $row['code'] !== '' ? (string) $row['code'] : null,
                'name' => (string) ($row['name'] ?? $row['code'] ?? ''),
                'value' => (float) $row['value'],
                'unit' => isset($row['unit']) && $row['unit'] !== '' ? (string) $row['unit'] : null,
            ];
        }

        return $out;
    }

    /**
     * Deterministically flag each extracted analyte against the reference
     * table. This function performs NO LLM calls.
     *
     * @param  array<int,array{code:?string,name:string,value:float,unit:?string}>  $extracted
     * @return array<int,array<string,mixed>>
     */
    public function classify(array $extracted, string $sex = 'any', int $age = 30, ?string $condition = null): array
    {
        $results = [];

        foreach ($extracted as $item) {
            $range = $this->resolveRange($item['code'], $item['name'], $sex, $age, $condition);

            $flag = 'unknown';
            $refLow = $refHigh = null;
            if ($range) {
                $refLow = $range->ref_low;
                $refHigh = $range->ref_high;
                $flag = $this->flagFor($item['value'], $refLow, $refHigh);
            }

            $results[] = [
                'code' => $range->analyte_code ?? $item['code'],
                'name' => $range->analyte_name_ka ?? $item['name'],
                'value' => $item['value'],
                'unit' => $item['unit'] ?? ($range->unit ?? null),
                'ref_low' => $refLow,
                'ref_high' => $refHigh,
                'flag' => $flag, // low | normal | high | unknown
                'note_ka' => $range->note_ka ?? null,
            ];
        }

        return $results;
    }

    /**
     * Pure comparison — the one place "normal vs abnormal" is decided.
     */
    public function flagFor(float $value, ?float $low, ?float $high): string
    {
        if ($low !== null && $value < $low) {
            return 'low';
        }
        if ($high !== null && $value > $high) {
            return 'high';
        }
        if ($low === null && $high === null) {
            return 'unknown';
        }

        return 'normal';
    }

    /**
     * Find the most specific matching reference row.
     */
    private function resolveRange(?string $code, string $name, string $sex, int $age, ?string $condition): ?LabReferenceRange
    {
        $query = LabReferenceRange::query();

        if ($code) {
            $query->whereRaw('LOWER(analyte_code) = ?', [Str::lower($code)]);
        } else {
            $query->where('analyte_name_ka', 'like', '%'.trim($name).'%');
        }

        $candidates = $query
            ->where('age_min', '<=', $age)
            ->where('age_max', '>=', $age)
            ->whereIn('sex', ['any', Str::lower($sex)])
            ->get();

        if ($candidates->isEmpty()) {
            return null;
        }

        // Prefer: matching condition > sex-specific > generic.
        return $candidates->sortByDesc(function (LabReferenceRange $r) use ($sex, $condition) {
            $score = 0;
            if ($condition !== null && $r->condition === $condition) {
                $score += 4;
            }
            if ($condition === null && ($r->condition === null || $r->condition === '')) {
                $score += 1;
            }
            if ($r->sex === Str::lower($sex) && $sex !== 'any') {
                $score += 2;
            }

            return $score;
        })->first();
    }
}

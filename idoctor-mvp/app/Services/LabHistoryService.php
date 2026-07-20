<?php

namespace App\Services;

use App\Models\LabUpload;
use App\Models\User;
use Illuminate\Support\Collection;

/**
 * Builds an account's lab history and per-analyte trends from the ALREADY
 * classified uploads. This is pure aggregation over stored data — no LLM, no
 * re-classification. The flags come straight from LabParser::classify (Rule #1),
 * so a trend never re-decides "normal vs abnormal".
 */
class LabHistoryService
{
    /**
     * Parsed uploads for a user, newest first.
     */
    public function uploadsFor(User $user): Collection
    {
        return $user->labUploads()
            ->where('status', 'parsed')
            ->orderByDesc('created_at')
            ->get();
    }

    /**
     * A compact, content-free-ish history list. Each row summarises one upload:
     * how many analytes, how many out of range — never the raw file.
     *
     * @return array<int,array<string,mixed>>
     */
    public function history(User $user): array
    {
        return $this->uploadsFor($user)->map(function (LabUpload $u) {
            $classified = is_array($u->classified) ? $u->classified : [];
            $abnormal = collect($classified)
                ->filter(fn ($c) => in_array($c['flag'] ?? 'unknown', ['low', 'high'], true))
                ->count();

            return [
                'id' => $u->id,
                'date' => $u->created_at?->toDateString(),
                'analytes' => count($classified),
                'abnormal' => $abnormal,
                'needs_review' => collect($classified)->contains(fn ($c) => ! empty($c['needs_review'])),
            ];
        })->all();
    }

    /**
     * Per-analyte time series across all of a user's parsed uploads. Points are
     * ordered oldest→newest so a client can draw a trend line. The plotted value
     * is the reference-unit value when a conversion was possible (comparable
     * across sheets), else the raw reading.
     *
     * @return array<int,array<string,mixed>>
     */
    public function trends(User $user): array
    {
        $series = [];

        // Oldest→newest so each analyte's points are chronological.
        $uploads = $this->uploadsFor($user)->sortBy('created_at');

        foreach ($uploads as $upload) {
            $date = $upload->created_at?->toDateString();
            foreach ((is_array($upload->classified) ? $upload->classified : []) as $item) {
                $key = $item['code'] ?? $item['name'] ?? null;
                if ($key === null) {
                    continue;
                }

                $value = $item['value_in_ref_unit'] ?? $item['value'] ?? null;
                if ($value === null) {
                    continue; // incomparable reading (e.g. failed unit conversion)
                }

                if (! isset($series[$key])) {
                    $series[$key] = [
                        'code' => $item['code'] ?? null,
                        'name' => $item['name'] ?? $key,
                        'unit' => $item['unit'] ?? null,
                        'ref_low' => $item['ref_low'] ?? null,
                        'ref_high' => $item['ref_high'] ?? null,
                        'points' => [],
                    ];
                }

                $series[$key]['points'][] = [
                    'date' => $date,
                    'value' => (float) $value,
                    'flag' => $item['flag'] ?? 'unknown', // straight from Rule #1
                ];
            }
        }

        // Only analytes measured more than once are meaningful as a "trend",
        // but we return singletons too so the UI can show a first data point.
        return array_values($series);
    }
}

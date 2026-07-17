<?php

namespace Database\Seeders;

use App\Models\LabReferenceRange;
use Illuminate\Database\Seeder;

/**
 * Rule #1 source of truth. Loads the clinician-maintained reference table
 * from database/data/lab_reference_ranges.csv.
 */
class LabReferenceRangeSeeder extends Seeder
{
    public function run(): void
    {
        $path = database_path('data/lab_reference_ranges.csv');
        if (! is_file($path)) {
            $this->command?->warn("lab_reference_ranges.csv not found at $path");

            return;
        }

        $handle = fopen($path, 'r');
        $header = fgetcsv($handle);
        if ($header === false) {
            fclose($handle);

            return;
        }

        LabReferenceRange::query()->delete();

        $count = 0;
        while (($row = fgetcsv($handle)) !== false) {
            if (count($row) < count($header)) {
                $row = array_pad($row, count($header), null);
            }
            $data = array_combine($header, array_slice($row, 0, count($header)));

            LabReferenceRange::create([
                'analyte_code' => trim((string) $data['analyte_code']),
                'analyte_name_ka' => trim((string) $data['analyte_name_ka']),
                'unit' => trim((string) $data['unit']),
                'sex' => trim((string) ($data['sex'] ?: 'any')),
                'age_min' => (int) ($data['age_min'] ?: 0),
                'age_max' => (int) ($data['age_max'] ?: 120),
                'ref_low' => $data['ref_low'] !== '' ? (float) $data['ref_low'] : null,
                'ref_high' => $data['ref_high'] !== '' ? (float) $data['ref_high'] : null,
                'condition' => $data['condition'] !== '' ? trim((string) $data['condition']) : null,
                'source' => $data['source'] !== '' ? trim((string) $data['source']) : null,
                'note_ka' => $data['note_ka'] !== '' ? trim((string) $data['note_ka']) : null,
            ]);
            $count++;
        }
        fclose($handle);

        $this->command?->info("Seeded $count lab reference ranges.");
    }
}

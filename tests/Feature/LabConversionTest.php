<?php

namespace Tests\Feature;

use App\Services\LabParser;
use Database\Seeders\LabReferenceRangeSeeder;
use Illuminate\Foundation\Testing\RefreshDatabase;
use PHPUnit\Framework\Attributes\Group;
use Tests\TestCase;

/**
 * Rule #1 under unit conversion: when a lab sheet reports a different unit than
 * the reference table, LabParser::classify must convert before flagging — and
 * must NEVER trust a flag suggested in the input (that would be the LLM
 * deciding normal/abnormal).
 */
#[Group('lab')]
class LabConversionTest extends TestCase
{
    use RefreshDatabase;

    protected function setUp(): void
    {
        parent::setUp();
        $this->seed(LabReferenceRangeSeeder::class);
    }

    private function parser(): LabParser
    {
        return $this->app->make(LabParser::class);
    }

    public function test_glucose_reported_in_mgdl_is_converted_then_flagged(): void
    {
        // GLU table range is 3.9–5.5 mmol/L. 110 mg/dL ≈ 6.1 mmol/L -> high.
        $r = $this->parser()->classify(
            [['code' => 'GLU', 'name' => 'გლუკოზა', 'value' => 110.0, 'unit' => 'mg/dL']],
            sex: 'any', age: 40, condition: 'fasting',
        )[0];

        $this->assertSame('high', $r['flag']);
        $this->assertEqualsWithDelta(6.1, $r['value_in_ref_unit'], 0.2);
    }

    public function test_glucose_normal_in_mgdl(): void
    {
        // 90 mg/dL ≈ 5.0 mmol/L -> normal.
        $r = $this->parser()->classify(
            [['code' => 'GLU', 'name' => 'გლუკოზა', 'value' => 90.0, 'unit' => 'mg/dL']],
            sex: 'any', age: 40, condition: 'fasting',
        )[0];

        $this->assertSame('normal', $r['flag']);
    }

    public function test_creatinine_reported_in_mgdl_female(): void
    {
        // CREA female range 53–97 µmol/L. 1.5 mg/dL ≈ 133 µmol/L -> high.
        $r = $this->parser()->classify(
            [['code' => 'CREA', 'name' => 'კრეატინინი', 'value' => 1.5, 'unit' => 'mg/dL']],
            sex: 'f', age: 35,
        )[0];

        $this->assertSame('high', $r['flag']);
    }

    public function test_incompatible_unit_flags_unknown_never_wrong(): void
    {
        // TSH range is mIU/L; a nonsensical mg/dL reading cannot be compared.
        $r = $this->parser()->classify(
            [['code' => 'TSH', 'name' => 'TSH', 'value' => 2.0, 'unit' => 'mg/dL']],
        )[0];

        $this->assertSame('unknown', $r['flag']);
        $this->assertNull($r['value_in_ref_unit']);
    }

    public function test_input_flag_is_ignored_flag_is_recomputed(): void
    {
        // Even if the extraction stage suggests a (wrong) flag, classify ignores
        // it and computes the flag itself from the table (Rule #1).
        $r = $this->parser()->classify(
            [['code' => 'TSH', 'name' => 'TSH', 'value' => 2.0, 'unit' => 'mIU/L', 'flag' => 'high']],
        )[0];

        $this->assertSame('normal', $r['flag']);
    }
}

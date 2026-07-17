<?php

namespace Tests\Feature;

use App\Services\LabParser;
use Database\Seeders\LabReferenceRangeSeeder;
use Illuminate\Foundation\Testing\RefreshDatabase;
use PHPUnit\Framework\Attributes\Group;
use Tests\TestCase;

/**
 * Rule #1: normal/abnormal is decided by LabParser::classify against the
 * lab_reference_ranges table — never by the LLM.
 */
#[Group('lab')]
class LabClassificationTest extends TestCase
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

    public function test_high_tsh_is_flagged_high(): void
    {
        // TSH ref for adults is 0.4–4 mIU/L.
        $classified = $this->parser()->classify(
            [['code' => 'TSH', 'name' => 'TSH', 'value' => 8.2, 'unit' => 'mIU/L']],
            sex: 'any', age: 30,
        );

        $this->assertSame('high', $classified[0]['flag']);
        $this->assertEqualsWithDelta(0.4, $classified[0]['ref_low'], 0.001);
        $this->assertEqualsWithDelta(4.0, $classified[0]['ref_high'], 0.001);
    }

    public function test_normal_tsh_is_flagged_normal(): void
    {
        $classified = $this->parser()->classify(
            [['code' => 'TSH', 'name' => 'TSH', 'value' => 2.0, 'unit' => 'mIU/L']],
        );
        $this->assertSame('normal', $classified[0]['flag']);
    }

    public function test_low_hemoglobin_female_uses_female_range(): void
    {
        // Female HGB ref is 12–15.5 g/dL; 10.5 must flag low.
        $classified = $this->parser()->classify(
            [['code' => 'HGB', 'name' => 'ჰემოგლობინი', 'value' => 10.5, 'unit' => 'g/dL']],
            sex: 'f', age: 30,
        );
        $this->assertSame('low', $classified[0]['flag']);
    }

    public function test_male_hemoglobin_range_differs_from_female(): void
    {
        // 13.0 g/dL is LOW for males (ref 13.5–17.5) but NORMAL for females.
        $male = $this->parser()->classify(
            [['code' => 'HGB', 'name' => 'HGB', 'value' => 13.0]], sex: 'm', age: 40,
        );
        $female = $this->parser()->classify(
            [['code' => 'HGB', 'name' => 'HGB', 'value' => 13.0]], sex: 'f', age: 40,
        );

        $this->assertSame('low', $male[0]['flag']);
        $this->assertSame('normal', $female[0]['flag']);
    }

    public function test_unknown_analyte_is_flagged_unknown(): void
    {
        $classified = $this->parser()->classify(
            [['code' => 'NOTREAL', 'name' => 'უცნობი', 'value' => 5.0]],
        );
        $this->assertSame('unknown', $classified[0]['flag']);
    }

    public function test_flag_for_is_pure_boundary_logic(): void
    {
        $p = $this->parser();
        $this->assertSame('low', $p->flagFor(3.9, 4.0, 10.0));
        $this->assertSame('normal', $p->flagFor(4.0, 4.0, 10.0));
        $this->assertSame('high', $p->flagFor(10.1, 4.0, 10.0));
        $this->assertSame('unknown', $p->flagFor(5.0, null, null));
    }
}

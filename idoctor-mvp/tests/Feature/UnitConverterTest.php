<?php

namespace Tests\Feature;

use App\Services\UnitConverter;
use PHPUnit\Framework\Attributes\Group;
use Tests\TestCase;

#[Group('lab')]
class UnitConverterTest extends TestCase
{
    private function conv(): UnitConverter
    {
        return $this->app->make(UnitConverter::class);
    }

    public function test_same_unit_is_identity(): void
    {
        $this->assertSame(5.0, $this->conv()->convert(5.0, 'mmol/L', 'mmol/L', 'GLU'));
        $this->assertTrue($this->conv()->sameUnit('mIU/L', 'miu / l'));
        $this->assertTrue($this->conv()->sameUnit('µmol/L', 'umol/l'));
    }

    public function test_glucose_mmol_to_mgdl_and_back(): void
    {
        $c = $this->conv();
        // 5.0 mmol/L ≈ 90 mg/dL
        $this->assertEqualsWithDelta(90.1, $c->convert(5.0, 'mmol/L', 'mg/dL', 'GLU'), 0.5);
        // 90 mg/dL ≈ 5.0 mmol/L
        $this->assertEqualsWithDelta(5.0, $c->convert(90.0, 'mg/dL', 'mmol/L', 'GLU'), 0.05);
    }

    public function test_creatinine_umol_to_mgdl(): void
    {
        // 88.4 µmol/L ≈ 1.0 mg/dL
        $this->assertEqualsWithDelta(1.0, $this->conv()->convert(88.4, 'µmol/L', 'mg/dL', 'CREA'), 0.02);
    }

    public function test_testosterone_ngml_to_nmoll(): void
    {
        // 1 ng/mL ≈ 3.47 nmol/L
        $this->assertEqualsWithDelta(3.47, $this->conv()->convert(1.0, 'ng/mL', 'nmol/L', 'TEST'), 0.05);
    }

    public function test_unknown_unit_returns_null(): void
    {
        // U/L is not a mass/molar concentration — never guess.
        $this->assertNull($this->conv()->convert(30.0, 'U/L', 'mg/dL', 'ALT'));
    }

    public function test_mass_to_molar_without_molecular_weight_returns_null(): void
    {
        // Crossing mass<->molar needs the analyte's molecular weight.
        $this->assertNull($this->conv()->convert(5.0, 'mmol/L', 'mg/dL', null));
        $this->assertNull($this->conv()->convert(5.0, 'mmol/L', 'mg/dL', 'NOPE'));
    }
}

<?php

namespace App\Services;

/**
 * Deterministic lab-unit conversion. When a lab sheet reports an analyte in a
 * different unit than the reference table (Rule #1), the value MUST be
 * converted before comparison — otherwise "normal vs abnormal" is meaningless.
 *
 * Safety contract: if a conversion is not known with certainty, convert()
 * returns null. The caller (LabParser::classify) then flags the analyte as
 * `unknown` rather than comparing across incompatible units. We never guess.
 *
 * Molar <-> mass conversions are analyte-specific (they need the molecular
 * weight), so they only work for analytes in MOLAR_MASS below. Same-dimension
 * conversions (e.g. mg/dL -> g/L) are analyte-independent.
 */
class UnitConverter
{
    /** Molecular weight (g/mol) for analytes that may appear in molar OR mass units. */
    private const MOLAR_MASS = [
        'GLU' => 180.16,
        'CHOL' => 386.65,
        'LDL' => 386.65,
        'HDL' => 386.65,
        'TG' => 885.43,
        'CREA' => 113.12,
        'TEST' => 288.42,
        'E2' => 272.38,
        'PROG' => 314.46,
        'VITD' => 400.64,
        'FE' => 55.85,
        'UREA' => 60.06,
        'BILI' => 584.66,
        'URIC' => 168.11,
    ];

    /**
     * Canonical factors. 'mass' dimension canonicalises to g/L; 'molar' to mol/L.
     *
     * @var array<string,array{0:string,1:float}>
     */
    private const UNITS = [
        // mass concentration -> g/L
        'g/dl' => ['mass', 10.0],
        'mg/dl' => ['mass', 0.01],
        'ug/dl' => ['mass', 1.0e-5],
        'ug/l' => ['mass', 1.0e-6],
        'ng/ml' => ['mass', 1.0e-6],
        'ng/dl' => ['mass', 1.0e-8],
        'pg/ml' => ['mass', 1.0e-9],
        // molar concentration -> mol/L
        'mol/l' => ['molar', 1.0],
        'mmol/l' => ['molar', 1.0e-3],
        'umol/l' => ['molar', 1.0e-6],
        'nmol/l' => ['molar', 1.0e-9],
        'pmol/l' => ['molar', 1.0e-12],
    ];

    /**
     * Normalise a unit string: lower-case, µ/μ -> u, strip spaces.
     */
    public function normalise(string $unit): string
    {
        $u = mb_strtolower(trim($unit));
        $u = str_replace(['µ', 'μ'], 'u', $u);

        return str_replace(' ', '', $u);
    }

    public function sameUnit(string $a, string $b): bool
    {
        return $this->normalise($a) === $this->normalise($b);
    }

    /**
     * Convert $value from one unit to another for a given analyte.
     * Returns null when the conversion is not known with certainty.
     */
    public function convert(float $value, string $from, string $to, ?string $analyteCode = null): ?float
    {
        $from = $this->normalise($from);
        $to = $this->normalise($to);

        if ($from === $to) {
            return $value;
        }

        $f = self::UNITS[$from] ?? null;
        $t = self::UNITS[$to] ?? null;
        if ($f === null || $t === null) {
            return null; // unknown unit (e.g. U/L, %, mIU/L) — never guess
        }

        [$fromDim, $fromFactor] = $f;
        [$toDim, $toFactor] = $t;

        // Canonical value: g/L for mass, mol/L for molar.
        $canonical = $value * $fromFactor;

        if ($fromDim === $toDim) {
            return $canonical / $toFactor;
        }

        // Crossing mass <-> molar needs the molecular weight.
        $mw = $analyteCode !== null ? (self::MOLAR_MASS[strtoupper($analyteCode)] ?? null) : null;
        if ($mw === null) {
            return null;
        }

        if ($fromDim === 'mass' && $toDim === 'molar') {
            $molPerL = $canonical / $mw;           // (g/L) / (g/mol)

            return $molPerL / $toFactor;
        }

        // molar -> mass
        $gPerL = $canonical * $mw;                  // (mol/L) * (g/mol)

        return $gPerL / $toFactor;
    }
}

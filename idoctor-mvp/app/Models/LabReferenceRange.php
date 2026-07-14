<?php

namespace App\Models;

use Illuminate\Database\Eloquent\Model;

class LabReferenceRange extends Model
{
    protected $fillable = [
        'analyte_code', 'analyte_name_ka', 'unit', 'sex',
        'age_min', 'age_max', 'ref_low', 'ref_high',
        'condition', 'source', 'note_ka',
    ];

    protected $casts = [
        'age_min'  => 'integer',
        'age_max'  => 'integer',
        'ref_low'  => 'float',
        'ref_high' => 'float',
    ];
}

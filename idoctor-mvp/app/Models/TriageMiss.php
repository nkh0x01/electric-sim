<?php

namespace App\Models;

use Illuminate\Database\Eloquent\Concerns\HasUuids;
use Illuminate\Database\Eloquent\Model;

class TriageMiss extends Model
{
    use HasUuids;

    protected $fillable = [
        'session_hash', 'message_hash', 'text',
        'expected_category', 'source', 'status',
    ];

    protected $casts = [
        // Same at-rest encryption as message bodies — never plaintext.
        'text' => 'encrypted',
    ];
}

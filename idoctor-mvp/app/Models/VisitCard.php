<?php

namespace App\Models;

use Illuminate\Database\Eloquent\Concerns\HasUuids;
use Illuminate\Database\Eloquent\Model;
use Illuminate\Database\Eloquent\Relations\BelongsTo;

class VisitCard extends Model
{
    use HasUuids;

    protected $fillable = [
        'chat_session_id', 'summary', 'symptoms',
        'questions_for_doctor', 'suggested_specialty',
    ];

    protected $casts = [
        'symptoms'             => 'array',
        'questions_for_doctor' => 'array',
    ];

    public function session(): BelongsTo
    {
        return $this->belongsTo(ChatSession::class, 'chat_session_id');
    }
}

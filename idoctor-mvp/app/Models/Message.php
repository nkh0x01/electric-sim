<?php

namespace App\Models;

use Illuminate\Database\Eloquent\Concerns\HasUuids;
use Illuminate\Database\Eloquent\Model;
use Illuminate\Database\Eloquent\Relations\BelongsTo;

class Message extends Model
{
    use HasUuids;

    protected $fillable = [
        'chat_session_id', 'role', 'content',
        'is_emergency', 'triage_reason', 'model_used',
    ];

    protected $casts = [
        // At-rest encryption of message bodies (GDPR).
        'content' => 'encrypted',
        'is_emergency' => 'boolean',
    ];

    public function session(): BelongsTo
    {
        return $this->belongsTo(ChatSession::class, 'chat_session_id');
    }
}

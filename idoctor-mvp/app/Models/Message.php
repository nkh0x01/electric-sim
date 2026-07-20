<?php

namespace App\Models;

use Illuminate\Database\Eloquent\Concerns\HasUuids;
use Illuminate\Database\Eloquent\Model;
use Illuminate\Database\Eloquent\Relations\BelongsTo;
use Illuminate\Database\Eloquent\Relations\HasMany;

class Message extends Model
{
    use HasUuids;

    protected $fillable = [
        'chat_session_id', 'role', 'content',
        'is_emergency', 'triage_reason', 'model_used', 'latency_ms',
    ];

    protected $casts = [
        // At-rest encryption of message bodies (GDPR).
        'content' => 'encrypted',
        'is_emergency' => 'boolean',
        'latency_ms' => 'integer',
    ];

    public function session(): BelongsTo
    {
        return $this->belongsTo(ChatSession::class, 'chat_session_id');
    }

    /**
     * Content-free record of which KB chunks grounded this answer.
     */
    public function kbReferences(): HasMany
    {
        return $this->hasMany(MessageKbReference::class, 'message_id');
    }
}

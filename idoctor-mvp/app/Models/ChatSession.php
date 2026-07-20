<?php

namespace App\Models;

use Illuminate\Database\Eloquent\Concerns\HasUuids;
use Illuminate\Database\Eloquent\Model;
use Illuminate\Database\Eloquent\Relations\BelongsTo;
use Illuminate\Database\Eloquent\Relations\HasMany;

class ChatSession extends Model
{
    use HasUuids;

    protected $fillable = [
        'user_id', 'consent_given', 'consent_at', 'session_hash',
        'anamnesis_stage', 'message_count', 'locale', 'last_seen_at',
    ];

    protected $casts = [
        'consent_given' => 'boolean',
        'consent_at' => 'datetime',
        'last_seen_at' => 'datetime',
        'message_count' => 'integer',
    ];

    public function user(): BelongsTo
    {
        return $this->belongsTo(User::class);
    }

    public function messages(): HasMany
    {
        return $this->hasMany(Message::class);
    }

    public function labUploads(): HasMany
    {
        return $this->hasMany(LabUpload::class);
    }

    public function visitCards(): HasMany
    {
        return $this->hasMany(VisitCard::class);
    }
}

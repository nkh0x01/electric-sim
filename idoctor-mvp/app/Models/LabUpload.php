<?php

namespace App\Models;

use Illuminate\Database\Eloquent\Concerns\HasUuids;
use Illuminate\Database\Eloquent\Model;
use Illuminate\Database\Eloquent\Relations\BelongsTo;

class LabUpload extends Model
{
    use HasUuids;

    protected $fillable = [
        'chat_session_id', 'original_name', 'mime', 'storage_path',
        'status', 'extracted', 'classified', 'interpretation',
    ];

    protected $casts = [
        'extracted' => 'array',
        'classified' => 'array',
    ];

    public function session(): BelongsTo
    {
        return $this->belongsTo(ChatSession::class, 'chat_session_id');
    }
}

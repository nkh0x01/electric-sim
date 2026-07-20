<?php

namespace App\Models;

use Illuminate\Database\Eloquent\Model;
use Illuminate\Database\Eloquent\Relations\BelongsTo;

/**
 * Content-free link between an assistant message and the KB chunk(s) that
 * grounded it. Stores identifiers and a score only — never message text.
 */
class MessageKbReference extends Model
{
    protected $fillable = [
        'message_id', 'kb_document_id', 'kb_chunk_id', 'specialty', 'score',
    ];

    protected $casts = [
        'score' => 'float',
    ];

    public function message(): BelongsTo
    {
        return $this->belongsTo(Message::class, 'message_id');
    }

    public function document(): BelongsTo
    {
        return $this->belongsTo(KbDocument::class, 'kb_document_id');
    }
}

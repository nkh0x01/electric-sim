<?php

namespace App\Models;

use Illuminate\Database\Eloquent\Model;
use Illuminate\Database\Eloquent\Relations\BelongsTo;

class KbChunk extends Model
{
    protected $fillable = [
        'kb_document_id', 'specialty', 'ordinal', 'content', 'embedding',
    ];

    public function document(): BelongsTo
    {
        return $this->belongsTo(KbDocument::class, 'kb_document_id');
    }
}

<?php

namespace App\Models;

use Illuminate\Database\Eloquent\Model;
use Illuminate\Database\Eloquent\Relations\HasMany;

class KbDocument extends Model
{
    protected $fillable = ['slug', 'title', 'specialty', 'source', 'reviewed_by', 'reviewed_at', 'body'];

    protected $casts = [
        'reviewed_at' => 'datetime',
    ];

    public function chunks(): HasMany
    {
        return $this->hasMany(KbChunk::class);
    }
}

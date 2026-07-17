<?php

namespace App\Models;

use Illuminate\Database\Eloquent\Model;
use Illuminate\Database\Eloquent\Relations\HasMany;

class KbDocument extends Model
{
    protected $fillable = ['slug', 'title', 'specialty', 'source', 'body'];

    public function chunks(): HasMany
    {
        return $this->hasMany(KbChunk::class);
    }
}

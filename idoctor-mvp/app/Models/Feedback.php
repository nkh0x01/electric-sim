<?php

namespace App\Models;

use Illuminate\Database\Eloquent\Concerns\HasUuids;
use Illuminate\Database\Eloquent\Model;

class Feedback extends Model
{
    use HasUuids;

    protected $table = 'feedback';

    protected $fillable = [
        'chat_session_id', 'message_id', 'kind', 'note',
    ];
}

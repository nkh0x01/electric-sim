<?php

namespace App\Models;

use Illuminate\Database\Eloquent\Model;
use Illuminate\Database\Eloquent\Relations\BelongsTo;
use Illuminate\Support\Str;

/**
 * A hashed bearer token for an optional account. The plaintext is shown to the
 * client exactly once (at issue time); only its sha256 is stored here.
 */
class AccountToken extends Model
{
    protected $fillable = ['user_id', 'name', 'token_hash', 'last_used_at'];

    protected $casts = [
        'last_used_at' => 'datetime',
    ];

    public function user(): BelongsTo
    {
        return $this->belongsTo(User::class);
    }

    public static function hashToken(string $plain): string
    {
        return hash('sha256', $plain);
    }

    /**
     * Issue a fresh token for a user. Returns [model, plaintext].
     *
     * @return array{0:self,1:string}
     */
    public static function issue(User $user, ?string $name = null): array
    {
        $plain = Str::random(48);
        $token = self::create([
            'user_id' => $user->id,
            'name' => $name,
            'token_hash' => self::hashToken($plain),
        ]);

        return [$token, $plain];
    }
}

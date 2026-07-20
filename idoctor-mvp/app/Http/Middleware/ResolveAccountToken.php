<?php

namespace App\Http\Middleware;

use App\Models\AccountToken;
use Closure;
use Illuminate\Http\Request;
use Illuminate\Support\Facades\Auth;
use Symfony\Component\HttpFoundation\Response;

/**
 * Minimal bearer-token auth for optional accounts (no Sanctum dependency).
 * Reads "Authorization: Bearer <token>", matches its sha256 against
 * account_tokens, and binds the user for the request. Rejects with 401 when
 * the token is missing or unknown.
 */
class ResolveAccountToken
{
    public function handle(Request $request, Closure $next): Response
    {
        $plain = $request->bearerToken();
        if (! $plain) {
            return response()->json(['error' => 'unauthenticated'], 401);
        }

        $token = AccountToken::where('token_hash', AccountToken::hashToken($plain))->first();
        if (! $token) {
            return response()->json(['error' => 'unauthenticated'], 401);
        }

        $token->forceFill(['last_used_at' => now()])->save();
        Auth::setUser($token->user);
        $request->setUserResolver(fn () => $token->user);
        $request->attributes->set('account_token_id', $token->id);

        return $next($request);
    }
}

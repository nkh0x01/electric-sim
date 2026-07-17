<?php

namespace App\Services;

use Illuminate\Support\Facades\Log;

/**
 * Rule #3: pseudonymised, content-free audit trail.
 *
 * We never log message content. Every event is keyed by an HMAC of the
 * session id (session_hash) plus non-identifying metadata. This lets us
 * measure triage rates, model mix, and errors without storing PHI.
 */
class AuditLogger
{
    /**
     * Derive the stable pseudonym for a session id.
     */
    public static function hash(string $sessionId): string
    {
        $key = (string) config('idoctor.audit.hmac_key');

        return hash_hmac('sha256', $sessionId, $key);
    }

    /**
     * @param  array<string,mixed>  $meta  Non-PHI metadata only.
     */
    public function event(string $sessionId, string $event, array $meta = []): void
    {
        // Defensive: strip anything that looks like free-text content.
        unset($meta['content'], $meta['text'], $meta['message'], $meta['prompt']);

        Log::channel('audit')->info($event, array_merge([
            'session_hash' => self::hash($sessionId),
            'event' => $event,
        ], $meta));
    }
}

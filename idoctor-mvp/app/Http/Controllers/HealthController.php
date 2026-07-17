<?php

namespace App\Http\Controllers;

use App\Models\LabReferenceRange;
use Illuminate\Http\JsonResponse;
use Illuminate\Support\Facades\DB;
use Throwable;

/**
 * Readiness probe for deploys/load-balancers. Reports whether the core
 * dependencies the pipeline needs are wired — without exposing secrets.
 */
class HealthController extends Controller
{
    public function show(): JsonResponse
    {
        $checks = [
            'db'              => $this->dbOk(),
            'lab_ranges'      => $this->labRangesOk(),   // Rule #1 source present
            'triage_layer_a'  => (bool) config('idoctor.triage.redflag_phrases'),
            'triage_layer_b'  => (bool) config('idoctor.triage.llm_enabled'),
            'anthropic_key'   => (bool) config('services.anthropic.key'),
            'voyage_key'      => (bool) config('services.voyage.key'),
            'rag_enabled'     => (bool) config('idoctor.rag.enabled'),
        ];

        // Core = the minimum needed to serve a safe (triage + disclaimer) reply.
        $coreOk = $checks['db'] && $checks['lab_ranges'] && $checks['triage_layer_a'];

        return response()->json([
            'status' => $coreOk ? 'ok' : 'degraded',
            'checks' => $checks,
        ], $coreOk ? 200 : 503);
    }

    private function dbOk(): bool
    {
        try {
            DB::connection()->getPdo();

            return true;
        } catch (Throwable) {
            return false;
        }
    }

    private function labRangesOk(): bool
    {
        try {
            return LabReferenceRange::query()->exists();
        } catch (Throwable) {
            return false;
        }
    }
}

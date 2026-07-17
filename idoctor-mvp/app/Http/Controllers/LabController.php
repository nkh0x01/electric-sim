<?php

namespace App\Http\Controllers;

use App\Models\ChatSession;
use App\Models\LabUpload;
use App\Services\AuditLogger;
use App\Services\LabInterpreter;
use App\Services\LabParser;
use Illuminate\Http\JsonResponse;
use Illuminate\Http\Request;
use Illuminate\Support\Facades\Storage;
use Throwable;

class LabController extends Controller
{
    public function __construct(
        private readonly LabParser $parser,
        private readonly LabInterpreter $interpreter,
        private readonly AuditLogger $audit,
    ) {}

    /**
     * Upload → OCR extract → deterministic classify (Rule #1) → interpret.
     */
    public function store(Request $request): JsonResponse
    {
        $data = $request->validate([
            'session_id' => ['required', 'uuid'],
            'file' => ['required', 'file', 'max:10240', 'mimes:jpg,jpeg,png,pdf'],
            'sex' => ['nullable', 'in:any,m,f'],
            'age' => ['nullable', 'integer', 'min:0', 'max:120'],
            'condition' => ['nullable', 'string', 'max:64'],
        ]);

        $session = ChatSession::findOrFail($data['session_id']);
        abort_unless($session->consent_given, 403, 'consent_required');

        $file = $request->file('file');
        $path = $file->store('lab_uploads');

        $upload = $session->labUploads()->create([
            'original_name' => $file->getClientOriginalName(),
            'mime' => $file->getMimeType(),
            'storage_path' => $path,
            'status' => 'pending',
        ]);

        $this->audit->event($session->id, 'lab.uploaded', ['mime' => $file->getMimeType()]);

        try {
            $bytes = Storage::get($path);
            $extracted = $this->parser->extract($bytes, $file->getMimeType());

            // Rule #1: flags decided deterministically, never by the LLM.
            $classified = $this->parser->classify(
                $extracted,
                $data['sex'] ?? 'any',
                (int) ($data['age'] ?? 30),
                $data['condition'] ?? null,
            );

            $interpretation = $classified !== []
                ? $this->interpreter->interpret($classified)
                : 'ვერ ამოვიკითხე მაჩვენებლები. სცადეთ უფრო მკაფიო ფოტო.';

            $upload->update([
                'status' => 'parsed',
                'extracted' => $extracted,
                'classified' => $classified,
                'interpretation' => $interpretation."\n\n".config('idoctor.disclaimer'),
            ]);

            $this->audit->event($session->id, 'lab.parsed', ['analytes' => count($classified)]);
        } catch (Throwable $e) {
            $upload->update(['status' => 'failed']);
            $this->audit->event($session->id, 'lab.failed', ['error' => substr($e->getMessage(), 0, 120)]);

            return response()->json([
                'id' => $upload->id,
                'status' => 'failed',
                'error' => 'ანალიზის დამუშავება ვერ მოხერხდა.',
            ], 422);
        }

        return response()->json([
            'id' => $upload->id,
            'status' => $upload->status,
            'classified' => $upload->classified,
            'interpretation' => $upload->interpretation,
        ]);
    }

    public function show(LabUpload $upload): JsonResponse
    {
        return response()->json([
            'id' => $upload->id,
            'status' => $upload->status,
            'classified' => $upload->classified,
            'interpretation' => $upload->interpretation,
        ]);
    }
}

<?php

use Illuminate\Database\Migrations\Migration;
use Illuminate\Database\Schema\Blueprint;
use Illuminate\Support\Facades\Schema;

return new class extends Migration
{
    public function up(): void
    {
        Schema::create('lab_uploads', function (Blueprint $table) {
            $table->uuid('id')->primary();
            $table->foreignUuid('chat_session_id')
                ->constrained('chat_sessions')
                ->cascadeOnDelete();

            $table->string('original_name');
            $table->string('mime', 128);
            $table->string('storage_path');
            $table->string('status', 24)->default('pending'); // pending|parsed|failed

            // OCR-extracted analytes (LLM/vision) — raw values only.
            $table->json('extracted')->nullable();

            // Deterministic classification produced by LabParser::classify
            // using lab_reference_ranges (Rule #1). Structure:
            // [{code, name, value, unit, ref_low, ref_high, flag}]
            $table->json('classified')->nullable();

            // Final Georgian interpretation text (LLM, but flags are fixed).
            $table->text('interpretation')->nullable();

            $table->timestamps();
        });
    }

    public function down(): void
    {
        Schema::dropIfExists('lab_uploads');
    }
};

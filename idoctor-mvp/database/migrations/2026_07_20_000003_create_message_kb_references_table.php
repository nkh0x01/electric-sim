<?php

use Illuminate\Database\Migrations\Migration;
use Illuminate\Database\Schema\Blueprint;
use Illuminate\Support\Facades\Schema;

/**
 * Quality loop (Rule #3-friendly): records WHICH knowledge-base documents /
 * chunks grounded a given assistant answer. This is content-free — it stores
 * only KB identifiers, the specialty, and the retrieval score, never any
 * message text. It lets the review queue answer "this 👎 answer leaned on KB
 * doc X" and lets metrics report the most-retrieved specialties, all without
 * touching the encrypted message bodies.
 */
return new class extends Migration
{
    public function up(): void
    {
        Schema::create('message_kb_references', function (Blueprint $table) {
            $table->id();
            $table->foreignUuid('message_id')
                ->constrained('messages')
                ->cascadeOnDelete();
            // Nullable + nullOnDelete: re-embedding recreates chunks, and a KB
            // doc may be pruned; the reference row survives as an anonymous
            // "a chunk was used" marker rather than dangling.
            $table->foreignId('kb_document_id')
                ->nullable()
                ->constrained('kb_documents')
                ->nullOnDelete();
            $table->foreignId('kb_chunk_id')
                ->nullable()
                ->constrained('kb_chunks')
                ->nullOnDelete();
            $table->string('specialty', 64)->nullable()->index();
            $table->float('score')->default(0);
            $table->timestamps();

            $table->index('message_id');
        });
    }

    public function down(): void
    {
        Schema::dropIfExists('message_kb_references');
    }
};

<?php

use Illuminate\Database\Migrations\Migration;
use Illuminate\Database\Schema\Blueprint;
use Illuminate\Support\Facades\DB;
use Illuminate\Support\Facades\Schema;

return new class extends Migration
{
    public function up(): void
    {
        Schema::create('kb_chunks', function (Blueprint $table) {
            $table->id();
            $table->foreignId('kb_document_id')
                ->constrained('kb_documents')
                ->cascadeOnDelete();
            $table->string('specialty', 64)->index();
            $table->unsignedInteger('ordinal')->default(0);
            $table->text('content');
            $table->timestamps();
        });

        $driver = DB::connection()->getDriverName();
        $dim = (int) config('idoctor.embeddings.dimensions', 1024);

        if ($driver === 'pgsql') {
            // Real vector column + IVFFlat index for cosine similarity.
            DB::statement("ALTER TABLE kb_chunks ADD COLUMN embedding vector($dim)");
            DB::statement('CREATE INDEX kb_chunks_embedding_idx ON kb_chunks '
                .'USING ivfflat (embedding vector_cosine_ops) WITH (lists = 100)');
        } else {
            // Fallback for sqlite/CI: store the vector as JSON text.
            Schema::table('kb_chunks', function (Blueprint $table) {
                $table->text('embedding')->nullable();
            });
        }
    }

    public function down(): void
    {
        Schema::dropIfExists('kb_chunks');
    }
};

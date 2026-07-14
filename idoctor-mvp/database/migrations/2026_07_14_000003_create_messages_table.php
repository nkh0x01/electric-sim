<?php

use Illuminate\Database\Migrations\Migration;
use Illuminate\Database\Schema\Blueprint;
use Illuminate\Support\Facades\Schema;

return new class extends Migration
{
    public function up(): void
    {
        Schema::create('messages', function (Blueprint $table) {
            $table->uuid('id')->primary();
            $table->foreignUuid('chat_session_id')
                ->constrained('chat_sessions')
                ->cascadeOnDelete();

            $table->string('role', 16); // user | assistant | system

            // Content is encrypted at rest via the model cast. The column is
            // TEXT because ciphertext is larger than the plaintext.
            $table->text('content');

            $table->boolean('is_emergency')->default(false);
            $table->string('triage_reason', 255)->nullable();
            $table->string('model_used', 64)->nullable();
            $table->timestamps();

            $table->index(['chat_session_id', 'created_at']);
        });
    }

    public function down(): void
    {
        Schema::dropIfExists('messages');
    }
};

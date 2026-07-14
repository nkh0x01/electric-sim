<?php

use Illuminate\Database\Migrations\Migration;
use Illuminate\Database\Schema\Blueprint;
use Illuminate\Support\Facades\Schema;

return new class extends Migration
{
    public function up(): void
    {
        Schema::create('chat_sessions', function (Blueprint $table) {
            $table->uuid('id')->primary();

            // Anonymous by design — no user account required.
            $table->boolean('consent_given')->default(false);
            $table->timestamp('consent_at')->nullable();

            // Pseudonymous handle used in the audit log (HMAC of the uuid).
            $table->string('session_hash', 64)->index();

            // Lightweight anamnesis state machine used to decide when the
            // "generate visit card" button appears.
            $table->string('anamnesis_stage', 32)->default('intake');
            $table->unsignedSmallInteger('message_count')->default(0);

            $table->string('locale', 8)->default('ka');
            $table->timestamp('last_seen_at')->nullable();
            $table->timestamps();
        });
    }

    public function down(): void
    {
        Schema::dropIfExists('chat_sessions');
    }
};

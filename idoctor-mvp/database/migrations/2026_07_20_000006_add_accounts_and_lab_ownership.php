<?php

use Illuminate\Database\Migrations\Migration;
use Illuminate\Database\Schema\Blueprint;
use Illuminate\Support\Facades\Schema;

/**
 * Prompt 4: OPTIONAL accounts. Anonymous use is unchanged — an account only
 * adds persistent lab history/trends for users who choose to register.
 *
 * - account_tokens: hashed bearer tokens (we never store the plaintext).
 * - chat_sessions.user_id / lab_uploads.user_id: nullable ownership. Null =
 *   anonymous (the default). Set only after a user explicitly claims a session.
 * - lab_uploads.chat_session_id becomes nullable so a claimed upload survives
 *   its originating session being erased — the account keeps its history.
 */
return new class extends Migration
{
    public function up(): void
    {
        Schema::create('account_tokens', function (Blueprint $table) {
            $table->id();
            $table->foreignId('user_id')->constrained('users')->cascadeOnDelete();
            $table->string('name')->nullable();          // device / client label
            $table->string('token_hash', 64)->unique();  // sha256 hex of the bearer token
            $table->timestamp('last_used_at')->nullable();
            $table->timestamps();
        });

        Schema::table('chat_sessions', function (Blueprint $table) {
            $table->foreignId('user_id')->nullable()->after('id')
                ->constrained('users')->nullOnDelete();
        });

        Schema::table('lab_uploads', function (Blueprint $table) {
            $table->foreignId('user_id')->nullable()->after('id')
                ->constrained('users')->nullOnDelete();
        });

        // Allow a claimed upload to outlive its origin session.
        Schema::table('lab_uploads', function (Blueprint $table) {
            $table->uuid('chat_session_id')->nullable()->change();
        });
    }

    public function down(): void
    {
        Schema::table('lab_uploads', function (Blueprint $table) {
            $table->dropConstrainedForeignId('user_id');
        });
        Schema::table('chat_sessions', function (Blueprint $table) {
            $table->dropConstrainedForeignId('user_id');
        });
        Schema::dropIfExists('account_tokens');
    }
};

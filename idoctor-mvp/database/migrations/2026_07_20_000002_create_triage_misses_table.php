<?php

use Illuminate\Database\Migrations\Migration;
use Illuminate\Database\Schema\Blueprint;
use Illuminate\Support\Facades\Schema;

/**
 * Safety loop (Rule #3-friendly): candidate triage misses for human review.
 * Pseudonymised (session_hash/message_hash are HMACs) and the text is
 * encrypted at rest — this table never stores a raw session id or plaintext.
 */
return new class extends Migration
{
    public function up(): void
    {
        Schema::create('triage_misses', function (Blueprint $table) {
            $table->uuid('id')->primary();
            $table->string('session_hash')->index();
            $table->string('message_hash')->nullable()->index();
            $table->text('text');                              // encrypted by the model
            $table->string('expected_category', 64)->nullable();
            $table->string('source', 16)->default('feedback'); // feedback | manual
            $table->string('status', 16)->default('new');      // new | reviewed | added_to_suite
            $table->timestamps();
        });
    }

    public function down(): void
    {
        Schema::dropIfExists('triage_misses');
    }
};

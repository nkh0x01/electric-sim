<?php

use Illuminate\Database\Migrations\Migration;
use Illuminate\Database\Schema\Blueprint;
use Illuminate\Support\Facades\Schema;

return new class extends Migration
{
    public function up(): void
    {
        Schema::create('visit_cards', function (Blueprint $table) {
            $table->uuid('id')->primary();
            $table->foreignUuid('chat_session_id')
                ->constrained('chat_sessions')
                ->cascadeOnDelete();

            // Structured summary a patient can hand to a doctor.
            $table->text('summary');           // chief complaint + anamnesis
            $table->json('symptoms')->nullable();
            $table->json('questions_for_doctor')->nullable();
            $table->string('suggested_specialty', 64)->nullable();

            $table->timestamps();
        });
    }

    public function down(): void
    {
        Schema::dropIfExists('visit_cards');
    }
};

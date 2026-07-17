<?php

use Illuminate\Database\Migrations\Migration;
use Illuminate\Database\Schema\Blueprint;
use Illuminate\Support\Facades\Schema;

return new class extends Migration
{
    public function up(): void
    {
        Schema::create('feedback', function (Blueprint $table) {
            $table->uuid('id')->primary();
            $table->foreignUuid('chat_session_id')
                ->nullable()
                ->constrained('chat_sessions')
                ->nullOnDelete();
            $table->foreignUuid('message_id')
                ->nullable()
                ->constrained('messages')
                ->nullOnDelete();

            $table->string('kind', 16);          // up | down | report
            $table->text('note')->nullable();    // optional free text
            $table->timestamps();
        });
    }

    public function down(): void
    {
        Schema::dropIfExists('feedback');
    }
};

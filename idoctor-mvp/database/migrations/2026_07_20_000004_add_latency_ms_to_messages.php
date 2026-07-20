<?php

use Illuminate\Database\Migrations\Migration;
use Illuminate\Database\Schema\Blueprint;
use Illuminate\Support\Facades\Schema;

/**
 * Value loop: response latency (ms) for assistant turns, so metrics can report
 * an average/typical response time. A single content-free integer — no message
 * text is involved.
 */
return new class extends Migration
{
    public function up(): void
    {
        Schema::table('messages', function (Blueprint $table) {
            $table->unsignedInteger('latency_ms')->nullable()->after('model_used');
        });
    }

    public function down(): void
    {
        Schema::table('messages', function (Blueprint $table) {
            $table->dropColumn('latency_ms');
        });
    }
};

<?php

use Illuminate\Database\Migrations\Migration;
use Illuminate\Database\Schema\Blueprint;
use Illuminate\Support\Facades\Schema;

/**
 * Quality loop: mark when a piece of 👎/report feedback has been triaged, so
 * idoctor:feedback-queue can surface only the still-unreviewed items.
 */
return new class extends Migration
{
    public function up(): void
    {
        Schema::table('feedback', function (Blueprint $table) {
            $table->timestamp('reviewed_at')->nullable()->after('note');
        });
    }

    public function down(): void
    {
        Schema::table('feedback', function (Blueprint $table) {
            $table->dropColumn('reviewed_at');
        });
    }
};

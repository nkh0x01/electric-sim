<?php

use Illuminate\Database\Migrations\Migration;
use Illuminate\Database\Schema\Blueprint;
use Illuminate\Support\Facades\Schema;

/**
 * Clinician-review tracking for KB documents. A document is NOT launch-ready
 * until a clinician has reviewed it: reviewed_by null means "seed placeholder,
 * not yet vetted". idoctor:kb-status reports on this.
 */
return new class extends Migration
{
    public function up(): void
    {
        Schema::table('kb_documents', function (Blueprint $table) {
            $table->string('reviewed_by', 255)->nullable()->after('source');
            $table->timestamp('reviewed_at')->nullable()->after('reviewed_by');
        });
    }

    public function down(): void
    {
        Schema::table('kb_documents', function (Blueprint $table) {
            $table->dropColumn(['reviewed_by', 'reviewed_at']);
        });
    }
};

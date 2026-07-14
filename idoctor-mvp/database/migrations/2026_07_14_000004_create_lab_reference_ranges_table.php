<?php

use Illuminate\Database\Migrations\Migration;
use Illuminate\Database\Schema\Blueprint;
use Illuminate\Support\Facades\Schema;

return new class extends Migration
{
    public function up(): void
    {
        // Rule #1: the ONLY authoritative source of "normal vs abnormal".
        // Seeded from database/data/lab_reference_ranges.csv. The LLM never
        // decides whether a value is in range — LabParser::classify does,
        // reading exclusively from this table.
        Schema::create('lab_reference_ranges', function (Blueprint $table) {
            $table->id();
            $table->string('analyte_code', 32)->index();
            $table->string('analyte_name_ka');
            $table->string('unit', 32);
            $table->string('sex', 8)->default('any'); // any | m | f
            $table->unsignedSmallInteger('age_min')->default(0);
            $table->unsignedSmallInteger('age_max')->default(120);
            $table->decimal('ref_low', 12, 4)->nullable();
            $table->decimal('ref_high', 12, 4)->nullable();
            $table->string('condition', 64)->nullable(); // fasting, luteal, ...
            $table->string('source', 128)->nullable();
            $table->text('note_ka')->nullable();
            $table->timestamps();
        });
    }

    public function down(): void
    {
        Schema::dropIfExists('lab_reference_ranges');
    }
};

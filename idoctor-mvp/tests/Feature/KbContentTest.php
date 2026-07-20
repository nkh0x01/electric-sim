<?php

namespace Tests\Feature;

use Illuminate\Foundation\Testing\RefreshDatabase;
use PHPUnit\Framework\Attributes\Group;
use Tests\TestCase;

/**
 * Structural guards for the knowledge-base pack. These do not judge medical
 * content (that is the clinician's job) — they enforce the machine-checkable
 * invariants the seeder and RAG rely on.
 */
#[Group('kb')]
class KbContentTest extends TestCase
{
    use RefreshDatabase;

    private const ALLOWED = ['gynecology', 'urology', 'sti', 'endocrinology', 'general_labs'];

    /**
     * @return array<int,array<string,string>>
     */
    private function parse(): array
    {
        $raw = (string) file_get_contents(database_path('data/kb_starter_pack.md'));
        $raw = preg_replace('/^<!--.*?-->\s*/s', '', $raw) ?? $raw;

        $docs = [];
        foreach (preg_split('/^===DOC===\s*$/m', $raw) ?: [] as $block) {
            $block = trim($block);
            if ($block === '') {
                continue;
            }
            $meta = [];
            foreach (preg_split('/\r?\n/', $block) as $line) {
                if (trim($line) === '') {
                    break;
                }
                if (preg_match('/^(slug|title|specialty|source|reviewed_by):\s*(.+)$/', trim($line), $m)) {
                    $meta[$m[1]] = trim($m[2]);
                }
            }
            $docs[] = $meta;
        }

        return $docs;
    }

    public function test_pack_has_at_least_45_documents(): void
    {
        $this->assertGreaterThanOrEqual(45, count($this->parse()));
    }

    public function test_every_document_is_well_formed_and_unique(): void
    {
        $slugs = [];
        foreach ($this->parse() as $doc) {
            $this->assertArrayHasKey('slug', $doc, 'a document is missing slug');
            $this->assertArrayHasKey('title', $doc, "doc {$doc['slug']} missing title");
            $this->assertContains(
                $doc['specialty'] ?? '',
                self::ALLOWED,
                "doc {$doc['slug']} has invalid specialty '{$doc['specialty']}'"
            );
            $slugs[] = $doc['slug'];
        }

        $this->assertSame(count($slugs), count(array_unique($slugs)), 'duplicate slug in KB pack');
    }

    public function test_seeded_docs_start_unreviewed(): void
    {
        $this->seed(\Database\Seeders\KbSeeder::class);

        // Seed placeholders must not be marked clinician-reviewed.
        $this->assertSame(0, \App\Models\KbDocument::whereNotNull('reviewed_by')->count());
        $this->assertGreaterThanOrEqual(45, \App\Models\KbDocument::count());
    }

    public function test_kb_status_command_runs(): void
    {
        $this->artisan('idoctor:kb-status')->assertExitCode(0);
    }
}

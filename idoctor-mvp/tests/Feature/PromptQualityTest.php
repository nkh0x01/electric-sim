<?php

namespace Tests\Feature;

use App\Services\ChatOrchestrator;
use App\Services\RouterService;
use PHPUnit\Framework\Attributes\Group;
use Tests\TestCase;

/**
 * Guards the answer-quality fixes prompted by live testing, where the cheap
 * model invented Georgian terms ("ხორბალი-ტკივილი") and wrote a lab reference
 * range ("0.4–4.0") from memory while RAG was disabled.
 */
#[Group('quality')]
class PromptQualityTest extends TestCase
{
    public function test_system_prompt_forbids_inventing_terms_and_memory_norms(): void
    {
        $system = $this->app->make(ChatOrchestrator::class)->systemPrompt();

        // Never invent terminology.
        $this->assertStringContainsString('არასოდეს გამოიგონო', $system);
        // Never write a reference range from memory.
        $this->assertStringContainsString('არასოდეს მეხსიერებიდან', $system);
        // Glossary of correct Georgian terms is present.
        $this->assertStringContainsString('ფარისებრი ჯირკვალი', $system);
        $this->assertStringContainsString('ჰიპოთირეოზი', $system);
    }

    public function test_medical_turns_use_the_premium_model(): void
    {
        $router = $this->app->make(RouterService::class);
        $premium = (string) config('idoctor.models.premium');
        $cheap = (string) config('idoctor.models.cheap');

        // A short medical chat turn must still escalate to premium.
        $this->assertSame($premium, $router->pick('რას ნიშნავს TSH?', ['medical' => true]));
        // Lab interpretation escalates too.
        $this->assertSame($premium, $router->pick('short', ['has_lab' => true]));
        // A short non-medical routing string may stay on the cheap model.
        $this->assertSame($cheap, $router->pick('hi', []));
    }
}

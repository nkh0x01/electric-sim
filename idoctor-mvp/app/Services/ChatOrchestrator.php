<?php

namespace App\Services;

use App\Models\ChatSession;
use Closure;

/**
 * Assembles the Claude prompt for a normal (non-emergency) chat turn:
 * system persona + disclaimer contract + RAG context + relevant lab
 * reference ranges, then streams the reply.
 *
 * This is only reached AFTER TriageService has cleared the message
 * (Rule #2: emergencies never get here).
 */
class ChatOrchestrator
{
    /** Model chosen for the most recent streamReply() call. */
    public ?string $lastModel = null;

    public function __construct(
        private readonly ClaudeClient $claude,
        private readonly RouterService $router,
        private readonly RagService $rag,
    ) {
    }

    /**
     * Build the system prompt. RAG snippets and lab ranges are injected as
     * grounded context the model must defer to.
     *
     * @param  array<int,array<string,mixed>>  $ragChunks
     */
    public function systemPrompt(array $ragChunks = [], string $labContext = ''): string
    {
        $scope = implode(', ', (array) config('idoctor.scope_specialties'));
        $disclaimer = (string) config('idoctor.disclaimer');

        $base = <<<PROMPT
        შენ ხარ "iDoctor.ge" — ქართულენოვანი ჯანმრთელობის ნავიგატორი. შენ **არ ხარ ექიმი**
        და **არ სვამ დიაგნოზს**. შენი როლი: მარტივად ახსნა ინფორმაცია, შეაგროვო ანამნეზი
        (სიმპტომები, ხანგრძლივობა, კონტექსტი) და მიმართო შესაბამის სპეციალისტთან.

        ფაზა-1 სფერო: $scope. ამ სფეროს გარეთ კითხვაზე თავაზიანად აღნიშნე, რომ ეს ფაზა-1-ის
        მიღმაა და ურჩიე პროფილის ექიმი.

        წესები:
        - ყოველი სამედიცინო პასუხის ბოლოს დაურთე disclaimer (ქვემოთ მოცემული).
        - არასოდეს დანიშნო კონკრეტული წამალი/დოზა. არასოდეს დაარწმუნო, რომ ადამიანი "ჯანმრთელია".
        - თუ მოცემულია ლაბ. ნორმები ან ცოდნის ბაზის ამონარიდი — დაეყრდენი მხოლოდ მათ.
        - ანამნეზის შეგროვებისას დაუსვი 1–2 დამაზუსტებელი კითხვა ერთ პასუხში, არა მეტი.
        - ისაუბრე თბილად, გასაგებად, ქართულად.

        disclaimer (სიტყვასიტყვით დაურთე ბოლოს):
        $disclaimer
        PROMPT;

        if ($ragChunks !== []) {
            $ctx = collect($ragChunks)
                ->map(fn ($c) => "### {$c['title']}\n{$c['content']}")
                ->implode("\n\n");
            $base .= "\n\n--- ცოდნის ბაზა (დაეყრდენი მხოლოდ ამას) ---\n".$ctx;
        }

        if ($labContext !== '') {
            $base .= "\n\n--- ლაბ. ნორმები (დეტერმინისტული წყარო, Rule #1) ---\n".$labContext;
        }

        return $base;
    }

    /**
     * Stream a reply. Returns the full assistant text (without disclaimer;
     * the caller appends it as a separate step so it is always present).
     *
     * @param  array<int,array{role:string,content:string}>  $history
     */
    public function streamReply(ChatSession $session, array $history, string $userText, Closure $onDelta): string
    {
        $specialty = null; // future: route by detected specialty
        $ragChunks = $this->rag->search($userText, $specialty);

        $system = $this->systemPrompt($ragChunks);

        $messages = array_map(
            fn ($m) => ['role' => $m['role'], 'content' => $m['content']],
            $history
        );
        $messages[] = ['role' => 'user', 'content' => $userText];

        $model = $this->router->pick($userText, ['has_rag' => $ragChunks !== []]);
        $this->lastModel = $model;

        $full = '';
        $this->claude->stream(
            system: $system,
            messages: $messages,
            onDelta: function (string $delta) use (&$full, $onDelta) {
                $full .= $delta;
                $onDelta($delta);
            },
            model: $model,
            maxTokens: (int) config('idoctor.router.max_output_tokens', 1024),
        );

        return $full;
    }
}

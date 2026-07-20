<?php

namespace App\Console\Commands;

use App\Models\ChatSession;
use App\Models\Feedback;
use App\Models\KbDocument;
use App\Models\MessageKbReference;
use Illuminate\Console\Command;

/**
 * Quality loop: a minimal review queue over 👎 / report feedback.
 *
 *   php artisan idoctor:feedback-queue                 # list unreviewed
 *   php artisan idoctor:feedback-queue --kind=report   # only reports
 *   php artisan idoctor:feedback-queue --all           # include reviewed
 *   php artisan idoctor:feedback-queue --mark=<id>     # mark one reviewed
 *
 * For each item it shows the model used and which KB documents grounded the
 * answer, so a reviewer can tell at a glance whether a bad reply came from a
 * weak/placeholder KB doc or from the model itself. It prints the user's own
 * feedback note (voluntary text) but NEVER the encrypted conversation — the
 * message_id is shown so an authorised reviewer can look that up separately.
 */
class FeedbackQueue extends Command
{
    protected $signature = 'idoctor:feedback-queue '
        .'{--kind= : Filter by kind (down|report)} '
        .'{--all : Include already-reviewed items} '
        .'{--limit=30 : Max items to show} '
        .'{--mark= : Mark a feedback id as reviewed and exit}';

    protected $description = 'Review queue for 👎/report feedback, with the KB docs each answer used.';

    public function handle(): int
    {
        if ($id = $this->option('mark')) {
            return $this->markReviewed((string) $id);
        }

        $query = Feedback::query()
            ->whereIn('kind', ['down', 'report'])
            ->with('message')
            ->orderByDesc('created_at')
            ->limit(max(1, (int) $this->option('limit')));

        if ($kind = $this->option('kind')) {
            $query->where('kind', $kind);
        }
        if (! $this->option('all')) {
            $query->whereNull('reviewed_at');
        }

        $items = $query->get();

        if ($items->isEmpty()) {
            $this->info('Feedback queue is empty — nothing to review. 🎉');

            return self::SUCCESS;
        }

        $this->info($items->count().' item(s) to review:');
        $this->line('');

        foreach ($items as $fb) {
            $this->renderItem($fb);
        }

        $this->line('');
        $this->comment('Mark one reviewed:  php artisan idoctor:feedback-queue --mark=<id>');
        $this->comment('Look up the full (encrypted) conversation by message_id in the DB.');

        return self::SUCCESS;
    }

    private function renderItem(Feedback $fb): void
    {
        $icon = $fb->kind === 'report' ? '⚠ report' : '👎 down';
        $age = $fb->created_at?->diffForHumans() ?? 'unknown';
        $model = $fb->message?->model_used ?? '—';
        $session = $fb->chat_session_id
            ? ChatSession::find($fb->chat_session_id)?->session_hash
            : null;

        $this->line("<fg=yellow>{$icon}</>  <fg=gray>{$fb->id}</>  ({$age})");
        $this->line(sprintf('  session_hash: %s', $session ? substr($session, 0, 16).'…' : '—'));
        $this->line(sprintf('  message_id:   %s', $fb->message_id ?? '—'));
        $this->line(sprintf('  model_used:   %s', $model));
        $this->line('  KB grounding: '.$this->kbGroundingFor($fb->message_id));

        if (! empty($fb->note)) {
            $this->line('  note:         '.trim($fb->note));
        }
        if ($fb->reviewed_at) {
            $this->line('  <fg=green>reviewed '.$fb->reviewed_at->diffForHumans().'</>');
        }
        $this->line('');
    }

    /**
     * Content-free grounding summary: which KB docs (slugs) the answer used and
     * whether any of them are still clinician-review-pending (a likely cause of
     * a weak reply).
     */
    private function kbGroundingFor(?string $messageId): string
    {
        if ($messageId === null) {
            return '—';
        }

        $docIds = MessageKbReference::where('message_id', $messageId)
            ->pluck('kb_document_id')
            ->filter()
            ->unique();

        if ($docIds->isEmpty()) {
            return 'no KB context (model answered unaided)';
        }

        $docs = KbDocument::whereIn('id', $docIds)->get(['slug', 'reviewed_by']);
        $unreviewed = $docs->whereNull('reviewed_by')->count();

        $slugs = $docs->pluck('slug')->implode(', ');
        $flag = $unreviewed > 0
            ? " <fg=red>({$unreviewed} unreviewed doc(s))</>"
            : '';

        return $slugs.$flag;
    }

    private function markReviewed(string $id): int
    {
        $fb = Feedback::find($id);
        if (! $fb) {
            $this->error("No feedback with id {$id}.");

            return self::FAILURE;
        }

        $fb->reviewed_at = now();
        $fb->save();

        $this->info("Marked {$id} reviewed.");

        return self::SUCCESS;
    }
}

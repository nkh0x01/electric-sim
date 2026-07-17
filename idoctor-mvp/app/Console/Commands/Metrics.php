<?php

namespace App\Console\Commands;

use App\Models\ChatSession;
use App\Models\Feedback;
use App\Models\LabUpload;
use App\Models\Message;
use App\Models\VisitCard;
use Illuminate\Console\Command;

/**
 * Content-free product metrics (Rule #3 friendly): every number here is a
 * count or rate — never message content. Useful for the closed-beta
 * MAU / triage-rate / NPS-proxy tracking called for in the strategy.
 *
 *   php artisan idoctor:metrics --days=7
 */
class Metrics extends Command
{
    protected $signature = 'idoctor:metrics {--days=7 : Window in days}';

    protected $description = 'Report content-free product metrics for iDoctor.';

    public function handle(): int
    {
        $days = max(1, (int) $this->option('days'));
        $since = now()->subDays($days);

        $sessions   = ChatSession::where('created_at', '>=', $since)->count();
        $active     = ChatSession::where('last_seen_at', '>=', $since)->count();
        $consented  = ChatSession::where('consent_given', true)
            ->where('created_at', '>=', $since)->count();

        $userMsgs   = Message::where('role', 'user')->where('created_at', '>=', $since)->count();
        $emergencies = Message::where('is_emergency', true)->where('created_at', '>=', $since)->count();

        $labs       = LabUpload::where('created_at', '>=', $since)->count();
        $labsParsed = LabUpload::where('status', 'parsed')->where('created_at', '>=', $since)->count();
        $cards      = VisitCard::where('created_at', '>=', $since)->count();

        $fbUp   = Feedback::where('kind', 'up')->where('created_at', '>=', $since)->count();
        $fbDown = Feedback::where('kind', 'down')->where('created_at', '>=', $since)->count();
        $fbRep  = Feedback::where('kind', 'report')->where('created_at', '>=', $since)->count();

        $emergencyRate = $userMsgs > 0 ? $emergencies / $userMsgs : 0.0;
        $consentRate   = $sessions > 0 ? $consented / $sessions : 0.0;
        $satisfaction  = ($fbUp + $fbDown) > 0 ? $fbUp / ($fbUp + $fbDown) : 0.0;

        $this->info("iDoctor metrics — last {$days} day(s)");
        $this->table(['metric', 'value'], [
            ['sessions created',      $sessions],
            ['active sessions',       $active],
            ['consent rate',          sprintf('%.1f%%', $consentRate * 100)],
            ['user messages',         $userMsgs],
            ['emergency screens',     $emergencies],
            ['emergency rate',        sprintf('%.2f%%', $emergencyRate * 100)],
            ['lab uploads',           "$labsParsed/$labs parsed"],
            ['visit cards',           $cards],
            ['feedback 👍/👎/⚠',       "$fbUp / $fbDown / $fbRep"],
            ['satisfaction (👍 share)', sprintf('%.1f%%', $satisfaction * 100)],
        ]);

        return self::SUCCESS;
    }
}

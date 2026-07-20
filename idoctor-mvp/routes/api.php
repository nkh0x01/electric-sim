<?php

use App\Http\Controllers\AccountController;
use App\Http\Controllers\ChatController;
use App\Http\Controllers\FeedbackController;
use App\Http\Controllers\HealthController;
use App\Http\Controllers\LabController;
use App\Http\Controllers\SessionController;
use App\Http\Controllers\VisitCardController;
use Illuminate\Support\Facades\Route;

// Readiness probe (deploy / load balancer)
Route::get('/health', [HealthController::class, 'show']);

// Anonymous sessions + consent + GDPR erasure
Route::post('/session', [SessionController::class, 'store']);
Route::post('/session/{session}/consent', [SessionController::class, 'consent']);
Route::delete('/session/{session}/data', [SessionController::class, 'destroyData']);

// Chat pipeline (SSE)
Route::post('/chat', [ChatController::class, 'send']);

// Lab uploads
Route::post('/lab', [LabController::class, 'store']);
Route::get('/lab/{upload}', [LabController::class, 'show']);

// Visit card
Route::post('/visit-card', [VisitCardController::class, 'generate']);

// Feedback
Route::post('/feedback', [FeedbackController::class, 'store']);

// Optional accounts (Prompt 4). Anonymous use never requires these.
Route::post('/account/register', [AccountController::class, 'register']);
Route::post('/account/login', [AccountController::class, 'login']);

Route::middleware('account.auth')->group(function () {
    Route::post('/account/logout', [AccountController::class, 'logout']);
    Route::get('/account', [AccountController::class, 'me']);
    Route::post('/account/claim-session', [AccountController::class, 'claimSession']);
    Route::get('/account/labs', [AccountController::class, 'labHistory']);
    Route::get('/account/labs/trends', [AccountController::class, 'labTrends']);
});

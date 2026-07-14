<?php

use App\Http\Controllers\ChatController;
use App\Http\Controllers\FeedbackController;
use App\Http\Controllers\LabController;
use App\Http\Controllers\SessionController;
use App\Http\Controllers\VisitCardController;
use Illuminate\Support\Facades\Route;

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

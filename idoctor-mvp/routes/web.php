<?php

use App\Http\Controllers\VisitCardController;
use Illuminate\Support\Facades\Route;

Route::get('/', fn () => view('chat'))->name('chat');

// PDF download lives on web so the browser can open it directly.
Route::get('/visit-card/{card}/pdf', [VisitCardController::class, 'pdf'])
    ->name('visit-card.pdf');

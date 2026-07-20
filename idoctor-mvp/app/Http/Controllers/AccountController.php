<?php

namespace App\Http\Controllers;

use App\Models\AccountToken;
use App\Models\ChatSession;
use App\Models\User;
use App\Services\AuditLogger;
use App\Services\LabHistoryService;
use Illuminate\Http\JsonResponse;
use Illuminate\Http\Request;
use Illuminate\Support\Facades\Hash;
use Illuminate\Validation\ValidationException;

/**
 * Optional accounts (Prompt 4). Registration is never required to use iDoctor;
 * an account only unlocks persistent lab history/trends. Bearer tokens are
 * issued here and validated by the ResolveAccountToken middleware.
 */
class AccountController extends Controller
{
    public function __construct(
        private readonly AuditLogger $audit,
        private readonly LabHistoryService $history,
    ) {}

    public function register(Request $request): JsonResponse
    {
        $data = $request->validate([
            'name' => ['nullable', 'string', 'max:120'],
            'email' => ['required', 'email', 'max:190', 'unique:users,email'],
            'password' => ['required', 'string', 'min:8', 'max:200'],
        ]);

        $user = User::create([
            'name' => $data['name'] ?? '',
            'email' => $data['email'],
            'password' => Hash::make($data['password']),
        ]);

        [, $plain] = AccountToken::issue($user, $request->userAgent());
        $this->audit->event('account:'.$user->id, 'account.registered');

        return response()->json([
            'user' => $this->profile($user),
            'token' => $plain,
        ], 201);
    }

    public function login(Request $request): JsonResponse
    {
        $data = $request->validate([
            'email' => ['required', 'email'],
            'password' => ['required', 'string'],
        ]);

        $user = User::where('email', $data['email'])->first();
        if (! $user || ! Hash::check($data['password'], $user->password)) {
            throw ValidationException::withMessages([
                'email' => ['არასწორი ელფოსტა ან პაროლი.'],
            ]);
        }

        [, $plain] = AccountToken::issue($user, $request->userAgent());
        $this->audit->event('account:'.$user->id, 'account.login');

        return response()->json([
            'user' => $this->profile($user),
            'token' => $plain,
        ]);
    }

    public function logout(Request $request): JsonResponse
    {
        // Revoke only the token used for this request.
        if ($tokenId = $request->attributes->get('account_token_id')) {
            AccountToken::whereKey($tokenId)->delete();
        }

        return response()->json(['ok' => true]);
    }

    public function me(Request $request): JsonResponse
    {
        return response()->json(['user' => $this->profile($request->user())]);
    }

    /**
     * Attach an anonymous session (and its lab uploads) to the account, so the
     * work done before signing in shows up in the user's history. A session
     * already owned by someone else is refused.
     */
    public function claimSession(Request $request): JsonResponse
    {
        $data = $request->validate([
            'session_id' => ['required', 'uuid'],
        ]);

        $user = $request->user();
        $session = ChatSession::findOrFail($data['session_id']);

        if ($session->user_id !== null && $session->user_id !== $user->id) {
            return response()->json(['error' => 'session_owned_by_another_account'], 409);
        }

        $session->update(['user_id' => $user->id]);
        // Backfill ownership of this session's uploads (only the still-unowned).
        $session->labUploads()->whereNull('user_id')->update(['user_id' => $user->id]);

        $this->audit->event($session->id, 'account.session_claimed');

        return response()->json([
            'claimed' => true,
            'labs' => $user->labUploads()->where('status', 'parsed')->count(),
        ]);
    }

    public function labHistory(Request $request): JsonResponse
    {
        return response()->json(['uploads' => $this->history->history($request->user())]);
    }

    public function labTrends(Request $request): JsonResponse
    {
        return response()->json(['trends' => $this->history->trends($request->user())]);
    }

    /**
     * @return array<string,mixed>
     */
    private function profile(User $user): array
    {
        return [
            'id' => $user->id,
            'name' => $user->name,
            'email' => $user->email,
        ];
    }
}

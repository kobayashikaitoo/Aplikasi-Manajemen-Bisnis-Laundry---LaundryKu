<?php

namespace App\Services;

use App\Models\User;
use Firebase\JWT\JWT;
use Firebase\JWT\Key;
use Exception;
use RuntimeException;

class JwtService
{
    private string $secret;
    private int $ttl;

    public function __construct()
    {
        $secret = config('app.jwt_secret', env('JWT_SECRET'));

        if (empty($secret)) {
            // Pada mode production, wajib disetel di .env demi keamanan
            if (app()->environment('production')) {
                throw new RuntimeException('JWT_SECRET wajib dikonfigurasi di file .env pada environment production.');
            }

            // Fallback khusus environment lokal development agar teman/penguji tidak error jika belum mengisi .env
            $secret = 'laundryku_development_jwt_secret_key_demo_2026';
        }

        $this->secret = (string) $secret;
        $this->ttl = (int) config('app.jwt_ttl', env('JWT_TTL', 86400));
    }

    public function generateToken(User $user): string
    {
        $payload = [
            'iss' => config('app.url', 'http://localhost:8000'),
            'sub' => $user->id,
            'role' => $user->role?->name,
            'email' => $user->email,
            'iat' => time(),
            'exp' => time() + $this->ttl,
        ];

        return JWT::encode($payload, $this->secret, 'HS256');
    }

    public function decodeToken(string $token): ?object
    {
        try {
            return JWT::decode($token, new Key($this->secret, 'HS256'));
        } catch (Exception) {
            return null;
        }
    }
}

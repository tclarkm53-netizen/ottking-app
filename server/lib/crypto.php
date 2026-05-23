<?php

declare(strict_types=1);

require_once __DIR__ . '/../config.php';

function sign_payload(string $payload): string
{
    return hash_hmac('sha256', $payload, HMAC_SECRET);
}

function verify_signature(string $payload, string $signature): bool
{
    return hash_equals(sign_payload($payload), $signature);
}

function encrypt_payload(string $plainText): string
{
    $iv = random_bytes(12);
    $cipherText = openssl_encrypt(
        $plainText,
        'aes-256-gcm',
        ENCRYPTION_KEY,
        OPENSSL_RAW_DATA,
        $iv,
        $tag
    );

    if ($cipherText === false || $tag === null) {
        throw new RuntimeException('Failed to encrypt payload');
    }

    return base64_encode($iv) . '.' . base64_encode($cipherText . $tag);
}

function decrypt_payload(string $encryptedPayload): string
{
    $parts = explode('.', $encryptedPayload, 2);
    if (count($parts) !== 2) {
        throw new InvalidArgumentException('Encrypted payload format is invalid');
    }

    $iv = base64_decode($parts[0], true);
    $combined = base64_decode($parts[1], true);

    if ($iv === false || $combined === false || strlen($combined) <= 16) {
        throw new InvalidArgumentException('Encrypted payload is malformed');
    }

    $tag = substr($combined, -16);
    $cipherText = substr($combined, 0, -16);

    $plainText = openssl_decrypt(
        $cipherText,
        'aes-256-gcm',
        ENCRYPTION_KEY,
        OPENSSL_RAW_DATA,
        $iv,
        $tag
    );

    if ($plainText === false) {
        throw new RuntimeException('Failed to decrypt payload');
    }

    return $plainText;
}

function secure_response(array $payload): array
{
    $json = json_encode($payload, JSON_UNESCAPED_SLASHES | JSON_UNESCAPED_UNICODE);
    if ($json === false) {
        throw new RuntimeException('Failed to encode response payload');
    }

    return [
        'encrypted_payload' => encrypt_payload($json),
        'signature' => sign_payload($json),
    ];
}

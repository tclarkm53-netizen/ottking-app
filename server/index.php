<?php

declare(strict_types=1);

require_once __DIR__ . '/config.php';
require_once __DIR__ . '/lib/crypto.php';
require_once __DIR__ . '/lib/storage.php';

header('Content-Type: application/json');

function send_response(int $statusCode, array $body): void
{
    http_response_code($statusCode);
    echo json_encode($body, JSON_UNESCAPED_SLASHES | JSON_UNESCAPED_UNICODE);
    exit;
}

function get_request_path(): string
{
    $uri = parse_url($_SERVER['REQUEST_URI'] ?? '/', PHP_URL_PATH) ?: '/';
    $scriptName = $_SERVER['SCRIPT_NAME'] ?? '/';
    $scriptDir = dirname($scriptName);

    if ($scriptDir !== '/' && $scriptDir !== '.' && str_starts_with($uri, $scriptDir)) {
        $uri = substr($uri, strlen($scriptDir));
    }

    if (str_starts_with($uri, '/index.php')) {
        $uri = substr($uri, strlen('/index.php'));
    }

    $uri = trim($uri, '/');
    return $uri === '' ? 'health' : $uri;
}

function get_secure_request_payload(): array
{
    $apiKey = $_SERVER['HTTP_X_API_KEY'] ?? '';
    $timestamp = $_SERVER['HTTP_X_TIMESTAMP'] ?? '';
    $signature = $_SERVER['HTTP_X_SIGNATURE'] ?? '';

    if ($apiKey !== APP_KEY_ID) {
        throw new InvalidArgumentException('Invalid API key');
    }

    if ($timestamp === '' || $signature === '') {
        throw new InvalidArgumentException('Missing request signature headers');
    }

    $timestampValue = strtotime($timestamp);
    if ($timestampValue === false || abs(time() - $timestampValue) > 300) {
        throw new InvalidArgumentException('Expired request timestamp');
    }

    $rawBody = file_get_contents('php://input') ?: '{}';
    $body = json_decode($rawBody, true);
    if (!is_array($body) || !isset($body['encrypted_payload']) || !is_string($body['encrypted_payload'])) {
        throw new InvalidArgumentException('Request payload is invalid');
    }

    $endpoint = get_request_path();
    $signedPayload = $timestamp . '|' . $endpoint . '|' . $body['encrypted_payload'];

    if (!verify_signature($signedPayload, $signature)) {
        throw new InvalidArgumentException('Request signature verification failed');
    }

    $decoded = json_decode(decrypt_payload($body['encrypted_payload']), true);
    if (!is_array($decoded)) {
        throw new InvalidArgumentException('Encrypted request payload is invalid');
    }

    return $decoded;
}

function get_catalog(): array
{
    return fetch_catalog();
}

try {
    $endpoint = get_request_path();

    switch ($endpoint) {
        case 'health':
            send_response(200, ['status' => 'ok', 'service' => 'OTTKing API']);
            break;

        case 'catalog':
            $requestData = get_secure_request_payload();
            $catalog = get_catalog();
            send_response(200, secure_response($catalog));
            break;

        case 'auth/login':
            $requestData = get_secure_request_payload();
            $session = authenticate_user((string) ($requestData['email'] ?? ''), (string) ($requestData['password'] ?? ''));
            send_response(200, secure_response($session));
            break;

        case 'auth/register':
            $requestData = get_secure_request_payload();
            $session = register_user((string) ($requestData['email'] ?? ''), (string) ($requestData['password'] ?? ''));
            send_response(200, secure_response($session));
            break;

        default:
            send_response(404, ['error' => 'Endpoint not found']);
            break;
    }
} catch (InvalidArgumentException | RuntimeException | JsonException $exception) {
    send_response(400, ['error' => $exception->getMessage()]);
} catch (Throwable $exception) {
    send_response(500, ['error' => 'Internal server error']);
}

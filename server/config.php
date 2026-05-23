<?php

declare(strict_types=1);

const APP_KEY_ID = 'ottking-mobile';
define('HMAC_SECRET', getenv('HMAC_SECRET_KEY') ?: 'ottking-hmac-secret-2026');
define('ENCRYPTION_KEY', getenv('ENCRYPTION_KEY') ?: 'ottking_secure_32byte_key_2026AB');
define('API_BASE_URL', getenv('API_BASE_URL') ?: 'http://localhost:8000');

define('DB_HOST', getenv('DB_HOST') ?: '127.0.0.1');
define('DB_PORT', (int) (getenv('DB_PORT') ?: '3306'));
define('DB_NAME', getenv('DB_NAME') ?: 'ottking_app');
define('DB_USER', getenv('DB_USER') ?: 'root');
define('DB_PASS', getenv('DB_PASS') ?: '');

# OTTKing PHP Backend

This folder contains a MySQLi-backed PHP backend for the OTTKing Flutter client.

## Endpoints

- `POST /catalog`
- `POST /auth/login`
- `POST /auth/register`
- `GET /health`

## Database Setup

1. Create a MySQL database in phpMyAdmin.
2. Import [server/sql/schema.sql](server/sql/schema.sql)
3. Import [server/sql/seed.sql](server/sql/seed.sql)
4. Update DB credentials in [server/config.php](server/config.php)

## Security

- Every request must contain:
  - `x-api-key`
  - `x-timestamp`
  - `x-signature`
- Request payload must be encrypted using AES-256-GCM.
- Responses are encrypted and signed with HMAC-SHA256.

## Run locally

Use Apache + mod_rewrite, or serve the `server` folder with PHP:

```bash
php -S localhost:8000 server/index.php
```

Then point your Flutter app to `http://localhost:8000`.

## Notes

- The backend now uses `mysqli` for all reads/writes.
- `server/lib/db.php` is the shared connection layer.
- `server/lib/storage.php` contains catalog and auth queries.

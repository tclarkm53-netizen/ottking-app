# OTTKing Security Guide

## 1. Transport Security

All requests should be sent over HTTPS.
Do not expose live stream URLs in plain text in client assets.

## 2. Request Signing

Every client request should include:
- `x-api-key`
- `x-timestamp`
- `x-signature`

Signature formula:
`HMAC-SHA256(timestamp | endpoint | encrypted_payload, secret)`

## 3. Payload Encryption

The application encrypts request payloads before sending and decrypts server responses before parsing.
Use AES-GCM for authenticated encryption.

## 4. Local Storage

- Use `flutter_secure_storage` for auth tokens
- Keep user profile data minimal
- Never persist raw stream URLs if not necessary

## 5. Production Hardening

- Rotate keys and HMAC secrets regularly
- Add certificate pinning with `http` interceptors if required
- Validate server response signatures before using data
- Use environment-based configuration in CI/CD

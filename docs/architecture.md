# OTTKing Architecture Guide

## 1. Goal

This boilerplate is designed for a secure, multi-platform live TV streaming app with:
- touch-first mobile UI
- smart TV remote-friendly navigation
- encrypted API communication using HMAC and AES-GCM
- modular, provider-based state management

## 2. Folder Structure

- `lib/main.dart` – app bootstrap and dependency injection
- `lib/app/app.dart` – Material app and route configuration
- `lib/core/constants` – application constants
- `lib/core/theme` – light/dark theme definitions
- `lib/data/models` – data models for channels, banners, plans, users
- `lib/data/services` – secure API client, encryption, device detection, secure storage
- `lib/data/repositories` – API repository layer
- `lib/presentation/providers` – state management using Provider
- `lib/presentation/screens` – splash, home, player, settings screens
- `lib/presentation/widgets` – reusable UI widgets

## 3. State Management

Provider is used for a clean, low-boilerplate architecture.

Recommended flow:
1. `main.dart` creates services and `AppState`
2. `AppState.bootstrap()` loads secure configuration and catalog
3. Screens consume `AppState` via `context.watch`
4. UI updates are localized and predictable

## 4. Security Model

- Every API request is signed with HMAC-SHA256
- Request/response payloads are encrypted with AES-GCM
- Authentication tokens are stored in `flutter_secure_storage`
- Runtime settings are persisted in `shared_preferences`

## 5. Smart TV UX

- `DeviceModeService` identifies smart TV mode
- `RawKeyboardListener` supports D-pad navigation
- `FocusGlowButton` provides focus border/glow visuals
- `PlayerScreen` allows channel zapping via Up/Down and hides visual channel lists

## 6. Extend to Production

Replace placeholders in `AppConstants` with server-issued secrets.
Point `apiBaseUrl` to your secure backend endpoint.
Implement server-side encryption and HMAC verification for all payloads.

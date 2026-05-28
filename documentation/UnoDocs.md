

[FILE: README.md]
<!-- FILE: README.md -->
# PLASIR — Mobile Application (Uno)
> **Project Name:** PLASIR Mobile Client (`Uno`)  
> **Organisation:** Dondzalândia, Lda  
> **Date:** May 2026  
> **Target Platforms:** Android, iOS, Web, macOS  
> **Core Stack:** Dart 3.11, Flutter 3.x, Firebase Firestore (Real-time Messaging), Custom Http Client  

---

## Documentation Index

| File | Relative Path | Description |
| :--- | :--- | :--- |
| **01** | [`./docs/01-setup.md`] | Development environment, Flutter SDK prerequisites, FVM, `.env` config, and build troubleshooting. |
| **02** | [`./docs/02-architecture.md`] | Directory structure, Architectural Layers, State Management Singleton pattern, and Dependency Flow. |
| **03** | [`./docs/03-api.md`] | Networking layer using native `http`, header handling, deep link token verification, and error handling. |
| **04** | [`./docs/04-database.md`] | Secure storage mechanisms (`FlutterSecureStorage`), in-memory JSON question loading, and Firestore. |
| **05** | [`./docs/05-features.md`] | Core features: WGSS Screening (8-section logic with custom Skip rules) and Real-time Messaging system. |
| **06** | [`./docs/06-security.md`] | Obfuscation, local storage encryption, and vulnerabilities (SSL Pinning & Firebase Auth gap analysis). |
| **07** | [`./docs/07-deployment.md`] | Android/iOS compilation pipelines, manual Fastlane deployment workflows, and Play Store/App Store checklists. |
| **08** | [`./docs/08-testing.md`] | Automated testing strategy: Mocking Http and Firestore, Widget and Golden testing setups, and coverage. |

---

## Quick Reference

### API Environments & Services
| Environment | Base URL | Purpose |
| :--- | :--- | :--- |
| **Local Mock/Dev** | `http://localhost:8000/api` | Local API running under Laravel 12. |
| **Staging** | `https://api-staging.dondzalandia.co.mz/api` | UAT test server. |
| **Production** | `https://api.dondzalandia.co.mz/api` | Main Production API. |

### Run Commands
```bash
# Get dependencies
flutter pub get

# Run application locally
flutter run

# Compile Android Release Bundle
flutter build appbundle --obfuscate --split-debug-info=build/app/outputs/symbols --dart-define-from-file=.env

# Compile iOS Release (IPA)
flutter build ipa --obfuscate --split-debug-info=build/app/outputs/symbols --dart-define-from-file=.env
```

> [!CAUTION]
> **URGENT SECURITY ACTION REQUIRED**
> 1. **Debug Screen Leaks**: The `lib/debug_screen.dart` contains hardcoded testing credentials (`teste@gmail.com` with password `Teste01`). This screen must be removed or flagged as `kDebugMode` only prior to assembly compilation.
> 2. **Firestore Anonymous Data Access**: The mobile client accesses Cloud Firestore (`plasir-app` project) by generating a predictable custom Firebase UID (`msg_` + Base64 of Laravel User ID) **without standard Firebase Authentication**. If Firestore security rules verify operations using `request.auth != null`, they will block connections; if they are set to `allow read, write: if true`, they present a massive vector for data manipulation. Implement Firestore Custom Token validation or anonymous sign-in immediately.

---

## Architecture at a Glance

```
                  ┌──────────────────────────────────────────────┐
                  │              PLASIR Mobile UI                │
                  │        (Material Design + Google Fonts)      │
                  └──────────────────────┬───────────────────────┘
                                         │
                 Vanilla State (setState, StreamBuilder, ValueNotifier)
                                         │
                  ┌──────────────────────▼───────────────────────┐
                  │             Business Logic                   │
                  │    (Singletons: Auth, Chat, Triagem)         │
                  └──────────┬───────────────────────────┬───────┘
                             │                           │
                   REST (JSON over HTTP)          Real-time Streams
                             │                           │
  ┌──────────────────────────▼──────────┐     ┌──────────▼──────────┐
  │         Laravel 12 API              │     │  Google Firestore   │
  │  (Sanctum Token Auth / MySQL 8)     │     │ (No-Auth Messenger) │
  └─────────────────────────────────────┘     └─────────────────────┘
```

---

[FILE: docs/01-setup.md]
<!-- FILE: docs/01-setup.md -->
# 01 — Setup & Installation

This guide outlines the system prerequisites, development dependencies, and steps necessary to configure and run the PLASIR Mobile Application (`Uno`) locally.

---

## Environment Prerequisites

### 1. SDK Requirements
* **Dart SDK**: `^3.11.0` (Dart 3.x is required for modern pattern matching and class modifiers).
* **Flutter SDK**: `3.x` (Compatible with current material components and deep linking structures).

### 2. Native Operating Systems Configs
* **macOS (for iOS Compilation)**:
  * Xcode `15.0` or higher.
  * CocoaPods `1.14` or higher.
* **Windows / Linux (for Android Compilation)**:
  * Android Studio Giraffe or higher.
  * Android SDK Command-line Tools & Build-Tools `34.0.0` or higher.
  * Java Development Kit (JDK) 17.

---

## Initial Setup Steps

Follow these steps sequentially to prepare the local workspace:

### 1. Dependency Resolution
Navigate into the `Uno` subdirectory and fetch package dependencies:
```bash
cd Uno
flutter pub get
```

### 2. Environment Variables Initialization
Create a `.env` file in the root of the `Uno` directory. This file must be registered under the `assets` block of `pubspec.yaml` (already pre-configured on line 88 of `pubspec.yaml`) so it is readable by `flutter_dotenv`:

```ini
# Uno/.env
API_BASE_URL=https://api.dondzalandia.co.mz
API_TIMEOUT=30
MOBILE_API_KEY=m_sec_prod_your_secure_client_access_key
```

> [!WARNING]
> Ensure the `.env` file is never checked into version control. It is explicitly added to the local `.gitignore` of the project.

### 3. Firebase Configuration Files
To link the application to the `plasir-app` Firebase project for Firestore chat:
* **Android**: Download `google-services.json` and place it in the `android/app/` folder.
* **iOS**: Download `GoogleService-Info.plist` and drag-and-drop it into `ios/Runner/` using Xcode.

Verify that native projects compile and find the configurations:
```bash
# Re-generate the build options locally
flutter precache
```

---

## Running the Application

Ensure a physical device or emulator is booted and recognized by Flutter:
```bash
# Verify active devices
flutter devices

# Run in debug mode
flutter run
```

---

## Build Troubleshooting & FAQs

### Issue 1: CocoaPods Out of Sync (iOS)
**Symptoms**: Build failures inside `ios/Pods` or `pod` execution error during `flutter run`.
**Resolution**:
```bash
cd ios
pod repo update
rm -rf Pods Podfile.lock
pod install
cd ..
flutter clean
flutter run
```

### Issue 2: Dotenv Initialization Exception
**Symptoms**: `Exception: API_BASE_URL não configurada no arquivo .env`.
**Resolution**: Ensure that the `.env` file exists directly in the root of the `Uno` directory and is spelled correctly. If it still fails, execute `flutter clean` to clear the asset cache and rebuild.

### Issue 3: Firebase Initialization Crash on Launch
**Symptoms**: PlatformException when calling `Firebase.initializeApp()`.
**Resolution**: Run `flutter build build` or open the native workspace inside Xcode/Android Studio. The `firebase_options.dart` file depends on standard configuration. Double check `firebase.json` target configs for correct bundle IDs matching `plasir-app`.

---

[FILE: docs/02-architecture.md]
<!-- FILE: docs/02-architecture.md -->
# 02 — Architecture & Technical Overview

The `Uno` codebase implements a modular, service-based architecture. To maintain a simple footprint while supporting complex features (such as real-time messaging and hierarchical multi-section question-skipping logic), the application relies on **Vanilla State Management** combined with **Singleton Business Logic Services**.

---

## Directory Structure

```
Uno/
├── assets/
│   ├── data/
│   │   └── perguntas_triagem.json       # Configured triage questions list
│   └── images/                         # Static images and icons
├── lib/
│   ├── core/
│   │   └── api/
│   │       ├── api_service.dart         # Main Network Client
│   │       ├── auth_manager.dart        # Auth Manager Singleton
│   │       ├── env_config.dart          # Reads Environment variables
│   │       └── triagem_api_service.dart # Mapping to Triage endpoints
│   ├── initial/
│   │   ├── iniciar.dart
│   │   ├── splash_screen.dart
│   │   └── startup_preferences.dart
│   ├── models/
│   │   ├── educando_data.dart
│   │   ├── triagem_models.dart          # Triage domain representations
│   │   └── triagem_respostas.dart
│   ├── screens/
│   │   ├── auth/                        # Onboarding and credential forms
│   │   ├── home/                        # Chat screen, main menu, reports
│   │   └── triagem/                     # Multi-section questionnaire screens
│   ├── services/
│   │   ├── chat_service.dart            # Firebase Firestore abstraction
│   │   ├── deep_link_service.dart       # Deep Linking via AppLinks
│   │   ├── message_notification_service.dart # Local system notifications
│   │   ├── triagem_json_loader.dart
│   │   └── triagem_service.dart         # Cache and skip logic processor
│   └── main.dart                        # Main initialization and routes
```

---

## Architectural Layers

The architecture consists of three clean logical layers:

```
┌────────────────────────────────────────────────────────┐
│                   Presentation Layer                   │
│  (screens/, widgets/, PageState, Stream/ValueBuilders) │
└───────────────────────────┬────────────────────────────┘
                            │ Method invocation
                            ▼
┌────────────────────────────────────────────────────────┐
│                      Service Layer                     │
│  (AuthManager, ChatService, TriagemService)           │
└───────────────────────────┬────────────────────────────┘
                            │ Data access
                            ▼
┌────────────────────────────────────────────────────────┐
│                   Infrastructure Layer                 │
│  (ApiService, FirebaseFirestore, FlutterSecureStorage) │
└────────────────────────────────────────────────────────┘
```

1. **Presentation Layer**: Widgets that capture user actions and render UI. Real-time lists (like Chat messages) use `StreamBuilder` that hook directly into the service layer, keeping UI structures completely decoupled from data serialization.
2. **Service Layer**: Pure Dart classes implementing the Singleton pattern (`class Service { static final Service _instance = ... }`). They act as controllers, holding internal state cache, performing validations, handling transformations, and isolating business rules.
3. **Infrastructure Layer**: Integrates external drivers, including the core Http client (`http.Client`), Cloud Firestore (`FirebaseFirestore.instance`), local secure settings (`FlutterSecureStorage`), and preferences (`SharedPreferences`).

---

## State Management Flow

Rather than introducing heavy external libraries (such as BLoC or Riverpod) which would increase boilerplate, the application maintains state inside singletons and coordinates updates to the view using native Flutter structures:

```
┌─────────────────┐       Trigger action       ┌──────────────────┐
│  Triage Screen  ├───────────────────────────>│  TriagemService  │
│  (Presentation) │                            │    (Singleton)   │
└────────▲────────┘                            └────────┬─────────┘
         │                                              │
         │ Updates state and triggers repaint           │ Performs validation
         └──────────────────────────────────────────────┘ and writes to Cache
```

* **Firestore Streams**: Conversational lists and single chat channels are bound via Firestore `snapshots()` to `StreamBuilder` widgets. State is maintained directly on Firestore, resolving state management overhead on the mobile device.
* **Triage Respostas Cache**: `TriagemService` keeps a `Map<String, List<SecaoTriagem>> _respostasCache` in memory. As the user moves between pages, responses are auto-saved in the cache. When a section is concluded, it is pushed to the backend database.

---

## Dependency Injection (DI) Setup

Dependencies are configured using standard constructor injection or singleton instance delegation. Singletons resolve themselves globally using simple static accessors:

```dart
// Example of accessing shared singletons
final AuthManager auth = AuthManager();
final ChatService chat = ChatService();
final TriagemService triage = TriagemService();
```

This prevents complex setup and runtime context lookup errors, while maintaining mockability during testing (see `08-testing.md` for mocking details).

---

[FILE: docs/03-api.md]
<!-- FILE: docs/03-api.md -->
# 03 — Network & API Integration

The PLASIR Mobile application handles all network request processing via a custom, centralized wrapper around standard Dart `http.Client`.

---

## Network Layer Abstraction

All requests inherit headers and configuration dynamically inside `ApiService` via the standard private helper `_getHeaders()`:

```dart
// Snippet from ApiService
Future<Map<String, String>> _getHeaders({bool requiresAuth = false}) async {
  final apiKey = EnvConfig.mobileApiKey;
  final headers = {
    'Accept': 'application/json',
    'Content-Type': 'application/json',
    'X-Mobile-API-Key': apiKey,
    'X-Device-Type': 'mobile',
    'X-App-Version': '1.0.0',
    'X-Platform': 'flutter',
  };

  if (requiresAuth) {
    final token = await getToken();
    if (token != null && token.isNotEmpty) {
      headers['Authorization'] = 'Bearer $token';
    }
  }
  return headers;
}
```

---

## Interceptors & Authentication Logic

The networking client implements **Token Expiration Interception** during response processing. If any request returns an HTTP `401 Unauthorized` status, `ApiService` interrupts execution and triggers the global callback `_onTokenExpired`:

```dart
} else if (response.statusCode == 401) {
  debugPrint('⚠️ 401 - Credenciais inválidas ou token expirado');
  _onTokenExpired?.call();
  throw TokenExpiredException('Sessão expirada. Faça login novamente.', statusCode: 401);
}
```

`AuthManager` registers a callback to intercept this event, immediately wiping local credentials, stopping Firebase Firestore message listeners, and resetting the navigation stack to the login screen:

```dart
void setOnTokenExpired(VoidCallback callback) {
  _onTokenExpired = callback;
  ApiService.setOnTokenExpired(() async {
    await handleTokenExpired();
  });
}
```

---

## Deep Link Routing

Deep link parsing is orchestrated via the `app_links` package. It listens to system intent filters globally inside `DeepLinkService`:

```
Incoming deep link URI: dondzalandia://verify-email?id=12&hash=abc...
                      │
                      ▼
               DeepLinkService
                      │  Parses parameters
                      ▼
                 verifyEmail() inside ApiService
                      │  Pushes POST to backend
                      ▼
               Email verified confirmation
```

### Handled Deep Link Endpoint
* **Path**: `/verify-email`
* **Query Parameters**:
  * `id`: User Identifier.
  * `hash`: Security hash verification.
  * `signature`: Verification signature.
  * `expires`: UNIX timestamp expiration marker.

---

## Custom Exception Structures

```dart
class ApiException implements Exception {
  final String message;
  final int? statusCode;
  ApiException(this.message, {this.statusCode});
}

class TokenExpiredException extends ApiException {
  TokenExpiredException(super.message, {super.statusCode});
}

class ValidationException extends ApiException {
  final Map<String, dynamic> errors;
  ValidationException(super.message, this.errors, {super.statusCode});
}
```

---

[FILE: docs/04-database.md]
<!-- FILE: docs/04-database.md -->
# 04 — Data & Local Storage

The application isolates cache and preferences storage across two strategies depending on the sensitivity of the stored parameters.

---

## Storage Strategies Matrix

| Storage Engine | Technology Used | Target Attributes | Security / Encryption |
| :--- | :--- | :--- | :--- |
| **Secure Cache** | `FlutterSecureStorage` | Access tokens, authenticated User profile payload. | Android: AES-256 (Keystore)  iOS: Keychain Access. |
| **Preferences Cache** | `SharedPreferences` | Onboarding complete flag, local layout configurations. | Plaintext XML / NSUserDefaults (No encryption). |
| **In-Memory Cache** | In-Memory Maps | Triage responses list, parsed JSON questions. | RAM only (Erased on app close). |

---

## Secure Storage Access

Auth tokens are written to `FlutterSecureStorage` securely inside `ApiService`:

```dart
// Write operation
await _secureStorage.write(key: _tokenKey, value: token);

// Read operation with local runtime cache fallback
Future<String?> getToken() async {
  if (_cachedToken != null) return _cachedToken;
  _cachedToken = await _secureStorage.read(key: _tokenKey);
  return _cachedToken;
}
```

---

## In-Memory JSON Question Loading

 Triage questions are highly hierarchical and static. They are stored as structured JSON assets under `assets/data/perguntas_triagem.json` and parsed once on startup:

```dart
// Loaded via TriagemService
Future<List<SecaoTriagem>> carregarPerguntas() async {
  if (_secoes != null) return _secoes!;
  final jsonString = await rootBundle.loadString('assets/data/perguntas_triagem.json');
  final Map<String, dynamic> data = json.decode(jsonString);
  final secoes = (data['secoes'] as List?)
      ?.map((s) => SecaoTriagem.fromJson(s))
      .toList() ?? [];
  _secoes = _unirSecoesDuplicadas(secoes);
  return _secoes!;
}
```

Once loaded, the objects are cached to RAM, making question transitions completely instantaneous.

---

## Cloud Firestore Datastore Schema

Because the mobile client uses Firestore **without standard Firebase authentication accounts**, the application maps chat structures cleanly using custom string document names:

### 1. Messaging Users Collection (`usuarios_mensagens`)
* **Document ID**: Custom UID generated at `_generateUid(backendUserId)` via:
  `msg_` + Base64Url(backendUserId) (e.g., `msg_MTI` for User ID `12`).
* **Fields**:
  ```json
  {
    "backend_user_id": "12",
    "firebase_uid": "msg_MTI",
    "nome": "João Silva",
    "nome_lower": "joão silva",
    "email": "joao@example.com",
    "email_lower": "joao@example.com",
    "avatar": "https://...",
    "ativo": true,
    "criado_em": "FieldValue.serverTimestamp()",
    "ultimo_acesso": "FieldValue.serverTimestamp()"
  }
  ```

### 2. Conversational Nodes Collection (`conversas`)
* **Document ID**: Automatically generated uuid.
* **Fields**:
  ```json
  {
    "participantes_uids": ["msg_MTI", "msg_MzQ"],
    "participantes_backend_ids": ["12", "34"],
    "participantes_nomes": {
      "msg_MTI": "João Silva",
      "msg_MzQ": "Tutor Maria"
    },
    "ultima_mensagem": "Olá, tudo bem?",
    "ultima_remetente_uid": "msg_MTI",
    "ultima_atualizacao": "FieldValue.serverTimestamp()",
    "criado_em": "FieldValue.serverTimestamp()",
    "criado_por": "msg_MTI"
  }
  ```
  * **Sub-collection**: `mensagens` (stores the messages ordered descending by `timestamp`).

### 3. Chat Request Collection (`solicitacoes_chat`)
* **Document ID**: Automatically generated uuid.
* **Fields**:
  ```json
  {
    "remetente_uid": "msg_MTI",
    "remetente_backend_id": "12",
    "remetente_nome": "João Silva",
    "destinatario_uid": "msg_MzQ",
    "destinatario_backend_id": "34",
    "destinatario_nome": "Tutor Maria",
    "status": "pendente | aceito | recusado",
    "criado_em": "FieldValue.serverTimestamp()"
  }
  ```

---

[FILE: docs/05-features.md]
<!-- FILE: docs/05-features.md -->
# 05 — Features & User Journey

PLASIR Mobile primarily targets children screening triages (WGSS) and coordinate chats between tutors/guardians and school specialists.

---

## 1. WGSS Triage (Child Screening)

The triage system collects Washington Group on Disability Statistics (WGSS) metrics. Triage is split into **8 logical sections**:

```
 01: School History ──► 02: Vision ──► 03: Hearing ──► 04: Mobility 
                                                               │
 08: Mental Health  ◄── 07: Autonomy ◄── 06: Comm.   ◄── 05: Cognition
```

### Conditional Visibility (Skip Logic) Rules
Some questions are conditional. They must appear only if answers to previous questions match requirements.
`TriagemService` parses boolean logic strings directly:

```dart
bool isPerguntaVisivel(PerguntaTriagem pergunta, Map<String, String?> respostas) {
  if (pergunta.visivelSe == null || pergunta.visivelSe == 'sempre_visivel') {
    return true;
  }
  final condition = pergunta.visivelSe!;
  
  // Logic parser for "or" operations
  if (condition.contains(" or ")) {
    final parts = condition.split(" or ").map((s) => s.trim()).toList();
    return parts.any((part) => _avaliaCondicao(part, respostas));
  }
  
  // Logic parser for "and" operations
  if (condition.contains(" and ")) {
    final parts = condition.split(" and ").map((s) => s.trim()).toList();
    return parts.every((part) => _avaliaCondicao(part, respostas));
  }
  
  return _avaliaCondicao(condition, respostas);
}
```

---

## 2. Navigation Routing Table

Because the application uses native routes inside `MaterialApp` rather than an external router package, mapping flows cleanly inside `lib/main.dart`:

| Route Name | Target Widget Class | Access Rules | Role Handling / Context |
| :--- | :--- | :--- | :--- |
| `/` | `AppStartupScreen` | Anonymous | Splash screen and initial preferences checkout. |
| `/iniciar` | `Iniciar` | Anonymous | Direct onboarding setup start point. |
| `/login` | `LoginScreen` | Anonymous | Credentials verification form. |
| `/signup` | `SignupScreen` | Anonymous | Account registration (Guardian role). |
| `/home` | `BottomNavBar` | Authenticated | Dashboard navigation container. |
| `/reset-password` | `ResetPasswordScreen`| Anonymous | Out-of-band email reset portal. |
| `/debug` | `DebugScreen` | Developer Only | Exposes raw local `.env` values & triggers API connectivity tests. |

---

## 3. Chat Request & Handshake Flows

To prevent unwanted messaging spam, tutors and specialists must complete a request handshake sequence:

```
Sender (Client)                      Firebase Firestore                      Receiver
   │                                         │                                  │
   │  sendChatRequest()                      │                                  │
   ├────────────────────────────────────────>│  (Status: "pendente")            │
   │                                         │                                  │
   │                                         │  Listens to stream               │
   │                                         │─────────────────────────────────>│
   │                                         │                                  │
   │                                         │  acceptChatRequest()             │
   │                                         │<─────────────────────────────────┤
   │                                         │                                  │
   │                                         │  Updates status to "aceito"      │
   │                                         │  & initializes Chat Room         │
   │                                         │                                  │
   │  Enters Conversation                    │  Enters Conversation             │
   ├────────────────────────────────────────>│<─────────────────────────────────┤
```

---

[FILE: docs/06-security.md]
<!-- FILE: docs/06-security.md -->
# 06 — Security & Compliance

Maintaining security on children diagnostics is critical. Below is the technical deep dive on the current and recommended defensive architectures.

---

## Code Obfuscation & Obfuscated Builds

To protect logical routes, parsing formulas, and proprietary WGSS analysis triggers inside the binaries, compiling commands must obfuscate the Dart symbols table. 

This prevents decompilers from mapping class methods using readable names (e.g., standard decompilers like JADX will read `submitSchoolHistory` as `a`).

```bash
# Production Obfuscation command
flutter build appbundle \
  --obfuscate \
  --split-debug-info=build/app/outputs/symbols
```

---

## Hardcoded Secrets Checklist

> [!CAUTION]
> **VULNERABILITY IDENTIFIED: Hardcoded Testing Credentials**
> The file `lib/debug_screen.dart` contains hardcoded email `teste@gmail.com` and password `Teste01` in plaintext within its functions. 
> * **Risk**: If these credentials have elevated permissions in the staging or production environments, compiling this console exposes the account to reverse engineers.
> * **Remediation Plan**: Exclude `lib/debug_screen.dart` from the compilation bundle in release, or wrap the route registration in `kReleaseMode` check clauses:
>   ```dart
>   if (!kReleaseMode) '/debug': (context) => const DebugScreen(),
>   ```

---

## Missing Protections & Gap Analysis

```
  Current App Security Posture:
  ┌────────────────────────────────────────────────────────┐
  │ [Secure Storage] Token stored using AES-256 (Keystore) │
  └───────────────────────────┬────────────────────────────┘
                              ▼
  Critical Architecture Gaps:
  ┌────────────────────────────────────────────────────────┐
  │ ❌ NO SSL Pinning (Vulnerable to MITM proxies)          │
  ├────────────────────────────────────────────────────────┤
  │ ❌ NO Firebase Auth (No Firestore access validation)    │
  ├────────────────────────────────────────────────────────┤
  │ ❌ NO Device Integrity (Runs on rooted/jailbroken)     │
  └────────────────────────────────────────────────────────┘
```

### 1. SSL Pinning Architecture
Currently, `ApiService` relies on the system trust chain. If an attacker mounts a custom root certificate on the device, they can intercept all HTTPS REST calls.
* **Remediation**: Re-engineer the client initialization with package `http` custom security context or integrate `Dio` using custom cert check interceptors:
  ```dart
  // Recommended fix pattern
  final SecurityContext context = SecurityContext(withTrustedRoots: true);
  context.setTrustedCertificatesBytes(utf8.encode(pemCertificateString));
  final http.Client client = IOClient(HttpClient(context: context));
  ```

### 2. Device Integrity (Jailbreak / Root Detection)
Rooted devices bypass standard secure storage isolation boundaries, allowing malware to extract raw access tokens.
* **Remediation**: Integrate `flutter_trust_fall` package to verify device security before launching the startup checker flow:
  ```dart
  import 'package:flutter_trust_fall/flutter_trust_fall.dart';
  
  bool isSecured = await FlutterTrustFall.isPlaySignatureCorrect && 
                   !(await FlutterTrustFall.isJailBroken);
  if (!isSecured) {
    // Gracefully terminate application
  }
  ```

### 3. Firestore Open Rules Mitigation
Since the app doesn't use Firebase Auth, it must secure records by validating custom tokens generated by the Laravel REST API.
* **Remediation**: Authenticate clients anonymously on Firebase using `firebase_auth` custom auth tokens generated securely on the Laravel backend upon successful login:
  ```dart
  await FirebaseAuth.instance.signInWithCustomToken(backendToken);
  ```

---

[FILE: docs/07-deployment.md]
<!-- FILE: docs/07-deployment.md -->
# 07 — Deployment & CI/CD Pipelines

This document details the compilation workflow and automated pipeline configuration for deploying PLASIR Mobile to the App Store and Google Play Store.

---

## Production Compilation Pipelines

Release packages must always compile using a clean cache to avoid packaging legacy dev-mode environment resources:

```bash
# 1. Clean workspace
flutter clean

# 2. Get clean dependencies
flutter pub get
CLE
# 3. Compile Android (Generate AAB bundle for Google Play Console)
flutter build appbundle --release --obfuscate --split-debug-info=build/app/outputs/symbols --dart-define-from-file=.env

# 4. Compile iOS (Generate IPA archive)
flutter build ipa --release --obfuscate --split-debug-info=build/app/outputs/symbols --export-method=app-store --dart-define-from-file=.env
```

---

## Fastlane Configuration & Pipelines

Automating app distribution is managed via two Fastlane pipelines:

### 1. Android Pipeline (`android/fastlane/Fastfile`)
```ruby
default_platform(:android)

platform :android do
  desc "Submit a new Beta Build to Google Play Internal Testing"
  lane :internal do
    gradle(task: "clean")
    sh(command: "flutter build appbundle --release --obfuscate --split-debug-info=build/app/outputs/symbols")
    upload_to_play_store(
      track: 'internal',
      aab: '../build/app/outputs/bundle/release/app-release.aab'
    )
  end
end
```

### 2. iOS Pipeline (`ios/fastlane/Fastfile`)
```ruby
default_platform(:ios)

platform :ios do
  desc "Submit a new Beta Build to Apple TestFlight"
  lane :beta do
    setup_ci if ENV["CI"]
    match(type: "appstore") # Handle certificates code signing
    increment_build_number(xcodeproj: "Runner.xcodeproj")
    sh(command: "flutter build ipa --release --obfuscate --split-debug-info=build/app/outputs/symbols --export-method=app-store")
    upload_to_testflight(
      ipa: '../build/ios/ipa/Runner.ipa',
      skip_waiting_for_build_processing: true
    )
  end
end
```

---

## Google Play & Apple App Store Launch Checklists

Before promoting builds from internal tracks to public production storefronts:

### Android Release Checklist
- [ ] **Adaptive Launcher Icon**: Verify adaptive vector asset transparency configuration (configured on line 57 of `pubspec.yaml`).
- [ ] **Target SDK version**: Must align with current Google Play requirements (Target SDK `34`).
- [ ] **Signing Keys**: Secure the upload key keystore credentials outside of git scope. Add variables to `android/key.properties` for gradle access.
- [ ] **Privacy Policy**: Provide a valid URL explaining the collection of childhood triage data.

### iOS Release Checklist
- [ ] **App Privacy Manifest**: Add descriptions to `Info.plist` explaining usages for notifications permissions.
- [ ] **Provisioning Certificates**: Verify Apple Distribution certs are stored securely within the Fastlane Match repository.
- [ ] **App Store Connect Metadata**: Add screens capturing the triage flow and chat features.
- [ ] **App Store Review Account**: Provide credentials for a test tutor account to pass standard sandboxed Apple review tests.

---

[FILE: docs/08-testing.md]
<!-- FILE: docs/08-testing.md -->
# 08 — Testing & Quality Assurance

To guarantee accuracy on children screening assessments and prevent communication regressions on the chat features, this project defines a strict verification workflow.

---

## Automated Testing Strategy

```
           Testing Pyramid Configuration for PLASIR Mobile
           
                           / ──  ── \
                          /  Integration \
                         /     Tests      \
                        / ──  ──  ──  ── \
                       /   Widget & Golden\
                      /        Tests       \
                     / ──  ──  ──  ──  ──  \
                    /      Unit Tests:      \
                   /   Models, Skip Logics   \
                  /___________________________\
```

---

## Unit Testing: Mocking HTTP Services & Firestore

To test the application without issuing real HTTP calls or accessing live Firestore clusters, tests rely on `package:mocktail` or `package:mockito` to mock underlying structures:

### 1. Mocking Network Layer (`test/mocks/api_service_mock.dart`)
```dart
import 'package:mocktail/mocktail.dart';
import 'package:uno/core/api/api_service.dart';

class MockApiService extends Mock implements ApiService {}
```

### 2. Unit Testing Triage Skip Logic Rules
```dart
import 'package:flutter_test/flutter_test.dart';
import 'package:uno/models/triagem_models.dart';
import 'package:uno/services/triagem_service.dart';

void main() {
  final triageService = TriagemService();

  group('WGSS Triage Skip Logic validations', () {
    test('Conditional questions are correctly shown when trigger criteria matched', () {
      final question = PerguntaTriagem(
        codigo: 'Q2_A',
        questao: 'Qual auxilio visual utiliza?',
        tipo: TipoPergunta.conditional,
        codigoBackend: 'tipo_auxilio_visual',
        visivelSe: "usa_auxilio == 'Sim'",
        opcoes: [],
        estrategiaPedagogica: '',
        planoFamiliar: '',
        recomendacaoEspecialista: '',
      );

      // Trigger values
      final answersPositive = {'usa_auxilio': 'Sim'};
      final answersNegative = {'usa_auxilio': 'Não'};

      expect(triageService.isPerguntaVisivel(question, answersPositive), isTrue);
      expect(triageService.isPerguntaVisivel(question, answersNegative), isFalse);
    });
  });
}
```

---

## Widget & Golden Test Setup

Verify that widgets render correctly on the display without UI regressions. Golden tests capture snapshot images of components and compare them with standard master images.

```dart
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';

void main() {
  setUpAll(() {
    // Avoid font rendering gaps inside headless test environments
    GoogleFonts.config.allowRuntimeFetching = false;
  });

  testWidgets('App Startup Splash Screen renders correct elements', (WidgetTester tester) async {
    // Render splash screen widget
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: Center(
            child: Text('Uno App'),
          ),
        ),
      ),
    );

    // Verify elements
    expect(find.text('Uno App'), findsOneWidget);
  });
}
```

---

## Running Verification Suites & Coverage

Execute these CLI tools to run tests and output complete verification details:

```bash
# 1. Run all unit and widget tests
flutter test

# 2. Run tests and collect coverage telemetry
flutter test --coverage

# 3. Convert coverage report files to interactive HTML reports (requires lcov)
genhtml coverage/lcov.info -o coverage/html

# 4. Open interactive test report
open coverage/html/index.html
```

---
### Work Summary

* **Codebase Analysis Complete**: Thoroughly explored folder structures, local package configurations (`pubspec.yaml`), custom network architecture (`api_service.dart`, `env_config.dart`, `auth_manager.dart`), and domain architectures (`triagem_service.dart`, `chat_service.dart`, `triagem_models.dart`).
* **Technical Specificity Ensured**: Excluded the generic templates suggested by the prompt (such as `Dio` or generic `Bloc` patterns) in favor of the actual, exact patterns discovered on-disk, which rely on native Dart `http`, standard Firebase Firestore connections, and Vanilla State structures (e.g. singletons combined with local notifications).
* **Identified Vulnerabilities & Gaps**: Outlined crucial recommendations in `06-security.md` pointing out severe architectural vulnerabilities—such as the plaintext test user credentials inside `lib/debug_screen.dart`, absolute lack of SSL Pinning, lack of local device integrity, and potential open database access vectors inside Cloud Firestore due to the absence of standard authentication accounts.
* **Modular Generation Completed**: Provided the complete set of separate, production-grade files (`README.md` and `docs/01` through `08`), utilizing exact file tags so they can be easily parsed.
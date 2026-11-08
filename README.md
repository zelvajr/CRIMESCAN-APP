# CrimeScan Mobile

CrimeScan Mobile is the Flutter-based mobile companion for the wider CrimeScan ecosystem. This repository is a selective public engineering showcase of the current development-stage prototype rather than a production forensic application or app-store release.

## Scope and release intent

This codebase is intended to show:

- the mobile application architecture and implementation status,
- the forensic evidence collection workflow under development,
- the local SQLite and media handling model,
- the LiveKit preview publishing path,
- the desktop/mobile synchronization concepts in progress.

This repository is not a validated production deployment, a chain-of-custody system, or a finished mobile forensic product. It should be treated as a prototype and engineering reference for the wider CrimeScan ecosystem.

## Problem statement

The mobile application is designed to support forensic scene workflows such as:

- case creation and scene metadata capture,
- photo and video evidence capture,
- voice-note attachment,
- location tagging,
- SQLite-backed evidence persistence,
- local sync queue management,
- reporting and review workflows.

The project remains under active development. Some flows are partially implemented, some are conceptually defined, and some are dependent on external services or backend support that is not included in this public repository snapshot.

## System architecture

### Application structure

- Flutter app shell with route-based screens.
- Provider-based state management for case, evidence and sync workflows.
- SQLite database persistence for cases, evidence, audit entries and sync queue state.
- Local media file handling with perimeter checks to keep evidence on app-managed storage paths where possible.
- Live preview publishing using the LiveKit client library.
- QR/endpoint style desktop synchronization flow using HTTP-based operations.
- PDF generation and report composition for review/reporting screens.

### Core components

- `lib/main.dart` initializes the database and provider graph.
- `lib/app.dart` defines the app routes and default dark theme.
- `lib/providers/` manages case, evidence and sync state.
- `lib/core/services/` contains persistence, GPS, hashing, sync and LiveKit publishing services.
- `lib/screens/` contains the UI screens for case setup, capture, gallery, review and reporting.
- `lib/models/` contains the case and evidence record models.

## Feature inventory

| Classification | Features |
| --- | --- |
| IMPLEMENTED | Case creation and storage; SQLite-backed evidence records; provider-driven state updates; photo/video capture flow scaffolding; GPS capture support; voice-note screen and attachment flow; local sync queue state; PDF/report generation scaffold; LiveKit preview publisher configuration; route-based app navigation. |
| PARTIALLY IMPLEMENTED | Evidence hashing and integrity tracking; sync status/retry logic; review confirmation flow; app-managed media storage; report validation messaging; backend connectivity assumptions and token handling; database lifecycle and migration handling. |
| PROTOTYPE / EXTERNALLY DEPENDENT | LiveKit room connectivity and real-time publish path; laptop/desktop synchronization with backend or external service dependencies; AI/analysis workflows and any backend-intensive processing; production-grade app signing, entitlement, and deployment configuration. |

This classification is intentionally conservative. A screen or UI exists does not mean the underlying workflow is production-complete or validated.

## Security and publication notes

This release copy intentionally excludes generated artifacts, local build output, runtime caches and synthetic evidence data.

The project was audited for embedded secrets and sensitive configuration. The hardcoded LiveKit fallback shared key was removed from the public code path and replaced with build-time configuration that must be supplied externally by a secure secret store. The source does not include production credentials, tokens or private endpoints.

Relevant release-sensitive items still requiring operational review before any non-demo deployment:

- Android manifest still declares `usesCleartextTraffic` and should be reviewed for any production network policy.
- Application identifiers and signing configuration remain example/default-style placeholders and are not app-store ready.
- The project uses external server dependencies in some paths; those endpoints and tokens must be provisioned securely outside the repository.
- Local SQLite records are not a tamper-proof evidence trail and should not be treated as a legal or forensic chain-of-custody system.

## Third-party dependencies and licensing

This project uses a number of Flutter and Dart packages including LiveKit, SQLite, camera/media, GPS, PDF generation, speech/voice, and HTTP sync dependencies. Before any broader corporate or production use, review the license obligations for each dependency and confirm the package set aligns with the intended distribution model.

Key packages to review for licensing and operational fit include:

- `livekit_client`
- `pdf`
- `printing`
- `record`
- `speech_to_text`
- `camera`
- `permission_handler`
- `network_info_plus`
- `connectivity_plus`
- `shared_preferences`

This public repository is a source showcase only and should not be treated as legal or licensing compliance documentation.

## Build and validation

The project is structured as a Flutter application. Typical local validation steps are:

```bash
flutter pub get
flutter analyze
flutter test
```

This release copy is intended for public source review and engineering evaluation. It is not a production build artifact or signed release package.

## Repository layout

```text
.
├── android/
├── assets/
├── ios/
├── lib/
├── linux/
├── macos/
├── test/
├── web/
├── windows/
├── analysis_options.yaml
├── pubspec.yaml
├── pubspec.lock
├── README.md
└── .gitignore
```

## Known limitations

- This is a development-stage prototype.
- It is not an App Store, enterprise, or production deployment.
- Some flows are incomplete and may require backend support or product-specific decisions.
- Generated build output, caches and local evidence directories are intentionally excluded from this public copy.
- No forensic admissibility, chain-of-custody, or production readiness claim is implied.

## Project identity

The wider ecosystem is named CrimeScan. This mobile component is released as a separate repository and engineering showcase, not as the full forensic product or a commercial app distribution.

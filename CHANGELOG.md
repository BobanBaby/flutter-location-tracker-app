# Changelog

All notable changes to this project will be documented in this file.

## [2.1.0+7] - 2026-07-27

### Added
- **12-Step Weighted Confidence Scoring Engine**: Added `confidenceScore` (0–100) and `accuracyTier` (`Excellent`, `Good`, `Acceptable`, `Low Confidence`) in `GpsLog`.
- **Low-Confidence Accuracy Tier Toggle**: Added `ignoreLowConfidence` option in `JourneyAnalysisEngine` and `[X] Ignore Low Confidence Fixes (>50m)` toggle switch on the Web Portal.
- **Rule 1 — GPS Warm-Up Stabilization**: Cold-start satellite lock fixes (Accuracy $> 50\text{m}$ followed by $< 20\text{m}$ within $30\text{s}$) are automatically discarded.
- **Stop & Visit Detection Engine**: Automatically identifies and categorizes `Client Visit / Office Stop` ($> 5\text{min}$) and `Lunch Break / Prolonged Visit` ($> 30\text{min}$).
- **Web Analytics Portal Upgrades**: Collection Group Firestore query (`collectionGroup("gps_logs")`), Leaflet route visualizer, cascading rep/journey filters, composite key deduplication, and CSV export.

### Changed
- **Pure 2-Tier Hierarchical Firestore Architecture**: Completely removed legacy flat `/sales_gps_logs` collection writes and queries. All telemetry now routes exclusively through `/users/{userId}/journeys/{journeyId}/gps_logs/{docId}`.
- **Multi-Pass Pipeline Architecture**: Refactored `JourneyAnalysisEngine` into a 4-Pass Pipeline for pre-filtering, stationary radius clustering, gated Google Routes API execution, and journey reconstruction.

### Fixed
- Fixed duplicate row rendering in web dashboard raw logs table via `deduplicateLogs()` composite key matching.
- Fixed uncaught JavaScript `TypeError` in web portal filter selection handler.

---

## [2.0.0+6] - 2026-07-25

### Added
- 2-Tier Hierarchical Firestore Structure (`/users/{userId}/journeys/{journeyId}/gps_logs`).
- Web Analytics Portal (`web_dashboard/index.html`) with Leaflet.js maps.
- Strict profile validation gate requiring verified Sales Rep profile setup before tracking.
- Zero-warning static analysis and updated unit test suite.

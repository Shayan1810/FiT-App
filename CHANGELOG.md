# Changelog

All notable changes to FiT are documented here. The format follows
[Keep a Changelog](https://keepachangelog.com/en/1.1.0/) and the project uses
[Semantic Versioning](https://semver.org/).

## [1.0.0] - 2026-10-02

First public release.

### Added
- **Nutrition**: plain-language meal logging, "My foods" and recipes recognised offline, optional Gemini AI with caching, exponential backoff and an offline queue, plus water tracking.
- **Training**: gym logging with a 55+ exercise library, **custom exercises** and automatic duration estimates. Session-RPE training load, weekly sets per muscle and muscle recovery status.
- **Steps & sleep**: import from Samsung Health (Health Connect) or Apple Health (HealthKit), with manual entry and **editing of any day or night**. Manual edits are never overwritten by a sync.
- **Progress**: 30+ metrics over 30 days to 1 year. Includes protein per kg, energy balance, training load, ACWR, monotony, volume, readiness, recovery speed and sleep regularity. Per-exercise curves for est. 1RM, top weight, volume, best reps and relative strength, plus a weekly sets-per-muscle heat-map.
- **Nebula coach**: readiness score, a recovery-speed factor (sleep, energy intake, protein, age and recent damage) and a plan for tomorrow.
- **Dark mode**: black + lime theme matching the logo. Choose System, Light or Dark in Settings.
- New logo, app icon and splash screen.
- iOS build (unsigned IPA for sideloading).

### Changed
- The acute:chronic workload ratio uses EWMA. Risk is only reported after a 21-day baseline and above a minimum absolute load, so a single light session can't show as an injury risk.
- Food search covers only your own foods and recipes; the built-in food database was removed.

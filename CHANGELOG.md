# Changelog

All notable changes to FiT are documented here. The format follows
[Keep a Changelog](https://keepachangelog.com/en/1.1.0/) and the project uses
[Semantic Versioning](https://semver.org/).

## [2.1.0] - 2026-10-07

- Updated Transformation Section.

## [2.0.0] - 2026-10-06

### Added
- **Transformation mode**, alongside the existing General mode:
  - goals for **Body** (fat loss, weight gain or recomposition, with start date, end date, start weight, body fat and goal weight) and/or **Skin**;
  - daily targets for calories, macros, fibre, water, steps, cardio minutes and sleep (hours, lights out, wake-up), with an optional weekly calorie step;
  - a weekly plan entered once: meals with macros (or calculated from the foods), workouts with sets × reps × kg per weekday, rest days, cardio sessions, supplements and medicine, habits, and morning, afternoon and evening skincare;
  - a daily checklist grouped by time of day. Ticking a meal, workout, cardio session or night of sleep logs the real record; unticking removes it. Use "Tick all" per group, or log anything off-plan as usual;
  - opens on the plan while active, until you switch to General mode in Settings or the plan ends;
  - fat lost and mass gained estimated from cumulative energy balance, plus estimated vs planned vs scale weight, estimated body fat, projected end weight, adherence and streaks;
  - a **Plan** range and category on the Progress tab, covering only the transformation period;
  - Nebula follows the plan: targets, tomorrow's planned workout adjusted for readiness, planned bedtime, and new insights (missed items, open items, behind plan, streaks, skincare);
  - plan import and export as text.
- Morning weigh-in card.
- Metabolism adjustment (±%) in Profile, for medication or conditions that change resting metabolism.

### Changed
- A logged walk is no longer counted on top of a day's step count (no double counting).
- The demo data uses a generic person.

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

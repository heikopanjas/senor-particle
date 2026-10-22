# Recent Updates & Decisions

This file is the append-only log of project decisions and notable changes, maintained by coding agents following the `recent-updates` skill. Everything below the marker line is user-owned history: slopctl never overwrites it during init or merge.

<!-- {changelog} -->

### 2026-10-22 (v1.2.0, señor particle branding 10:30)

- added cfbundledisplayname set to señor particle and a bundle displayname accessor used by the about tab, menu items, and general settings text
- updated the bluetooth usage description to the branded name
- rationale: the about tab and menu showed the ascii product name; one display name keeps app and system surfaces consistent
- kept the ascii senor particle for product name, bundle file name, scripts, and ci so build paths and existing installations are unaffected
- version: stays 1.2.0 because that release is unpublished; this joins it rather than taking a patch number of its own

### 2026-10-22 (v1.2.0, about menu item placement 10:15)

- moved the about menu item below settings and renamed it to about senor particle
- rationale: follows the macOS convention of naming the app in the about item, keeps settings as the first entry in the app section

### 2026-10-22 (v1.2.0, about menu item)

- added an about menu item above settings that opens the shared settings window on the about tab
- centered the two update checkboxes as one group so they line up with the icon, name, and update button
- rationale: reuse the existing about tab instead of adding a second window, and keep the checkboxes left-aligned with each other as macOS expects
- version bump: 1.1.1 to 1.2.0 (MINOR - new user-facing menu entry)

### 2025-10-05 (v0.1.0, initial setup)

- initial AGENTS.md setup
- established core coding standards and conventions
- defined repository structure and governance principles

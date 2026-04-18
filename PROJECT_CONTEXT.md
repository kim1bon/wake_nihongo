# Project Context

## Project Name
WakeNihongo

## Project Summary
This is a Flutter mobile app for Android and iOS.
It is an alarm app where the user must solve Japanese quiz questions in order to stop the alarm.

## Core Features
1. Alarm creation, editing, enabling, disabling
2. Alarm ringing screen
3. Japanese quiz mission to dismiss alarm
4. Quiz data sync from Google Spreadsheet
5. Local cached quiz database for offline use

## MVP Scope
- Alarm list screen
- Alarm create/edit screen
- Alarm ringing full-screen UI
- Multiple-choice Japanese vocabulary quiz
- Quiz data version check from Google Spreadsheet
- Local cache usage if quiz version is unchanged

## Non-MVP Features
- Login
- Cloud sync
- Social features
- Advanced statistics
- In-app purchase
- Multiple quiz types beyond vocabulary

## Target Platforms
- Android
- iOS

## Important Constraints
- Alarm quiz must work offline
- Quiz data should always be served from local storage during alarm session
- Google Spreadsheet is used as the source of quiz content in MVP
- App must be maintainable and modular

## Alarm & Session Rules
- **Snooze:** Interval **5 minutes**. Maximum **10 snoozes per alarm ring event** (from one trigger until the user dismisses or hits the cap; reset the count on the next scheduled ring).
- **Alarm OFF:** Toggling an alarm **off** means **full deactivation** for that alarm—cancel all scheduled triggers for it; no “today only” or partial pause unless explicitly added later.
- **iOS quiz UX:** The user must **open the app** to access the quiz and dismiss the alarm. Notifications are for alerting only; do not require or assume lock-screen or inline quiz completion on iOS.

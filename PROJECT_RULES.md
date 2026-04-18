# Project Rules

## General Principles
- Follow clean, modular, and maintainable Flutter architecture.
- Do not generate overly complex abstractions unless necessary.
- Keep implementations simple and production-friendly.
- Prefer readability over cleverness.
- Do not change unrelated files.
- Do not introduce new packages unless clearly justified.
- Before adding a package, explain why it is needed.

## Work Style Rules
- Before coding, briefly summarize the requested change.
- If the task touches architecture, explain the proposed file changes first.
- Prefer incremental implementation over large rewrites.
- When creating new files, keep names consistent with existing naming conventions.
- If a task has multiple steps, implement the minimum working version first.
- If something is uncertain, choose the simplest maintainable solution.

## Scope Control
- Only implement what is explicitly requested.
- Do not add speculative features.
- Do not create unnecessary placeholder code.
- Do not create mock APIs unless asked.

## Flutter Architecture
- Use feature-based folder structure.
- Separate UI, state, model, repository, and service layers.
- Keep widgets small and reusable.
- Avoid putting business logic directly inside UI widgets.
- Keep platform-specific code isolated.

## Folder Structure (`lib/`)
Follow this layout unless a task explicitly requires a different arrangement.

```
lib/
 ┣ app/
 ┃ ┣ router/
 ┃ ┣ theme/
 ┃ ┗ config/
 ┣ core/
 ┃ ┣ constants/
 ┃ ┣ utils/
 ┃ ┣ extensions/
 ┃ ┗ errors/
 ┣ features/
 ┃ ┣ alarm/
 ┃ ┃ ┣ data/
 ┃ ┃ ┣ domain/
 ┃ ┃ ┗ presentation/
 ┃ ┣ quiz/
 ┃ ┃ ┣ data/
 ┃ ┃ ┣ domain/
 ┃ ┃ ┗ presentation/
 ┃ ┣ sync/
 ┃ ┃ ┣ data/
 ┃ ┃ ┣ domain/
 ┃ ┃ ┗ presentation/
 ┃ ┗ settings/
 ┣ shared/
 ┃ ┣ widgets/
 ┃ ┗ services/
 ┗ main.dart
```

### Placement rules
- **`app/`** — App shell: routing, theming, environment/config wiring. No feature-specific business logic.
- **`core/`** — Cross-feature helpers only (constants, pure utils, extensions, shared error types). Do not import `features/*` from here.
- **`features/<name>/`** — Vertical slices. For features like `alarm`, `quiz`, and `sync`, use **`data/`** (DTOs, local/remote sources, repository implementations), **`domain/`** (entities, repository interfaces, use cases), and **`presentation/`** (screens, widgets, Riverpod providers for that feature). Apply the same three layers when other features (e.g. `settings`) grow beyond a few files.
- **`shared/`** — Reusable UI building blocks and cross-cutting services used by multiple features (e.g. shared dialogs). Prefer feature folders when code is used by one feature only.
- **`main.dart`** — Entrypoint; keep bootstrap minimal (runApp, provider scope, app widget).

## State Management
- Use Riverpod as the primary state management solution.
- Do not mix Riverpod with other state management approaches unless explicitly requested.
- Keep providers focused and small.

## Data Rules
- Quiz data must be loaded from local storage during actual alarm sessions.
- Remote spreadsheet data is only for synchronization, never for direct alarm-time querying.
- Validate spreadsheet data before saving locally.
- Never overwrite local quiz data until new data has been fully downloaded and validated.
- Store quiz version separately from quiz content.

## Alarm Rules
- Alarm-related logic must be reliable and defensive.
- Do not assume Android and iOS alarm behavior are identical.
- Clearly separate scheduling logic from alarm session UI logic.
- Any platform-specific limitation must be documented in comments.
- **Snooze:** Fixed interval of **5 minutes** and a maximum of **10 snoozes per ringing session** (track count per session; enforce in domain/scheduling, not only in UI).
- **Alarm OFF:** Means **full deactivation**—persist disabled state and **cancel all OS schedules/notifications** for that alarm until turned on again.
- **iOS:** Quiz and alarm dismissal run **only inside the app** (foreground). Design flows as notification tap → app opens → alarm/quiz session; do not rely on lock-screen quiz on iOS.

## UI Rules
- Build simple, clean, mobile-first interfaces.
- Prioritize clarity and large touch targets.
- Alarm ringing screen must be minimal and distraction-free.
- Avoid overly decorative UI.
- Keep visual consistency across screens.
- On **iOS**, assume the user reaches the quiz/alarm-dismiss flow **after launching or returning to the app**; align copy and navigation with that path.

## Code Style
- Write null-safe Dart code.
- Prefer explicit naming over abbreviations.
- Add comments only where logic is non-obvious.
- Avoid long files when possible.
- Prefer small focused methods.

## File Editing Rules
- When modifying a file, preserve existing structure unless improvement is necessary.
- Do not rewrite the entire file if only a small change is needed.
- Explain major refactors before applying them.

## Testing and Validation
- For logic-heavy code, provide simple testable units.
- When implementing parsing or sync logic, handle invalid or missing fields safely.
- Always account for offline fallback paths.

## What to Avoid
- Do not hardcode temporary values without marking them clearly.
- Do not mix UI text and business constants throughout the codebase.
- Do not put spreadsheet parsing logic inside widgets.
- Do not place sync logic inside UI screens.

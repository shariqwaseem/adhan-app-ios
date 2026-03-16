# Plan: Downloadable Adhan Sounds via Firebase Storage

## Overview
Add the ability to download adhan audio files from Firebase Storage after app install. The app currently bundles 17 CAF files (~app size impact). This feature will allow shipping fewer bundled sounds and offering an expanded catalog via download.

## Architecture

```
Firebase Storage (CAF files)
        ↓
  DownloadManager (URLSession background download)
        ↓
  Library/Sounds/ (local storage)
        ↓
  AlarmKit .named("filename")
```

---

## Step 1: Add Firebase SDK Dependency

**Files:** `project.yml`

- Add `FirebaseStorage` SPM dependency (https://github.com/firebase/firebase-ios-sdk)
- Only pull in `FirebaseStorage` — no Auth, Firestore, etc. needed for public reads
- Add `GoogleService-Info.plist` to the project (user must create a Firebase project and download this)

---

## Step 2: Extend the AdhanAudio Model

**Files:** `AdhanApp/Models/AdhanAudio.swift`

- Add `source` property to `AdhanAudioFile`: `.bundled` or `.remote(firebasePath: String)`
- Add `isDownloaded` computed property — checks if file exists in `Library/Sounds/`
- Add `localURL` computed property — returns bundle URL for bundled, `Library/Sounds/` URL for remote
- Split `AdhanAudioCatalog.allFiles` into `bundledFiles` and `remoteFiles`
- Add a `remoteCatalog` that defines the downloadable sounds (ID, display name, Firebase path)
- `bundleRelativePath(forID:)` should resolve to `Library/Sounds/` path for downloaded files

---

## Step 3: Create AdhanAudioDownloadManager

**New file:** `AdhanApp/Services/AdhanAudioDownloadManager.swift`

- `@Observable` class, singleton via `shared`
- Properties:
  - `downloadProgress: [String: Double]` — per-file progress (0.0–1.0)
  - `downloadState: [String: DownloadState]` — `.notDownloaded`, `.downloading`, `.downloaded`, `.failed`
- Methods:
  - `download(_ file: AdhanAudioFile) async throws` — downloads from Firebase Storage to `Library/Sounds/`
  - `cancelDownload(_ file: AdhanAudioFile)`
  - `deleteDownload(_ file: AdhanAudioFile) throws` — removes local file
  - `isDownloaded(_ fileID: String) -> Bool` — checks disk
  - `ensureSoundsDirectory()` — creates `Library/Sounds/` if needed
  - `verifyAllSelectedSounds(preferences: UserPreferences) async` — on app launch, checks all selected sounds exist, re-downloads missing ones
- Implementation details:
  - Use `StorageReference.write(toFile:)` for direct file download
  - Save to: `FileManager.default.urls(for: .libraryDirectory, in: .userDomainMask)[0]/Sounds/{filename}.caf`
  - Track progress via Firebase Storage's progress handler

---

## Step 4: Update AdhanAudioSelectionView

**Files:** `AdhanApp/Views/Prayer/AdhanAudioSelectionView.swift`

- Add three sections: "Default", "Bundled Sounds", "Downloadable Sounds"
- For each downloadable sound, show:
  - Download button (cloud icon) if not downloaded
  - Progress indicator if downloading
  - Checkmark if downloaded and selected
  - Disable selection (tap) until download completes
- On tap of a not-yet-downloaded sound:
  - Start download → show progress → on completion, select it and save preference
- Add swipe-to-delete for downloaded sounds (to free storage)
- Add "Download All" option at top of downloadable section

---

## Step 5: Update Alarm Scheduling Path

**Files:** `AdhanApp/ViewModels/AlarmManager.swift`, `AdhanApp/ViewModels/NotificationScheduler.swift`

- In `NotificationScheduler`, before scheduling an alarm with a downloaded sound:
  - Verify the file exists at `Library/Sounds/` path
  - If missing: attempt re-download, or fall back to default sound
- Update `AdhanAudioCatalog.bundleRelativePath(forID:)` to return the correct path based on source:
  - Bundled: `"AdhanAudio/filename.caf"` (current behavior)
  - Downloaded: just `"filename.caf"` (AlarmKit resolves from `Library/Sounds/`)
- Add a `soundFileExists(forID:) -> Bool` helper

---

## Step 6: App Launch Verification

**Files:** `AdhanApp/App/AdhanApp.swift` (or wherever app init happens)

- On launch, call `AdhanAudioDownloadManager.shared.verifyAllSelectedSounds()`
- For any missing downloaded sounds: re-download in background, or reset preference to default bundled sound
- Configure Firebase on launch: `FirebaseApp.configure()`

---

## Step 7: Firebase Storage Structure

```
gs://your-bucket/
  adhan-audio/
    v1/
      Al-Arake.caf
      Al-Aassaf-Iraq.caf
      ... (expanded catalog)
      catalog.json        ← optional: remote catalog for dynamic updates
```

- Optional: `catalog.json` lists available files with metadata (name, display name, size, duration)
- This allows adding new sounds without an app update
- Firebase Storage rules: allow public read, no write from client

---

## File Changes Summary

| File | Change |
|------|--------|
| `project.yml` | Add FirebaseStorage SPM dependency |
| `AdhanApp/Models/AdhanAudio.swift` | Add source enum, isDownloaded, localURL, remote catalog |
| **NEW** `AdhanApp/Services/AdhanAudioDownloadManager.swift` | Download manager with progress tracking |
| `AdhanApp/Views/Prayer/AdhanAudioSelectionView.swift` | Download UI, progress indicators, sections |
| `AdhanApp/ViewModels/AlarmManager.swift` | Support Library/Sounds path resolution |
| `AdhanApp/ViewModels/NotificationScheduler.swift` | Pre-schedule file verification |
| `AdhanApp/App/AdhanApp.swift` | Firebase init, launch verification |
| **NEW** `GoogleService-Info.plist` | Firebase config (user-provided) |

---

## Key Design Decisions

1. **No sound selection without download** — the confirm/select action is gated on file existence
2. **Bundled sounds stay bundled** — existing 17 sounds remain in the app bundle for offline reliability
3. **Graceful fallback** — if a downloaded sound goes missing, fall back to "Adhan-Makkah-New" (bundled default)
4. **Minimal Firebase footprint** — only `FirebaseStorage`, no Auth needed (public read rules)
5. **No streaming** — AlarmKit requires local files, so full download before use

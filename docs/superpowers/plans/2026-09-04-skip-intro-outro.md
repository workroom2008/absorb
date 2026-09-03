# Skip Intro/Outro Feature Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Add per-book intro/outro skip times for audiobooks, automatically skipping the intro at chapter starts and outro before chapter ends.

**Architecture:** 
- Per-book settings stored in SharedPreferences via ScopedPrefs
- Skip logic integrated into the existing position stream listener in AudioPlayerService
- UI via a new "Skip Intro/Outro" card button that opens a bottom sheet to configure per-book times

**Tech Stack:** Flutter/Dart, SharedPreferences, ScopedPrefs, just_audio

**Spec:** User requirements for skip intro/outro feature

## Global Constraints
- Use ScopedPrefs with key pattern `skip_intro_{bookId}` and `skip_outro_{bookId}`
- Keep existing player functionality intact
- Handle edge cases (shorter chapters than skip time)
- Skip times are per-book, not global

---

## File Structure

- **Create:** `lib/widgets/skip_intro_outro_sheet.dart` - Bottom sheet UI for configuring per-book skip times
- **Modify:** `lib/services/player_settings.dart` - Add skip intro/outro getters/setters
- **Modify:** `lib/services/audio_player_service.dart` - Add skip logic in position stream listener
- **Modify:** `lib/widgets/card_button_config.dart` - Add skip_intro_outro button definition
- **Modify:** `lib/l10n/app_en.arb` - Add English translations for new UI strings
- **Modify:** `lib/widgets/card_buttons.dart` - Add handler for skip_intro_outro button

---

## Task 1: Add Per-Book Skip Settings to PlayerSettings

**Files:**
- Modify: `lib/services/player_settings.dart:64-116` (after existing skip settings around line 670-710)

**Interfaces:**
- Consumes: `ScopedPrefs` for persistence
- Produces: `getSkipIntro(String bookId)`, `setSkipIntro(String bookId, int seconds)`, `getSkipOutro(String bookId)`, `setSkipOutro(String bookId, int seconds)`

- [ ] **Step 1: Add skip intro/outro getters and setters**

Add after the existing `getEffectiveBackSkip` method (around line 710):

```dart
  // ── Per-book intro/outro skip (seconds) ──
  
  /// Skip intro time for a book (seconds), 0 = no skip.
  static Future<int> getSkipIntro(String bookId) async {
    final v = await ScopedPrefs.getInt('skip_intro_$bookId');
    return v ?? 0;
  }
  
  /// Set skip intro time for a book (seconds), 0 = no skip.
  static Future<void> setSkipIntro(String bookId, int seconds) async {
    await ScopedPrefs.setInt('skip_intro_$bookId', seconds.clamp(0, 3600));
    _notify();
  }
  
  /// Skip outro time for a book (seconds), 0 = no skip.
  static Future<int> getSkipOutro(String bookId) async {
    final v = await ScopedPrefs.getInt('skip_outro_$bookId');
    return v ?? 0;
  }
  
  /// Set skip outro time for a book (seconds), 0 = no skip.
  static Future<void> setSkipOutro(String bookId, int seconds) async {
    await ScopedPrefs.setInt('skip_outro_$bookId', seconds.clamp(0, 3600));
    _notify();
  }
```

- [ ] **Step 2: Run tests to verify no regressions**

Run: `flutter test`
Expected: All existing tests pass

- [ ] **Step 3: Commit**

```bash
git add lib/services/player_settings.dart
git commit -m "feat: add per-book skip intro/outro settings"
```

---

## Task 2: Add Skip Logic to AudioPlayerService

**Files:**
- Modify: `lib/services/audio_player_service.dart:5328-5500` (position stream listener)

**Interfaces:**
- Consumes: `PlayerSettings.getSkipIntro(bookId)`, `PlayerSettings.getSkipOutro(bookId)`, `_chapters`, `_totalDuration`, `_currentItemId`
- Produces: Automatic seeking when intro/outro conditions met

- [ ] **Step 1: Add skip intro/outro tracking fields**

Add after `_lastChapterCheckSec` declaration (around line 1480):

```dart
  // Per-book skip intro/outro times (cached from settings)
  int _skipIntroSeconds = 0;
  int _skipOutroSeconds = 0;
  bool _skipSettingsLoaded = false;
  String? _skipSettingsBookId;
  
  // Track whether we've already applied skip for current chapter
  int _lastSkipIntroChapterIndex = -1;
  int _lastSkipOutroChapterIndex = -1;
```

- [ ] **Step 2: Add method to load skip settings for current book**

Add after `_initChapterInfo` method (around line 4838):

```dart
  /// Load skip intro/outro settings for the current book.
  Future<void> _loadSkipSettings() async {
    if (_currentItemId == null) return;
    if (_skipSettingsBookId == _currentItemId && _skipSettingsLoaded) return;
    
    _skipIntroSeconds = await PlayerSettings.getSkipIntro(_currentItemId!);
    _skipOutroSeconds = await PlayerSettings.getSkipOutro(_currentItemId!);
    _skipSettingsLoaded = true;
    _skipSettingsBookId = _currentItemId;
    _lastSkipIntroChapterIndex = -1;
    _lastSkipOutroChapterIndex = -1;
    
    debugPrint(
      '[SkipIntroOutro] Loaded settings: intro=${_skipIntroSeconds}s outro=${_skipOutroSeconds}s for ${_currentItemId}',
    );
  }
```

- [ ] **Step 3: Add skip logic in position stream listener**

Insert after the chapter change detection block (after line 5490, before completion detection):

```dart
        // ─── Skip intro/outro logic ──────────────────────────
        if (_currentItemId != null && _chapters.isNotEmpty && _player?.playing == true) {
          await _loadSkipSettings();
          
          if ((_skipIntroSeconds > 0 || _skipOutroSeconds > 0) && chapterIdx >= 0) {
            // Skip intro: when entering a new chapter, seek past intro
            if (_skipIntroSeconds > 0 && chapterIdx != _lastSkipIntroChapterIndex) {
              final chapterDuration = chapterEnd - chapterStart;
              final relativePos = posSec - chapterStart;
              
              // Only skip if we're at the start of the chapter and chapter is longer than skip time
              if (relativePos < _skipIntroSeconds && chapterDuration > _skipIntroSeconds) {
                final seekTo = chapterStart + _skipIntroSeconds;
                debugPrint(
                  '[SkipIntroOutro] Skipping intro: seeking to ${seekTo.toStringAsFixed(1)}s (was at ${posSec.toStringAsFixed(1)}s)',
                );
                _lastSkipIntroChapterIndex = chapterIdx;
                await _seekAbsolute(seekTo);
                _logEvent(PlaybackEventType.seek, detail: 'skip intro');
              }
            }
            
            // Skip outro: when near chapter end, seek to next chapter
            if (_skipOutroSeconds > 0 && chapterIdx != _lastSkipOutroChapterIndex) {
              final chapterDuration = chapterEnd - chapterStart;
              final remaining = chapterEnd - posSec;
              
              // Only skip if we're within outro time of chapter end and chapter is longer than skip time
              if (remaining <= _skipOutroSeconds && chapterDuration > _skipOutroSeconds) {
                final nextChapterStart = ChapterLookup.nextSkipTarget(
                  _chapters,
                  posSec,
                  _totalDuration,
                );
                
                if (nextChapterStart != null && !nextChapterStart.finishesItem) {
                  debugPrint(
                    '[SkipIntroOutro] Skipping outro: seeking to next chapter at ${nextChapterStart.seconds.toStringAsFixed(1)}s',
                  );
                  _lastSkipOutroChapterIndex = chapterIdx;
                  await _seekAbsolute(nextChapterStart.seconds);
                  _logEvent(PlaybackEventType.seek, detail: 'skip outro');
                }
              }
            }
          }
        }
```

- [ ] **Step 4: Reset skip tracking on new book load**

In `playItem` method, after `_chapters = chapters;` (line 3284), add:

```dart
    // Reset skip settings for new book
    _skipSettingsLoaded = false;
    _skipSettingsBookId = null;
    _lastSkipIntroChapterIndex = -1;
    _lastSkipOutroChapterIndex = -1;
```

- [ ] **Step 5: Run tests to verify no regressions**

Run: `flutter test`
Expected: All existing tests pass

- [ ] **Step 6: Commit**

```bash
git add lib/services/audio_player_service.dart
git commit -m "feat: add skip intro/outro playback logic"
```

---

## Task 3: Add Skip Intro/Outro Card Button Definition

**Files:**
- Modify: `lib/widgets/card_button_config.dart:63-79`

**Interfaces:**
- Consumes: `CardButtonDef` class
- Produces: New `skip_intro_outro` button definition

- [ ] **Step 1: Add button definition**

Add to `_allCardButtons` list (after line 78):

```dart
  CardButtonDef('skip_intro_outro', 'Skip Intro/Outro', Icons.skip_next_rounded),
```

- [ ] **Step 2: Add localized label**

In `localizedCardButtonLabel` function, add case after line 47:

```dart
    case 'skip_intro_outro':
      return l.skipIntroOutro;
```

- [ ] **Step 3: Run tests to verify no regressions**

Run: `flutter test`
Expected: All existing tests pass

- [ ] **Step 4: Commit**

```bash
git add lib/widgets/card_button_config.dart
git commit -m "feat: add skip_intro_outro card button definition"
```

---

## Task 4: Add English Translations

**Files:**
- Modify: `lib/l10n/app_en.arb`

**Interfaces:**
- Consumes: ARB file format
- Produces: New translation strings

- [ ] **Step 1: Add translation strings**

Add at the end of the file (before closing `}`):

```json
  "skipIntroOutro": "Skip Intro/Outro",
  "skipIntroOutroTitle": "Skip Intro/Outro Settings",
  "skipIntroOutroDescription": "Automatically skip intro and outro for this book",
  "skipIntroLabel": "Skip Intro (seconds)",
  "skipOutroLabel": "Skip Outro (seconds)",
  "skipIntroHint": "Seconds to skip at chapter start",
  "skipOutroHint": "Seconds to skip before chapter end"
```

- [ ] **Step 2: Run tests to verify no regressions**

Run: `flutter test`
Expected: All existing tests pass

- [ ] **Step 3: Commit**

```bash
git add lib/l10n/app_en.arb
git commit -m "feat: add English translations for skip intro/outro"
```

---

## Task 5: Create Skip Intro/Outro Bottom Sheet UI

**Files:**
- Create: `lib/widgets/skip_intro_outro_sheet.dart`

**Interfaces:**
- Consumes: `PlayerSettings.getSkipIntro()`, `PlayerSettings.setSkipIntro()`, `PlayerSettings.getSkipOutro()`, `PlayerSettings.setSkipOutro()`, `AudioPlayerService.currentItemId`
- Produces: `showSkipIntroOutroSheet(BuildContext context)` function

- [ ] **Step 1: Create the bottom sheet widget**

Create new file `lib/widgets/skip_intro_outro_sheet.dart`:

```dart
import 'package:flutter/material.dart';
import '../l10n/app_localizations.dart';
import '../services/player_settings.dart';
import '../services/audio_player_service.dart';

/// Shows a bottom sheet to configure per-book skip intro/outro times.
Future<void> showSkipIntroOutroSheet(BuildContext context) async {
  final l = AppLocalizations.of(context)!;
  final bookId = AudioPlayerService().currentItemId;
  
  if (bookId == null) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(l.noBookPlaying)),
    );
    return;
  }
  
  int skipIntro = await PlayerSettings.getSkipIntro(bookId);
  int skipOutro = await PlayerSettings.getSkipOutro(bookId);
  
  if (!context.mounted) return;
  
  showModalBottomSheet(
    context: context,
    builder: (context) => _SkipIntroOutroSheet(
      bookId: bookId,
      initialSkipIntro: skipIntro,
      initialSkipOutro: skipOutro,
    ),
  );
}

class _SkipIntroOutroSheet extends StatefulWidget {
  final String bookId;
  final int initialSkipIntro;
  final int initialSkipOutro;
  
  const _SkipIntroOutroSheet({
    required this.bookId,
    required this.initialSkipIntro,
    required this.initialSkipOutro,
  });
  
  @override
  State<_SkipIntroOutroSheet> createState() => _SkipIntroOutroSheetState();
}

class _SkipIntroOutroSheetState extends State<_SkipIntroOutroSheet> {
  late int _skipIntro;
  late int _skipOutro;
  final _introController = TextEditingController();
  final _outroController = TextEditingController();
  
  @override
  void initState() {
    super.initState();
    _skipIntro = widget.initialSkipIntro;
    _skipOutro = widget.initialSkipOutro;
    _introController.text = _skipIntro > 0 ? _skipIntro.toString() : '';
    _outroController.text = _skipOutro > 0 ? _skipOutro.toString() : '';
  }
  
  @override
  void dispose() {
    _introController.dispose();
    _outroController.dispose();
    super.dispose();
  }
  
  Future<void> _saveAndClose() async {
    final intro = int.tryParse(_introController.text) ?? 0;
    final outro = int.tryParse(_outroController.text) ?? 0;
    
    await PlayerSettings.setSkipIntro(widget.bookId, intro);
    await PlayerSettings.setSkipOutro(widget.bookId, outro);
    
    if (mounted) Navigator.of(context).pop();
  }
  
  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context)!;
    final theme = Theme.of(context);
    
    return Padding(
      padding: const EdgeInsets.all(16.0),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            l.skipIntroOutroTitle,
            style: theme.textTheme.titleLarge,
          ),
          const SizedBox(height: 8),
          Text(
            l.skipIntroOutroDescription,
            style: theme.textTheme.bodyMedium?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: 24),
          TextField(
            controller: _introController,
            keyboardType: TextInputType.number,
            decoration: InputDecoration(
              labelText: l.skipIntroLabel,
              hintText: l.skipIntroHint,
              suffixText: 'seconds',
              border: const OutlineInputBorder(),
            ),
          ),
          const SizedBox(height: 16),
          TextField(
            controller: _outroController,
            keyboardType: TextInputType.number,
            decoration: InputDecoration(
              labelText: l.skipOutroLabel,
              hintText: l.skipOutroHint,
              suffixText: 'seconds',
              border: const OutlineInputBorder(),
            ),
          ),
          const SizedBox(height: 24),
          Row(
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              TextButton(
                onPressed: () => Navigator.of(context).pop(),
                child: Text(MaterialLocalizations.of(context).cancelButtonLabel),
              ),
              const SizedBox(width: 8),
              FilledButton(
                onPressed: _saveAndClose,
                child: Text(MaterialLocalizations.of(context).saveButtonLabel),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
```

- [ ] **Step 2: Run tests to verify no regressions**

Run: `flutter test`
Expected: All existing tests pass

- [ ] **Step 3: Commit**

```bash
git add lib/widgets/skip_intro_outro_sheet.dart
git commit -m "feat: add skip intro/outro bottom sheet UI"
```

---

## Task 6: Add Button Handler in Card Buttons

**Files:**
- Modify: `lib/widgets/card_buttons.dart`

**Interfaces:**
- Consumes: `showSkipIntroOutroSheet` from skip_intro_outro_sheet.dart
- Produces: Handler for 'skip_intro_outro' button tap

- [ ] **Step 1: Add import for skip_intro_outro_sheet.dart**

Add to imports section (after other sheet imports):

```dart
import 'skip_intro_outro_sheet.dart';
```

- [ ] **Step 2: Add case in buildCardButton method**

In the `buildCardButton` method's switch statement, add case for 'skip_intro_outro':

```dart
      case 'skip_intro_outro':
        return _buildIconButton(
          def.icon,
          accent,
          () => showSkipIntroOutroSheet(context),
          label: localizedCardButtonLabel(l, def),
          compact: compact,
          short: short,
          iconsOnly: iconsOnly,
        );
```

- [ ] **Step 3: Run tests to verify no regressions**

Run: `flutter test`
Expected: All existing tests pass

- [ ] **Step 4: Commit**

```bash
git add lib/widgets/card_buttons.dart
git commit -m "feat: add skip_intro_outro button handler"
```

---

## Task 7: Add Localization Strings to Other Languages

**Files:**
- Modify: Other `app_*.arb` files in `lib/l10n/`

**Interfaces:**
- Consumes: ARB file format
- Produces: Translation strings for all supported languages

- [ ] **Step 1: Add translation strings to all language files**

For each language file, add:

```json
  "skipIntroOutro": "Skip Intro/Outro",
  "skipIntroOutroTitle": "Skip Intro/Outro Settings",
  "skipIntroOutroDescription": "Automatically skip intro and outro for this book",
  "skipIntroLabel": "Skip Intro (seconds)",
  "skipOutroLabel": "Skip Outro (seconds)",
  "skipIntroHint": "Seconds to skip at chapter start",
  "skipOutroHint": "Seconds to skip before chapter end"
```

Note: English values shown. Replace with actual translations for each language.

- [ ] **Step 2: Run l10n generation**

Run: `flutter gen-l1n`
Expected: No errors

- [ ] **Step 3: Run tests to verify no regressions**

Run: `flutter test`
Expected: All existing tests pass

- [ ] **Step 4: Commit**

```bash
git add lib/l10n/
git commit -m "feat: add skip intro/outro translations for all languages"
```

---

## Task 8: Integration Testing

**Files:**
- Test: `test/services/player_settings_test.dart` (create if doesn't exist)

**Interfaces:**
- Consumes: `PlayerSettings` class
- Produces: Test coverage for skip intro/outro settings

- [ ] **Step 1: Add unit tests for skip settings**

Create or update `test/services/player_settings_test.dart`:

```dart
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:absorb/services/player_settings.dart';

void main() {
  group('Skip Intro/Outro Settings', () {
    setUp(() async {
      SharedPreferences.setMockInitialValues({});
    });

    test('getSkipIntro returns 0 by default', () async {
      final result = await PlayerSettings.getSkipIntro('test_book_id');
      expect(result, 0);
    });

    test('setSkipIntro stores value correctly', () async {
      await PlayerSettings.setSkipIntro('test_book_id', 30);
      final result = await PlayerSettings.getSkipIntro('test_book_id');
      expect(result, 30);
    });

    test('getSkipOutro returns 0 by default', () async {
      final result = await PlayerSettings.getSkipOutro('test_book_id');
      expect(result, 0);
    });

    test('setSkipOutro stores value correctly', () async {
      await PlayerSettings.setSkipOutro('test_book_id', 60);
      final result = await PlayerSettings.getSkipOutro('test_book_id');
      expect(result, 60);
    });

    test('skip times are per-book', () async {
      await PlayerSettings.setSkipIntro('book1', 10);
      await PlayerSettings.setSkipIntro('book2', 20);
      
      expect(await PlayerSettings.getSkipIntro('book1'), 10);
      expect(await PlayerSettings.getSkipIntro('book2'), 20);
    });

    test('clamp values to valid range', () async {
      await PlayerSettings.setSkipIntro('test_book_id', -5);
      expect(await PlayerSettings.getSkipIntro('test_book_id'), 0);
      
      await PlayerSettings.setSkipIntro('test_book_id', 5000);
      expect(await PlayerSettings.getSkipIntro('test_book_id'), 3600);
    });
  });
}
```

- [ ] **Step 2: Run tests**

Run: `flutter test test/services/player_settings_test.dart`
Expected: All tests pass

- [ ] **Step 3: Commit**

```bash
git add test/services/player_settings_test.dart
git commit -m "test: add unit tests for skip intro/outro settings"
```

---

## Verification Checklist

- [ ] Skip intro settings persist per-book
- [ ] Skip outro settings persist per-book
- [ ] Intro skip works when starting a chapter
- [ ] Outro skip works when near chapter end
- [ ] Skip logic doesn't affect chapters shorter than skip time
- [ ] Settings button appears in player card
- [ ] Settings sheet opens and saves correctly
- [ ] All existing player functionality unchanged
- [ ] No regressions in existing tests

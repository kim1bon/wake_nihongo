import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../quiz/domain/quiz_prompt_mode.dart';

final quizPromptModeProvider =
    AsyncNotifierProvider<QuizPromptModeNotifier, QuizPromptMode>(
  QuizPromptModeNotifier.new,
);

class QuizPromptModeNotifier extends AsyncNotifier<QuizPromptMode> {
  static const String _prefsKey = 'quiz_prompt_mode_v1';

  @override
  Future<QuizPromptMode> build() async {
    final prefs = await SharedPreferences.getInstance();
    return QuizPromptMode.fromStorage(prefs.getString(_prefsKey));
  }

  Future<void> setMode(QuizPromptMode mode) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_prefsKey, mode.storageValue);
    state = AsyncData(mode);
  }
}

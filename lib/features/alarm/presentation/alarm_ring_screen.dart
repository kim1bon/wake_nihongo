import 'package:flutter/material.dart';

/// 알림(전체 화면 인텐트 포함)으로 앱이 열렸을 때 표시하는 전용 화면. 뒤로 가기로는 닫히지 않습니다.
class AlarmRingScreen extends StatelessWidget {
  const AlarmRingScreen({
    super.key,
    required this.onDismiss,
  });

  final Future<void> Function() onDismiss;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return PopScope(
      canPop: false,
      child: Scaffold(
        backgroundColor: theme.colorScheme.surface,
        body: SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const SizedBox(height: 32),
                Icon(
                  Icons.alarm,
                  size: 72,
                  color: theme.colorScheme.primary,
                ),
                const SizedBox(height: 24),
                Text(
                  '알람',
                  style: theme.textTheme.headlineMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 16),
                Text(
                  '알람이 울리는 중입니다. 알람음은 끄기 전까지 반복됩니다.\n아래 버튼으로만 끌 수 있습니다.',
                  style: theme.textTheme.bodyLarge,
                  textAlign: TextAlign.center,
                ),
                const Spacer(),
                FilledButton(
                  style: FilledButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 18),
                  ),
                  onPressed: () async {
                    await onDismiss();
                    if (context.mounted) {
                      Navigator.of(context).pop();
                    }
                  },
                  child: const Text('알람 끄기'),
                ),
                const SizedBox(height: 16),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

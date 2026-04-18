import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'app/app.dart';
import 'app/config/app_bootstrap.dart';
import 'features/alarm/presentation/alarm_providers.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  final repository = await AppBootstrap.createAlarmRepository();
  registerAlarmRepository(repository);
  runApp(
    const ProviderScope(
      child: WakeNihongoApp(),
    ),
  );
}

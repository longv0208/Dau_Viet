import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'app/app.dart';
import 'features/learning/data/learning_providers.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  appContainer = ProviderContainer();
  runApp(
    UncontrolledProviderScope(
      container: appContainer!,
      child: const DauVietApp(),
    ),
  );
}

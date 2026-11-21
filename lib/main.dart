import 'package:flutter/material.dart';

import 'app/app.dart';
import 'app/app_state.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  final appState = AppState.createDefault();
  await appState.initialize();
  runApp(HakeemiDigitalLibraryApp(appState: appState));
}

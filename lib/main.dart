import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'core/strings.dart';
import 'core/world.dart';
import 'state.dart';
import 'ui/home.dart';
import 'ui/theme.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  final world = World.fromJson(jsonDecode(await rootBundle.loadString('assets/world.json')) as Map<String, dynamic>);
  final state = AppState(world, await SharedPreferences.getInstance());
  runApp(DunyaApp(state: state));
}

class DunyaApp extends StatelessWidget {
  const DunyaApp({super.key, required this.state});

  final AppState state;

  @override
  Widget build(BuildContext context) => ListenableBuilder(
        listenable: state,
        builder: (context, _) => MaterialApp(
          title: appName,
          debugShowCheckedModeBanner: false,
          theme: buildTheme(),
          locale: Locale(state.lang),
          home: HomeScreen(state: state),
        ),
      );
}

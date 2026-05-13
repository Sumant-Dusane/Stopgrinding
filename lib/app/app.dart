import 'package:flutter/material.dart';

import 'package:stopgrinding/app/di.dart';
import 'package:stopgrinding/app/routes.dart';
import 'package:stopgrinding/app/theme/app_theme.dart';

void runStopGrindingApp() {
  runApp(StopGrindingApp(di: AppDi.bootstrap()));
}

class StopGrindingApp extends StatefulWidget {
  const StopGrindingApp({super.key, required this.di});

  final AppDi di;

  @override
  State<StopGrindingApp> createState() => _StopGrindingAppState();
}

class _StopGrindingAppState extends State<StopGrindingApp> {
  @override
  void initState() {
    super.initState();
    widget.di.menuBarTrayService.initialize();
  }

  @override
  void dispose() {
    widget.di.menuBarTrayService.disposeService();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'StopGrinding',
      theme: AppTheme.build(),
      routes: appRoutes(widget.di),
      initialRoute: AppRoute.home,
    );
  }
}

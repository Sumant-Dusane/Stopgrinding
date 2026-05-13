import 'package:flutter/material.dart';

import 'package:stopgrinding/app/di.dart';
import 'package:stopgrinding/app/routes.dart';
import 'package:stopgrinding/app/theme/app_theme.dart';

void runStopGrindingApp() {
  runApp(StopGrindingApp(di: AppDi.bootstrap()));
}

class StopGrindingApp extends StatelessWidget {
  const StopGrindingApp({super.key, required this.di});

  final AppDi di;

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'StopGrinding',
      theme: AppTheme.build(),
      routes: appRoutes(di),
      initialRoute: AppRoute.home,
    );
  }
}

import 'package:flutter/material.dart';

import 'package:stopgrinding/app/di.dart';
import 'package:stopgrinding/app/routes.dart';

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
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: const Color(0xFF355C4D)),
      ),
      routes: appRoutes(di),
      initialRoute: AppRoute.home,
    );
  }
}

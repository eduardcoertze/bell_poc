import 'package:bell_poc/models/job_data.dart';
import 'package:bell_poc/screens/add_job_screen.dart';
import 'package:bell_poc/screens/home_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_foreground_task/flutter_foreground_task.dart';
import 'package:provider/provider.dart';

void main() {
  FlutterForegroundTask.initCommunicationPort();
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider(
      create: (BuildContext context) {
        return JobData();
      },
      child: MaterialApp(
        initialRoute: HomeScreen.id,
        routes: {
          HomeScreen.id : (context) => HomeScreen(),
          AddJobScreen.id : (context) => AddJobScreen()
        },
      ),
    );
  }
}

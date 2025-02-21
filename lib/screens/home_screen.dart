import 'dart:async';

import 'package:bell_poc/screens/add_job_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_foreground_task/flutter_foreground_task.dart';
import 'package:provider/provider.dart';

import '../models/job_data.dart';
import '../models/status_text.dart';

class HomeScreen extends StatefulWidget {
  static String id = 'home_screen';

  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  final ValueNotifier<Object?> _taskDataListenable = ValueNotifier(null);
  String serviceStatus = 'not running';

  Future<void> _requestPermissions() async {
    final NotificationPermission notificationPermission =
        await FlutterForegroundTask.checkNotificationPermission();
    if (notificationPermission != NotificationPermission.granted) {
      await FlutterForegroundTask.requestNotificationPermission();
    }
  }

  void _initService() {
    FlutterForegroundTask.init(
      androidNotificationOptions: AndroidNotificationOptions(
        channelId: 'foreground_service',
        channelName: 'Foreground Service Notification',
        channelDescription:
            'This notification appears when the foreground service is running.',
        onlyAlertOnce: true,
      ),
      iosNotificationOptions: const IOSNotificationOptions(
        //TODO Show notification is still set to false here
        showNotification: true,
        playSound: false,
      ),
      foregroundTaskOptions: ForegroundTaskOptions(
        eventAction: ForegroundTaskEventAction.repeat(5000),
        autoRunOnBoot: true,
        autoRunOnMyPackageReplaced: true,
        allowWakeLock: true,
        allowWifiLock: true,
      ),
    );
  }

  Future<void> _startService() async {
    if (await FlutterForegroundTask.isRunningService) {
      print("Restarting ForegroundTask Service");
      setState(() {
        serviceStatus = "restarting";
      });
      await FlutterForegroundTask.restartService();
    } else {
      print("Initializing ForegroundTask Service");
      setState(() {
        serviceStatus = "initializing";
      });
      await FlutterForegroundTask.startService(
        serviceId: 256,
        notificationTitle: 'Sync in progress',
        notificationText: 'Tap to return to the app',
        notificationIcon: null,
        notificationButtons: [
          const NotificationButton(id: 'btn_hello', text: 'Return to Bell'),
        ],
        notificationInitialRoute: HomeScreen.id,
        callback: startCallback,
      );
    }

    serviceStatus = await FlutterForegroundTask.isRunningService ? "running" : "not running";
    setState(() {});
  }

  void _onReceiveTaskData(Object data) {
    print('onReceiveTaskData: $data');
    _taskDataListenable.value = data;
    Provider.of<JobData>(context, listen: false).refreshJobs();
    if (data == false) {
      _stopService();
    }
  }

  Future<ServiceRequestResult> _stopService() {
    return FlutterForegroundTask.stopService();
  }

  void _loadTestData() async {
    final jobData = Provider.of<JobData>(context, listen: false);

    await jobData.clearJobs();
    for (var i = 0; i < 500; i++) {
      await jobData.addJob(
        DateTime.now().millisecondsSinceEpoch,
        'test-$i',
        StatusesText.created,
      );
    }
  }

  @override
  void initState() {
    super.initState();
    Provider.of<JobData>(context, listen: false).refreshJobs();

    FlutterForegroundTask.addTaskDataCallback(_onReceiveTaskData);

    WidgetsBinding.instance.addPostFrameCallback((_) async {
      _requestPermissions();
      _initService();
      serviceStatus = await FlutterForegroundTask.isRunningService ? "running" : "not running";
      setState(() {

      });
    });

    Timer.periodic(Duration(seconds: 5), (timer) { print("Main app still running"); });
  }

  @override
  void dispose() {
    FlutterForegroundTask.removeTaskDataCallback(_onReceiveTaskData);
    _taskDataListenable.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Home'),
      ),
      body: Column(
        children: [
          ElevatedButton(
            onPressed: () {
              Navigator.pushNamed(context, AddJobScreen.id);
            },
            child: const Text('Add Job'),
          ),
          ElevatedButton(
            onPressed: () {
              _startService();
            },
            child: const Text('Sync Jobs'),
          ),
          ElevatedButton(
              onPressed: () {
                _loadTestData();
              },
              child: const Text('Load Test Data')
          ),
          Text('Service status: $serviceStatus'),
          Expanded(
            child: Consumer<JobData>(
              builder: (context, jobData, child) {
                return ListView(
                  children: [
                    // Header Row with centered content
                    Padding(
                      padding: const EdgeInsets.all(8.0),
                      child: Row(
                        children: [
                          Expanded(
                            child: Text(
                              'Job Name',
                              style: TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: 18,
                              ),
                              textAlign: TextAlign.center,
                            ),
                          ),
                          Expanded(
                            child: Text(
                              'Status',
                              style: TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: 18,
                              ),
                              textAlign: TextAlign.center,
                            ),
                          ),
                        ],
                      ),
                    ),
                    // Job List
                    ...jobData.jobs.map((job) {
                      return Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 16.0),
                        child: Row(
                          children: [
                            Expanded(
                              child: Text(
                                job.name,
                                textAlign: TextAlign.center,
                                style: TextStyle(fontSize: 18),
                              ),
                            ),
                            Expanded(
                              child: Text(job.status,
                                  textAlign: TextAlign.center,
                                  style: TextStyle(fontSize: 18)),
                            ),
                          ],
                        ),
                      );
                    }).toList(),
                  ],
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

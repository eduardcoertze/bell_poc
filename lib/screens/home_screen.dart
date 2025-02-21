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
  final ValueNotifier<double> _syncProgress = ValueNotifier(0.0);

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
        showNotification: false,
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

  Future<ServiceRequestResult> _startService() async {
    if (await FlutterForegroundTask.isRunningService) {
      return FlutterForegroundTask.restartService();
    } else {
      return FlutterForegroundTask.startService(
        serviceId: 256,
        notificationTitle: 'Sync in progress',
        notificationText: 'Tap to return to the app',
        notificationIcon: NotificationIcon(
            metaDataName: 'notification_icon2', backgroundColor: Colors.black),
        notificationInitialRoute: HomeScreen.id,
        callback: startCallback,
      );
    }
  }

  void _onReceiveTaskData(Object data) {
    if (data is double) {
      _syncProgress.value = data;

      FlutterForegroundTask.updateService(
        notificationTitle: 'Sync in progress',
        notificationText: 'Syncing... ${(data * 100).toInt()}% completed',
      );
    } else if (data == false) {
      _syncProgress.value = 0.0;
      _stopService();
    }
    Provider.of<JobData>(context, listen: false).refreshJobs();
  }

  Future<ServiceRequestResult> _stopService() {
    _syncProgress.value = 0.0;
    return FlutterForegroundTask.stopService();
  }

  @override
  void initState() {
    super.initState();
    Provider.of<JobData>(context, listen: false).refreshJobs();

    FlutterForegroundTask.addTaskDataCallback(_onReceiveTaskData);

    WidgetsBinding.instance.addPostFrameCallback((_) {
      _requestPermissions();
      _initService();
    });
  }

  void _loadTestData() async {
    final jobData = Provider.of<JobData>(context, listen: false);
    for (var i = 0; i < 100; i++) {
      await jobData.addJob(
        DateTime.now().millisecondsSinceEpoch,
        'test-$i',
        StatusesText.created,
      );
    }
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
          ValueListenableBuilder<double>(
            valueListenable: _syncProgress,
            builder: (context, progress, child) {
              return Visibility(
                visible: progress > 0.0 && progress < 1.0, // Show only during syncing
                child: Padding(
                  padding: const EdgeInsets.symmetric(vertical: 8.0, horizontal: 16.0),
                  child: LinearProgressIndicator(
                    value: progress, // Progress from 0.0 to 1.0
                    backgroundColor: Colors.grey[300],
                    color: Colors.blue,
                  ),
                ),
              );
            },
          ),
          ElevatedButton(
            onPressed: () {
              _loadTestData();
            },
            child: const Text('Add test jobs'),
          ),
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

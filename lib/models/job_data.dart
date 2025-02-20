import 'dart:async';
import 'dart:collection';
import 'dart:math';
import 'package:bell_poc/database/database_helper.dart';
import 'package:bell_poc/models/job.dart';
import 'package:bell_poc/models/status_text.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_foreground_task/flutter_foreground_task.dart';

@pragma('vm:entry-point')
void startCallback() {
  FlutterForegroundTask.setTaskHandler(MyTaskHandler());
}

class MyTaskHandler extends TaskHandler {
  static const String updateJobs = 'updateJobs';

  bool hasPendingJobs = false;

  Future<void> _updateJobs() async {
    hasPendingJobs = await DatabaseHelper.instance.hasPendingJobs();
    FlutterForegroundTask.sendDataToMain(hasPendingJobs);
  }

  @override
  Future<void> onStart(DateTime timestamp, TaskStarter starter) async {
    await queueJobs();
    await runQueuedJobs();
  }

  @override
  Future<void> onRepeatEvent(DateTime timestamp) async {
    await runQueuedJobs();
  }

  Future<void> queueJobs() async {
    final jobsToQueue =
        await DatabaseHelper.instance.fetchJobsWithStatus("created");

    for (var job in jobsToQueue) {
      job.status = 'queued';
      await DatabaseHelper.instance.updateJob(job);
      print("Job ${job.name} moved to queued");
    }
    _updateJobs();
  }

  Future<void> runQueuedJobs() async {
    List<Job> jobs = await DatabaseHelper.instance.getJobsByStatus(
      status: 'queued',
      limit: 1,
    );

    if (jobs.isEmpty) {
      print("No queued jobs found.");
      return;
    }

    var job = jobs.first;

    await DatabaseHelper.instance
        .updateJob(Job(job.name, StatusesText.processing, job.id));

    _updateJobs();

    print("Executing job: ${job.name}");

    try {
      await executeJob(minDelay: 2, maxDelay: 10, failureChance: 0.1);
      await DatabaseHelper.instance
          .updateJob(Job(job.name, StatusesText.completed, job.id));
      print("Job completed: ${job.name}");

      int totalJobs = await DatabaseHelper.instance.countJobs();
      int completedJobs = await DatabaseHelper.instance.countJobsByStatus(StatusesText.completed);
      double progress = completedJobs / totalJobs;

      FlutterForegroundTask.sendDataToMain(progress);

      _updateJobs();

    } catch (e) {
      print('Error executing job: $e');
      await DatabaseHelper.instance
          .updateJob(Job(job.name, StatusesText.failed, job.id));
      _updateJobs();
    }
  }

  Future<void> executeJob({
    int minDelay = 5,
    int maxDelay = 20,
    double failureChance = 0,
  }) async {
    final random = Random();
    final delayDuration =
        Duration(seconds: random.nextInt(maxDelay - minDelay + 1) + minDelay);
    await Future.delayed(delayDuration);

    print("Task completed after ${delayDuration.inSeconds} seconds");
  }

  @override
  Future<void> onReceiveData(Object data) async {
    FlutterForegroundTask.sendDataToTask(MyTaskHandler.updateJobs);
  }

  @override
  void onNotificationButtonPressed(String id) {
    print('onNotificationButtonPressed: $id');
  }

  @override
  void onNotificationPressed() {
    print('onNotificationPressed');
  }

  @override
  void onNotificationDismissed() {
    print('onNotificationDismissed');
  }

  @override
  Future<void> onDestroy(DateTime timestamp) async {
    print('onDestroy');
  }
}

class JobData extends ChangeNotifier {
  final List<Job> _jobs = [];

  UnmodifiableListView<Job> get jobs {
    return UnmodifiableListView(_jobs);
  }

  Future<void> refreshJobs() async {
    final jobsFromDb = await DatabaseHelper.instance.fetchJobs();
    _jobs.clear();
    _jobs.addAll(jobsFromDb);
    notifyListeners();
  }

  Future<void> addJob(int id, String name, String status) async {
    final job = Job(name, status, id);
    await DatabaseHelper.instance.addJob(job);
    _jobs.add(job);
    notifyListeners();
  }
}

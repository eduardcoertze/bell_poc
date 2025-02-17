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

  static const String incrementCountCommand = 'incrementCount';

  int _count = 0;

  void _incrementCount() {
    _count++;

    // Update notification content.
    FlutterForegroundTask.updateService(
      notificationTitle: 'Hello MyTaskHandler :)',
      notificationText: 'count: $_count',
    );

    // Send data to main isolate.
    FlutterForegroundTask.sendDataToMain(_count);

    print("INCREMENT COUNT");
  }

  @override
  Future<void> onStart(DateTime timestamp, TaskStarter starter) async {
    print('onStart(starter: ${starter.name})');

    await queueJobs();
    await runQueuedJobs();
  }

  @override
  Future<void> onRepeatEvent(DateTime timestamp) async {
    print("Foreground task repeating...");
    await queueJobs().then((_) => runQueuedJobs());
  }

  Future<void> queueJobs() async {
    final jobsToQueue = await DatabaseHelper.instance.fetchJobsWithStatus("created");

    for (var job in jobsToQueue) {
      job.status = 'queued';
      await DatabaseHelper.instance.updateJob(job);
      print("Job ${job.name} moved to queued");
    }
    _incrementCount();
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

    _incrementCount();

    print("Executing job: ${job.name}");

    FlutterForegroundTask.updateService(
      notificationTitle: 'Processing Job',
      notificationText: 'Executing: ${job.name}',
    );

    try {
      await executeJob(minDelay: 2, maxDelay: 10, failureChance: 0.1);
      await DatabaseHelper.instance
          .updateJob(Job(job.name, StatusesText.completed, job.id));
      print("Job completed: ${job.name}");

      _incrementCount();

      FlutterForegroundTask.updateService(
        notificationTitle: 'Job Completed',
        notificationText: '${job.name} finished successfully',
      );
    } catch (e) {
      print('Error executing job: $e');
      await DatabaseHelper.instance
          .updateJob(Job(job.name, StatusesText.failed, job.id));
      _incrementCount();

      FlutterForegroundTask.updateService(
        notificationTitle: 'Job Failed',
        notificationText: '${job.name} encountered an error',
      );
    }
  }

  Future<void> executeJob({
    int minDelay = 2,
    int maxDelay = 10,
    double failureChance = 0.1,
  }) async {
    final random = Random();
    final delayDuration = Duration(seconds: random.nextInt(maxDelay - minDelay + 1) + minDelay);
    await Future.delayed(delayDuration);

    if (random.nextDouble() < failureChance) {
      throw Exception("Task failed after ${delayDuration.inSeconds} seconds");
    }

    print("Task completed after ${delayDuration.inSeconds} seconds");
  }

  @override
  Future<void> onReceiveData(Object data) async {
    FlutterForegroundTask.sendDataToTask(MyTaskHandler.incrementCountCommand);
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
  bool _isProcessing = false;

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

  Future<void> updateJobStatus(int index, String newStatus) async {
    final job = _jobs[index];
    job.status = newStatus;
    await DatabaseHelper.instance.updateJob(job);
    notifyListeners();
  }

  Future<void> loadJobs() async {
    final jobsFromDb = await DatabaseHelper.instance.fetchJobs();
    _jobs.clear();
    _jobs.addAll(jobsFromDb);
    notifyListeners();
  }

  Future<void> runQueuedJobs() async {
    if (_isProcessing) return;

    _isProcessing = true;

    List<Job> jobs = await DatabaseHelper.instance.getJobsByStatus(
      status: 'queued',
      limit: 1,
    );

    if (jobs.isEmpty) {
      _isProcessing = false;
      return;
    }

    var job = jobs.first;

    await DatabaseHelper.instance
        .updateJob(Job(job.name, StatusesText.processing, job.id));

    int index = _jobs.indexWhere((existingJob) => existingJob.id == job.id);
    if (index != -1) {
      _jobs[index].status = StatusesText.processing;
    }

    notifyListeners();

    try {
      print("Executing job...");
      await executeJob(minDelay: 2, maxDelay: 10, failureChance: 0.1); // Adjust parameters as needed
      await DatabaseHelper.instance
          .updateJob(Job(job.name, StatusesText.completed, job.id));

      if (index != -1) {
        _jobs[index].status = StatusesText.completed;
      }
      notifyListeners();
      _isProcessing = false;
    } catch (e) {
      print('Error executing job: $e');
      await DatabaseHelper.instance
          .updateJob(Job(job.name, StatusesText.failed, job.id));

      if (index != -1) {
        _jobs[index].status = StatusesText.failed;
      }

      notifyListeners();
      _isProcessing = false;
    }
  }

  Future<void> executeJob({
    int minDelay = 1,
    int maxDelay = 10,
    double failureChance = 0,
  }) async {
    final random = Random();

    // Ensure valid range
    if (minDelay > maxDelay || minDelay < 0) {
      throw ArgumentError("Invalid delay range: minDelay should be ≤ maxDelay and non-negative");
    }

    if (failureChance < 0 || failureChance > 1) {
      throw ArgumentError("failureChance must be between 0 and 1");
    }

    // Generate a random delay between minDelay and maxDelay seconds
    final delayDuration = Duration(seconds: random.nextInt(maxDelay - minDelay + 1) + minDelay);
    await Future.delayed(delayDuration);

    // Determine if the task should fail
    if (random.nextDouble() < failureChance) {
      throw Exception("Task failed after ${delayDuration.inSeconds} seconds");
    }

    print("Task completed after ${delayDuration.inSeconds} seconds");
  }
}

import 'dart:async';
import 'dart:collection';
import 'dart:math';
import 'package:bell_poc/database/database_helper.dart';
import 'package:bell_poc/models/job.dart';
import 'package:bell_poc/models/status_text.dart';
import 'package:flutter/foundation.dart';

class JobData extends ChangeNotifier {
  final List<Job> _jobs = [];
  bool _isProcessing = false;

  UnmodifiableListView<Job> get jobs {
    return UnmodifiableListView(_jobs);
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

  Future<void> queueJobs() async {
    final jobsToQueue = await DatabaseHelper.instance.fetchJobsWithStatus("created");

    for (var job in jobsToQueue) {
      job.status = 'queued';
      await DatabaseHelper.instance.updateJob(job);

      // Update the existing job in the list if it exists, otherwise don't add a new job.
      int index = _jobs.indexWhere((existingJob) => existingJob.id == job.id);
      if (index != -1) {
        _jobs[index] = job; // Update the job in the list
      }
    }
    notifyListeners(); // Notify the UI that the list has been updated
  }

  Future<void> deleteJob(int index) async {
    final job = _jobs[index];
    await DatabaseHelper.instance.deleteJob(job.id);
    _jobs.removeAt(index);
    notifyListeners();
  }

  Future<void> loadJobs() async {
    final jobsFromDb = await DatabaseHelper.instance.fetchJobs();
    _jobs.clear();
    _jobs.addAll(jobsFromDb);
    notifyListeners();
  }

  void startTimer() {
    const oneSecond = Duration(seconds: 1);

    Timer.periodic(oneSecond, (timer) {
      print('Timer');
      runQueuedJobs();
    });
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
    double failureChance = 0.05, // 5% failure rate by default
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

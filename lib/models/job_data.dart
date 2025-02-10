import 'dart:collection';
import 'package:flutter/foundation.dart';
import 'package:bell_poc/models/status_text.dart';
import 'package:bell_poc/models/job.dart';
import 'package:bell_poc/database/database_helper.dart';

class JobData extends ChangeNotifier {
  final List<Job> _jobs = [];

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
      _jobs[_jobs.indexOf(job)] = job;
    }
    notifyListeners();
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
}

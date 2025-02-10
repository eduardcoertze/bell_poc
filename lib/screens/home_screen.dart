import 'package:bell_poc/screens/add_job_screen.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../models/job_data.dart';

class HomeScreen extends StatefulWidget {
  static String id = 'home_screen';

  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  @override
  void initState() {
    super.initState();
    // Load jobs from the database when the screen is initialized
    Provider.of<JobData>(context, listen: false).loadJobs();
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
              // Add sync logic here
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

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:bell_poc/models/status_text.dart';
import '../models/job_data.dart';

class AddJobScreen extends StatefulWidget {

  static String id = 'add_job_screen';

  const AddJobScreen({super.key});

  @override
  _AddJobScreenState createState() => _AddJobScreenState();
}

class _AddJobScreenState extends State<AddJobScreen> {
  final TextEditingController _controller = TextEditingController();

  void _submitJob(BuildContext context) {
    if (_controller.text.isNotEmpty) {
      Provider.of<JobData>(context, listen: false).addJob(
        DateTime.now().millisecondsSinceEpoch,
        _controller.text,
        StatusesText.created,
      );
      Navigator.pop(context);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Add Job')),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          children: [
            TextField(
              controller: _controller,
              decoration: const InputDecoration(labelText: 'Job Name'),
            ),
            const SizedBox(height: 20),
            ElevatedButton(
              onPressed: () => _submitJob(context),
              child: const Text('Submit'),
            ),
          ],
        ),
      ),
    );
  }
}
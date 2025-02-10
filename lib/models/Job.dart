import 'package:bell_poc/models/status_text.dart';

class Job {
  final int id;
  String name;
  String status;

  Job(this.name, this.status, this.id);

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'name': name,
      'status': status,
    };
  }

  static Job fromMap(Map<String, dynamic> map) {
    return Job(
      map['name'],
      map['status'],
      map['id'],
    );
  }
}

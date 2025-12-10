import 'package:itc_institute_admin/model/student.dart';

import 'internship_model.dart';

class InternshipOrITWithApplicants {
  late final IndustrialTraining internship;
  late final List<Student>
  applicants; // You can replace Map with a Student model if you prefer

  InternshipOrITWithApplicants({
    required this.internship,
    required this.applicants,
  });
}

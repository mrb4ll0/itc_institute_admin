import 'dart:collection';
import 'dart:ui';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/services.dart';
import 'package:itc_institute_admin/itc_logic/firebase/company_cloud.dart';
import 'package:itc_institute_admin/itc_logic/firebase/general_cloud.dart';
import 'package:itc_institute_admin/itc_logic/service/tranineeService.dart';
import 'package:itc_institute_admin/model/authorityCompanyMapper.dart';
import 'package:itc_institute_admin/model/studentApplication.dart';
import 'package:itc_institute_admin/model/traineeRecord.dart';
import 'package:itc_institute_admin/view/home/industrailTraining/applications/studentWithLatestApplication.dart';

import '../backgroundTask/backgroundTaskRegistry.dart';
import '../model/authority.dart';
import '../model/company.dart';

class MigrationService {
  late Company_Cloud company_cloud;
  late ITCFirebaseLogic itcFirebaseLogic;
  late TraineeService traineeService;

  // Add a flag to track initialization
  static bool _firebaseInitialized = false;
  String globalUserId = "";

  MigrationService(String userId) {
    this.globalUserId = userId;
    _initializeFirebase();

  }

  Future<void> _initializeFirebase() async {
    try {
      debugPrint("🔥 Initializing Firebase in MigrationService");

      if (!_firebaseInitialized) {
        // ❌ REMOVE this - token already handled by BackgroundTaskManager
        // final rootIsolateToken = RootIsolateToken.instance;

        // ❌ REMOVE this - messenger already initialized
        // BackgroundIsolateBinaryMessenger.ensureInitialized(rootIsolateToken);

        // Just initialize Firebase (messenger already set up)
        if (Firebase.apps.isEmpty) {
          await Firebase.initializeApp();
          debugPrint("🔥 Firebase initialized");
        }
        _firebaseInitialized = true;
      }

      // Initialize services
      company_cloud = Company_Cloud(globalUserId);
      itcFirebaseLogic = ITCFirebaseLogic(globalUserId);
      traineeService = TraineeService(globalUserId);
      debugPrint("🔥 All services initialized");

    } catch (e, s) {
      debugPrint("🔥❌ Failed to initialize: $e");
      debugPrint("🔥❌ Stack trace: $s");
      rethrow;
    }
  }


  bool isAuthority = false;
  Company? _company;
  Future<void> startMigration() async {
    debugPrint("startMigration - entered method");

    // Register task at start
    final taskId = BackgroundTaskRegistry.registerTask(
      type: 'migration',
      metadata: {'startedBy': globalUserId},
    );
    debugPrint("Task registered with id: $taskId");

    try {
      BackgroundTaskRegistry.markTaskStarted(taskId);
      debugPrint("Task marked as started");

      List<String> companyIds =
      await checkIfUserIsAuthorityOrCompanyAndReturnTheID();
      debugPrint("Fetched companyIds: $companyIds");

      if (companyIds.isEmpty) {
        debugPrint("No companies found - marking task failed");
        BackgroundTaskRegistry.markTaskFailed(taskId, 'No companies found');
        debugPrint("Task marked as failed due to empty company list");
        return;
      }

      debugPrint("companyIds length: ${companyIds.length}");

      // Track progress in metadata
      BackgroundTaskRegistry.updateTaskStatus(
        taskId: taskId,
        status: 'running',
        metadata: {
          'totalCompanies': companyIds.length,
          'completedCompanies': 0,
        },
      );
      debugPrint("Task status updated to running with initial metadata");

      int completedCompanies = 0;
      debugPrint("Initialized completedCompanies = 0");

      for (String company in companyIds) {
        debugPrint("Starting migration for company: $company");

        await getAndPerformTheStudentMigration(company);
        debugPrint("Completed migration for company: $company");

        completedCompanies++;
        debugPrint("Incremented completedCompanies: $completedCompanies");

        // Update progress
        BackgroundTaskRegistry.updateTaskStatus(
          taskId: taskId,
          status: 'running',
          metadata: {
            'completedCompanies': completedCompanies,
            'currentCompany': company,
          },
        );
        debugPrint("Updated task status for company: $company");
      }

      debugPrint("All companies processed successfully");

      // Mark as completed with result
      BackgroundTaskRegistry.markTaskCompleted(
        taskId,
        result: {
          'companiesProcessed': companyIds.length,
          'completedAt': DateTime.now().toIso8601String(),
        },
      );
      debugPrint("Task marked as completed");
    } catch (e, s) {
      debugPrint("Error occurred in startMigration: $e");
      debugPrint("Stacktrace: $s");

      BackgroundTaskRegistry.markTaskFailed(taskId, e.toString());
      debugPrint("Task marked as failed due to exception");

      rethrow;
    }
  }

  getAndPerformTheStudentMigration(String companyId) async {
      debugPrint("getAndPerformTheStudentMigration - entered method");
      debugPrint("companyId: $companyId");
    List<StudentWithLatestApplication> recentStudentApplication =
        await company_cloud.getStudentsWithLatestApplications(
          companyId: _company!.id,
          isAuthority: isAuthority,
          companyIds: _company!.originalAuthority?.linkedCompanies,
        );

        debugPrint("recentStudentApplication length: ${recentStudentApplication.length}");
    for (StudentWithLatestApplication student in recentStudentApplication) {
      if (student.latestApplication == null) {
        debugPrint("latestApplication is null");
        continue;
      }
      // delete the trainee for the currentStudent
      int totalTrainee = await traineeService.deleteTraineesByStudentAndCompany(
        studentId: student.student.uid,
        companyId: companyId,
      );
      debugPrint("total trainee deleted $totalTrainee");
      TraineeRecord? record = await traineeService.createTraineeFromApplication(
        application: student.latestApplication!,
        companyId: companyId,
        companyName: _company!.name,
        fromUpdateStatus: true,
        isAuthority: isAuthority,
      );

      debugPrint("migration completed for student ${student.student.fullName}");
      if (record == null) {
        debugPrint("record is null after the migration");
        return;
      }
      debugPrint("Started status check and update");

      bool statusUpdated = await traineeService.updateTraineeStatus(
        traineeId: record.id,
        newStatus: record.calculatedStatusFromDates,
      );

      debugPrint(
        "Status ${record.calculatedStatusFromDates} update for student ${student.student.fullName} ${statusUpdated ? "Successfully" : "Failed"}",
      );
    }
  }

  Future<List<String>> checkIfUserIsAuthorityOrCompanyAndReturnTheID() async {
    String userId = globalUserId;
    Company? company = await itcFirebaseLogic.getCompany(userId);
    if (company != null) {
      _company = company;
      return [userId];
    }

    Authority? authority = await itcFirebaseLogic.getAuthority(userId);
    if (authority != null) {
      _company = AuthorityCompanyMapper.createCompanyFromAuthority(
        authority: authority,
      );
      isAuthority = true;
      return authority.linkedCompanies;
    }

    return [];
  }
}

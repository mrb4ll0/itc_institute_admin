import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:itc_institute_admin/itc_logic/firebase/general_cloud.dart';

import '../../model/AuthorityRule.dart';
import '../../model/authority.dart';
import '../../model/company.dart';


class AuthorityRulesHelper {
  static AuthorityRule? _studentAcceptanceRule;
  static final Map<String, bool> _companyStatusCache = {};
  static final Map<String, Company> _companiesCache = {};

  static final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  /// Initialize the helper with a rule
  static void initRule(AuthorityRule rule) {
    _studentAcceptanceRule = rule;

    _companyStatusCache.clear();
    if (!rule.applyToAllCompanies && rule.applicableCompanyIds.isNotEmpty) {
      for (var companyId in rule.applicableCompanyIds) {
        _companyStatusCache[companyId] = true;
      }
    }
  }

  static ITCFirebaseLogic itcFirebaseLogic = ITCFirebaseLogic(FirebaseAuth.instance.currentUser!.uid);

  /// Preload all companies under the authority into the cache
  static Future<void> preloadCompanies(String authorityId) async {

    Authority? authority = await itcFirebaseLogic.getAuthority(authorityId);
    if(authority == null)
      {
        return;
      }

    _companiesCache.clear();
    for (var doc in authority.linkedCompanies) {
      Company? company = await itcFirebaseLogic.getCompany(doc);
      if(company == null)
        {
          continue;
        }
      _companiesCache[company.id] = company;
    }
  }

  /// Get a company from cache by ID
  static Company? getCompany(String companyId) {
    return _companiesCache[companyId];
  }

  /// Check if a company is under authority
  static bool isUnderAuthority(String companyId) {
    final company = _companiesCache[companyId];
    return company?.isUnderAuthority ?? false;
  }

  /// Check if a company can accept students
  static bool canAcceptStudents(String companyId) {
    if (_studentAcceptanceRule == null) return false;

    if (_studentAcceptanceRule!.applyToAllCompanies) return true;

    return _companyStatusCache[companyId] ?? false;
  }

  /// Update a company’s acceptance status dynamically
  static void setCompanyStatus(String companyId, bool canAccept) {
    _companyStatusCache[companyId] = canAccept;

    if (_studentAcceptanceRule != null) {
      _studentAcceptanceRule = _studentAcceptanceRule!.copyWith(
        applicableCompanyIds: _companyStatusCache.entries
            .where((e) => e.value)
            .map((e) => e.key)
            .toList(),
      );
    }
  }

  /// Get list of all companies under authority
  static List<Company> getAllCompanies() {
    return _companiesCache.values.toList();
  }

  /// Get list of companies that can accept students
  static List<Company> getAllowedCompanies() {
    return _companiesCache.values
        .where((c) => canAcceptStudents(c.id))
        .toList();
  }

  /// Get list of companies that cannot accept students
  static List<Company> getBlockedCompanies() {
    return _companiesCache.values
        .where((c) => !canAcceptStudents(c.id))
        .toList();
  }

  /// Get list of IDs of companies that can accept students
  static List<String> getAllowedCompanyIds() {
    return _companiesCache.values
        .where((c) => canAcceptStudents(c.id))
        .map((c) => c.id)
        .toList();
  }
  /// Get list of IDs of companies that cannot accept students
  static List<String> getBlockedCompanyIds() {
    return _companiesCache.values
        .where((c) => !canAcceptStudents(c.id))
        .map((c) => c.id)
        .toList();
  }

}

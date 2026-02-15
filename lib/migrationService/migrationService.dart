import 'dart:collection';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:itc_institute_admin/itc_logic/firebase/company_cloud.dart';
import 'package:itc_institute_admin/itc_logic/firebase/general_cloud.dart';
import 'package:itc_institute_admin/model/authorityCompanyMapper.dart';
import 'package:itc_institute_admin/model/studentApplication.dart';
import 'package:itc_institute_admin/view/home/industrailTraining/applications/studentWithLatestApplication.dart';

import '../model/authority.dart';
import '../model/company.dart';

class MigrationService {

  Company_Cloud company_cloud = Company_Cloud();
  ITCFirebaseLogic itcFirebaseLogic = ITCFirebaseLogic();

    bool isAuthority = false;
    Company? _company ;
  startMigration()async
  {
    //first check if the current user is a company or authority and get their ids
       List<String> companyIds = await checkIfUserIsAuthorityOrCompanyAndReturnTheID();
          if(companyIds.isEmpty)
            {
              return;
            }

           // loop through the companyIds
          for(String company in companyIds)
            {
              List<String> students = await getAndPerformTheStudentMigration(company);

            }



  }

   getAndPerformTheStudentMigration(String companyId) async
  {
    List<StudentWithLatestApplication> recentStudentApplication = await company_cloud.getStudentsWithLatestApplications(companyId:_company!.id,isAuthority:isAuthority,companyIds: _company!.originalAuthority?.linkedCompanies);

    for(StudentWithLatestApplication student in recentStudentApplication)
    {

    }

  }

  Future<List<String>>checkIfUserIsAuthorityOrCompanyAndReturnTheID()async
  {
    String userId = FirebaseAuth.instance.currentUser!.uid;
     Company? company = await itcFirebaseLogic.getCompany(userId);
      if(company != null)
        {
          _company = company;
          return [userId];
        }

      Authority? authority = await itcFirebaseLogic.getAuthority(userId);
       if(authority != null)
         {
           _company = AuthorityCompanyMapper.createCompanyFromAuthority(authority: authority);
           isAuthority = true;
           return authority.linkedCompanies;
         }

       return [];
  }
}
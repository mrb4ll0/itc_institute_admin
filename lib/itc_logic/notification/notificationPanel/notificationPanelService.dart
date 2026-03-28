

import 'package:firebase_auth/firebase_auth.dart';
import 'package:itc_institute_admin/itc_logic/notification/fireStoreNotification.dart' hide NotificationType;
import 'package:itc_institute_admin/itc_logic/notification/notitification_service.dart';
import 'package:itc_institute_admin/model/notificationModel.dart';

import '../../../model/notificationSettingModel.dart';
import '../../localDB/sharedPreference.dart';

class NotificationPanelService {

  static final  notificationService = NotificationService();
  static final fireStoreNotification = FireStoreNotification();

       static sendNotification(NotificationType type,NotificationModel notification)async
       {
         User? user = FirebaseAuth.instance.currentUser;
          if(user == null || user.email == null)return;

         final settings = await UserPreferences.getNotificationSettings(user.email!);
         if(!settings.hasAnyEnabledInCategory(NotificationCategory.channels))return;

          if(type == NotificationType.push)
            {
              bool isEnabled = settings.isEnabled(NotificationType.push);

              if(!isEnabled)return;
              bool isSent = await notificationService.sendNotificationToUser(
                fcmToken: notification.fcmToken,
                title: notification.title,
                body: notification.body,
                data: notification.data,
              );
              NotificationDeliveryStatus  status = isSent ? NotificationDeliveryStatus.sent : NotificationDeliveryStatus.failed;
                  return status.displayName;

            }

          if(type == NotificationType.email)
            {
              bool isEnabled = settings.isEnabled(NotificationType.email);;

              if(!isEnabled)return;
              bool isSent = await notificationService.sendEmail(to: notification.targetAudience??"", subject: notification.title, body: notification.body);
              NotificationDeliveryStatus  status = isSent ? NotificationDeliveryStatus.sent : NotificationDeliveryStatus.failed;
              return status.displayName;

            }

          if(type == NotificationType.sms)
         {
           bool isEnabled = settings.isEnabled(NotificationType.sms);

           if(!isEnabled)return;
          // implementation will be coming soon

         }

          if(type == NotificationType.inApp)
         {
           bool isEnabled = settings.isEnabled(NotificationType.inApp);

           if(!isEnabled)return;
           await fireStoreNotification.sendNotificationToStudent(
             studentUid: notification.targetAudience??"",
             fcmToken: notification.fcmToken,
             title: notification.title,
             imageUrl: notification.imageUrl,
             body: notification.body,
           );

         }


       }
}
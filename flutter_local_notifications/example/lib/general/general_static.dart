 import 'dart:async';
import 'dart:developer';

import 'package:flutter/cupertino.dart';
import 'package:flutter/services.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:workmanager/workmanager.dart';

import '../blocs_and_cubits/prayer_times_api/prayer_time_api_bloc.dart';
import '../main.dart';
import '../models/prayer_time.dart';
import '../services/notification_service.dart';
 import 'package:intl/intl.dart';

class GeneralStatic {
   static bool isPrayertimeShown = false;

   @pragma('vm:entry-point')
   static FutureOr<dynamic> someFunction(String arg) {
      print("Running in an isolate with argument : $arg");
      return 1;
   }


   static initHive() async {
      await Hive.initFlutter();
      if (!Hive.isAdapterRegistered(1)) {
         Hive.registerAdapter(PrayerTimeAdapter());
      }
      if (!Hive.isAdapterRegistered(2)) {
         Hive.registerAdapter(DateAdapter());
      }
      if (!Hive.isAdapterRegistered(3)) {
         Hive.registerAdapter(GregorianAdapter());
      }
      if (!Hive.isAdapterRegistered(5)) {
         Hive.registerAdapter(HijriAdapter());
      }
      if (!Hive.isAdapterRegistered(6)) {
         Hive.registerAdapter(WeekdayAdapter());
      }
      if (!Hive.isAdapterRegistered(7)) {
         Hive.registerAdapter(MonthAdapter());
      }
      if (!Hive.isAdapterRegistered(4)) {
         Hive.registerAdapter(DesignationAdapter());
      }
   }

}

 enum PermissionStatus {
    provisional, // iOS Only
    granted,
    unknown,
    denied
 }
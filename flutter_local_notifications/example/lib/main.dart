import 'dart:async';
import 'dart:developer';
import 'dart:io';
import 'dart:convert';

import 'package:device_info_plus/device_info_plus.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_local_notifications_example/shared_preferemces/location_helper.dart';
import 'package:flutter_localizations/flutter_localizations.dart';

import 'package:flutter_timezone/flutter_timezone.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:flutter_local_notifications_example/services/notification_service.dart';
import 'package:logger/logger.dart';
import 'package:http/http.dart' as http;

import 'package:timezone/data/latest_all.dart' as tz;
import 'package:timezone/timezone.dart' as tz;
import 'package:flutter_local_notifications_example/pages/main.dart';
import 'package:flutter_local_notifications_example/themes_and_styles/themes_constants.dart';
import 'package:workmanager/workmanager.dart';
import 'package:intl/intl.dart';

import 'blocs_and_cubits/Internet/internet_bloc.dart';
import 'blocs_and_cubits/locale_cubit/locale_cubit.dart';
import 'blocs_and_cubits/location/location_bloc.dart';
import 'blocs_and_cubits/prayer_times_api/prayer_time_api_bloc.dart';
import 'blocs_and_cubits/theme_mode/theme_mode_cubit.dart';
import 'blocs_and_cubits/theme_mode/theme_mode_state.dart';
import 'blocs_and_cubits/time_format/time_format_cubit.dart';
import 'delegates/app_localization.dart';
import 'general/general_static.dart';
import 'models/prayer_time.dart';
import 'package:flutter_native_splash/flutter_native_splash.dart';
var logger = Logger(
  printer: PrettyPrinter(),
);

var loggerNoStack = Logger(
  printer: PrettyPrinter(methodCount: 0),
);

int id = 0;

late Box box;

final FlutterLocalNotificationsPlugin flutterLocalNotificationsPlugin =
    FlutterLocalNotificationsPlugin();

/// Streams are created so that app can respond to notification-related events
/// since the plugin is initialised in the `main` function
final StreamController<ReceivedNotification> didReceiveLocalNotificationStream =
    StreamController<ReceivedNotification>.broadcast();

final StreamController<String?> selectNotificationStream =
    StreamController<String?>.broadcast();

const MethodChannel platform =
    MethodChannel('dexterx.dev/flutter_local_notifications_example');

const String portName = 'notification_send_port';

class ReceivedNotification {
  ReceivedNotification({
    required this.id,
    required this.title,
    required this.body,
    required this.payload,
  });

  final int id;
  final String? title;
  final String? body;
  final String? payload;
}

String? selectedNotificationPayload;

/// A notification action which triggers a url launch event
const String urlLaunchActionId = 'id_1';

/// A notification action which triggers a App navigation event
const String navigationActionId = 'id_3';

/// Defines a iOS/MacOS notification category for text input actions.
const String darwinNotificationCategoryText = 'textCategory';

/// Defines a iOS/MacOS notification category for plain actions.
const String darwinNotificationCategoryPlain = 'plainCategory';

@pragma('vm:entry-point')
void notificationTapBackground(NotificationResponse notificationResponse) {
  // ignore: avoid_print
  print('notification(${notificationResponse.id}) action tapped: '
      '${notificationResponse.actionId} with'
      ' payload: ${notificationResponse.payload}');
  if (notificationResponse.input?.isNotEmpty ?? false) {
    // ignore: avoid_print
    print(
        'notification action tapped with input: ${notificationResponse.input}');
  }
}

/// IMPORTANT: running the following code on its own won't work as there is
/// setup required for each platform head project.
///
/// Please download the complete example app from the GitHub repository where
/// all the setup has been done
@pragma('vm:entry-point')
void _configureDidReceiveLocalNotificationSubject() {
  BuildContext? contetx;
  didReceiveLocalNotificationStream.stream
      .listen((ReceivedNotification receivedNotification) async {
    await showDialog(
      context: contetx!,
      builder: (BuildContext context) => CupertinoAlertDialog(
        title: receivedNotification.title != null
            ? Text(receivedNotification.title!)
            : null,
        content: receivedNotification.body != null
            ? Text(receivedNotification.body!)
            : null,
        actions: <Widget>[
          CupertinoDialogAction(
            isDefaultAction: true,
            onPressed: () async {
              Navigator.of(context, rootNavigator: true).pop();
              await Navigator.of(context).push(
                MaterialPageRoute<void>(
                  builder: (BuildContext context) =>
                      SecondPage(receivedNotification.payload),
                ),
              );
            },
            child: const Text('Ok'),
          )
        ],
      ),
    );
  });
}

@pragma('vm:entry-point')
void _configureSelectNotificationSubject() {
  BuildContext? context;

  selectNotificationStream.stream.listen((String? payload) async {
    await Navigator.of(context!).push(MaterialPageRoute<void>(
      builder: (BuildContext context) => SecondPage(payload),
    ));
  });
}

@pragma('vm:entry-point')
Future<void> _configureLocalTimeZone() async {
  // log('tz init1');

  if (kIsWeb || Platform.isLinux) {
    return;
  }
  tz.initializeTimeZones();
  final String? timeZoneName = await FlutterTimezone.getLocalTimezone();
  tz.setLocalLocation(tz.getLocation(timeZoneName!));
  // log('tz init2');
  // var tz1 = tz.TZDateTime;
  // log("tz1: $tz1");
  //   var tz2 = tz.TZDateTime.now(tz.local);
  // log("tz2: $tz2");
  //   var tz3 = tz.TZDateTime.now(tz.local).add(const Duration(minutes: 1));
  // log("tz3: $tz3");
  // await flutterLocalNotificationsPlugin.zonedSchedule(
  //     0,
  //     'scheduled title',
  //     'scheduled body',
  //     tz.TZDateTime.now(tz.local).add(const Duration(minutes: 1)),
  //     333333333,
  //     const NotificationDetails(
  //       android: AndroidNotificationDetails(
  //         'your channel id', 'your channel name',
  //         channelDescription: 'your channel description',
  //         // sound: RawResourceAndroidNotificationSound('prayer_time_norify_sound'),
  //       ),
  //     ),
  //     androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
  //     uiLocalNotificationDateInterpretation: UILocalNotificationDateInterpretation
  //         .absoluteTime);
}

@pragma('vm:entry-point')
void callbackDispatcher() {
  Workmanager()
      .executeTask((String task, Map<String, dynamic>? inputdata) async {
    try {
      String lunchTime = DateFormat('hh:mm:ss').format(DateTime.now());

     await initNotificatin();
      // String lang = await LocaleHelper().getCachedLanguageCode();
      // log('lng:$lang');
      // await NotificationService()
      //     .showNotification(title: 'Prayer Time', body: lang, id: 0);
      DateTime now = DateTime.now();
      // String formattedDate = DateFormat('kk:mm:ss \n EEE d MMM').format(now);
      // await NotificationService().showNotification(
      //     title: 'Prayer Time', body: ' $task $formattedDate', id: 11);

      await initHive();

      log('task');
      await schedulePTs();

      var prayerTimeBox = await Hive.openBox(PrayerTimeApiBloc.prayerTimeKey);
      List boxList = [];
      List<PrayerTime> prayerTimes = [
        // PrayerTime(date: Date(readable: 'hhh'))
      ];
      boxList = await (prayerTimeBox
          .get(PrayerTimeApiBloc.prayerTimeKey, defaultValue: []));
      // log('test boxList Empty length ${boxList.length}');

      prayerTimes = List<PrayerTime>.from(boxList);
      // log('text Box : date ${prayerTimes[0].date!.readable}');
      // log('test not Empty length ${prayerTimes.length}');

      // prayerTimes.addAll(prayerTimes);
      if (prayerTimes.length < 60) {
      // if (now.month == DateTime.december && now.day >= 20) {

          await loadNextYear();
        }


      if (Platform.isAndroid) {
        var androidInfo = await DeviceInfoPlugin().androidInfo;
        // var release = androidInfo.version.release;
        var sdkInt = androidInfo.version.sdkInt;
        // var manufacturer = androidInfo.manufacturer;
        // var model = androidInfo.model;
        // print('Android $release (SDK $sdkInt), $manufacturer $model');
        // Android 9 (SDK 28), Xiaomi Redmi Note 7
        if (sdkInt > 21) {
          if (task == 'init00') {
            await Workmanager().registerPeriodicTask(
              "load",
              "load",
              initialDelay:
              Duration(days: 2 // firstDailySchedule.millisecondsSinceEpoch -
                //now.millisecondsSinceEpoch
              ),
              constraints: Constraints(
                  networkType: NetworkType.not_required,
                  requiresDeviceIdle: false,
                  requiresBatteryNotLow: true,
                  requiresStorageNotLow: true,
                  requiresCharging: false),
              existingWorkPolicy: ExistingWorkPolicy.keep,
              frequency: Duration(minutes: 16),
            );
          }
        }else {

          String taskStrInit = task.substring(4, 5);
          int taskInt = int.parse(taskStrInit);
          if (taskInt > 998)
            taskInt = -1;
          taskInt++;
          String taskStr = task.substring(0, 3) + taskInt.toString();
          logger.e('newTsakName $taskStr');
          await Workmanager().registerOneOffTask(
            taskStr,
            taskStr,
            initialDelay: Duration(days: 2),
            constraints: Constraints(
                networkType: NetworkType.not_required,
                requiresDeviceIdle: false,
                requiresBatteryNotLow: false,
                requiresStorageNotLow: false,
                requiresCharging: false),
            existingWorkPolicy: ExistingWorkPolicy.update,
          );
          await NotificationService().showNotification(
              title: 'Prayer Time', body: ' newxt is$taskStr ', id: 777);

        }
      }
        log('workMan taskName: $task');
        // await NotificationService().showNotification(
        //     title: 'Prayer Time', body: ' $task $formattedDate done', id: 111);

        return Future.value(true);

    } catch (err) {
      logger.e(
          'quietError :${err}'); // Logger flutter package, prints error on the debug console
      await NotificationService().showNotification(
          title: 'Prayer Time', body: 'Error ${err.toString()}', id: 404);
      throw Exception(err);
    }
  });
}


void main() async {
  WidgetsBinding widgetsBinding = await WidgetsFlutterBinding.ensureInitialized();
  FlutterNativeSplash.preserve(widgetsBinding: widgetsBinding);
  // Future.delayed(Duration(seconds: 2)).then((v){
    runApp(MyApp());

    FlutterNativeSplash.remove();

  // });
  Workmanager()
      .initialize(callbackDispatcher, isInDebugMode: true)
      .then((value) async {
    Workmanager().cancelAll().then((value) async {
      // await WidgetsFlutterBinding.ensureInitialized();

      HttpOverrides.global = await MyHttpOverrides();

    });
  });
  await initHive();


  await initNotificatin();
  await _configureLocalTimeZone();


}

class HomePage {
  static var routeName;
}

initHive() async {
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



initNotificatin() async{
  final FlutterLocalNotificationsPlugin flutterLocalNotificationsPlugin =
  FlutterLocalNotificationsPlugin();

  /// Streams are created so that app can respond to notification-related events
  /// since the plugin is initialised in the `main` function
  final StreamController<ReceivedNotification>
  didReceiveLocalNotificationStream =
  StreamController<ReceivedNotification>.broadcast();

  final StreamController<String?> selectNotificationStream =
  StreamController<String?>.broadcast();

  /// A notification action which triggers a App navigation event
  const String navigationActionId = 'id_3';

  /// Defines a iOS/MacOS notification category for text input actions.
  const String darwinNotificationCategoryText = 'textCategory';

  /// Defines a iOS/MacOS notification category for plain actions.
  const String darwinNotificationCategoryPlain = 'plainCategory';

  await WidgetsFlutterBinding.ensureInitialized();

  const AndroidInitializationSettings initializationSettingsAndroid =
  AndroidInitializationSettings('ic_launcher');

  final List<DarwinNotificationCategory> darwinNotificationCategories =
  <DarwinNotificationCategory>[
    DarwinNotificationCategory(
      darwinNotificationCategoryText,
      actions: <DarwinNotificationAction>[
        DarwinNotificationAction.text(
          'text_1',
          'Action 1',
          buttonTitle: 'Send',
          placeholder: 'Placeholder',
        ),
      ],
    ),
    DarwinNotificationCategory(
      darwinNotificationCategoryPlain,
      actions: <DarwinNotificationAction>[
        DarwinNotificationAction.plain('id_1', 'Action 1'),
        DarwinNotificationAction.plain(
          'id_2',
          'Action 2 (destructive)',
          options: <DarwinNotificationActionOption>{
            DarwinNotificationActionOption.destructive,
          },
        ),
        DarwinNotificationAction.plain(
          navigationActionId,
          'Action 3 (foreground)',
          options: <DarwinNotificationActionOption>{
            DarwinNotificationActionOption.foreground,
          },
        ),
        DarwinNotificationAction.plain(
          'id_4',
          'Action 4 (auth required)',
          options: <DarwinNotificationActionOption>{
            DarwinNotificationActionOption.authenticationRequired,
          },
        ),
      ],
      options: <DarwinNotificationCategoryOption>{
        DarwinNotificationCategoryOption.hiddenPreviewShowTitle,
      },
    )
  ];

  /// Note: permissions aren't requested here just to demonstrate that can be
  /// done later
  final DarwinInitializationSettings initializationSettingsDarwin =
  DarwinInitializationSettings(
    requestAlertPermission: false,
    requestBadgePermission: false,
    requestSoundPermission: false,
    onDidReceiveLocalNotification:
        (int id, String? title, String? body, String? payload) async {
      didReceiveLocalNotificationStream.add(
        ReceivedNotification(
          id: id,
          title: title,
          body: body,
          payload: payload,
        ),
      );
    },
    notificationCategories: darwinNotificationCategories,
  );
  final LinuxInitializationSettings initializationSettingsLinux =
  LinuxInitializationSettings(
    defaultActionName: 'Open notification',
    defaultIcon: AssetsLinuxIcon('icons/app_icon.png'),
  );
  final InitializationSettings initializationSettings =
  InitializationSettings(
    android: initializationSettingsAndroid,
    iOS: initializationSettingsDarwin,
    macOS: initializationSettingsDarwin,
    linux: initializationSettingsLinux,
  );

  await flutterLocalNotificationsPlugin.initialize(
    initializationSettings,
    onDidReceiveNotificationResponse:
        (NotificationResponse notificationResponse) {
      switch (notificationResponse.notificationResponseType) {
        case NotificationResponseType.selectedNotification:
          selectNotificationStream.add(notificationResponse.payload);
          break;
        case NotificationResponseType.selectedNotificationAction:
          if (notificationResponse.actionId == navigationActionId) {
            selectNotificationStream.add(notificationResponse.payload);
          }
          break;
      }
    },
    onDidReceiveBackgroundNotificationResponse: notificationTapBackground,
  );

}



Future schedulePTs() async {
  var prayerTimeBox = await Hive.openBox(PrayerTimeApiBloc.prayerTimeKey);
  List boxList = [];
  List<PrayerTime> prayerTimes = [];
  DateTime now = DateTime.now();

  var launchDate = DateFormat('dd MMM yyyy').format(now);
  // log('lunchDate: $launchDate');

  var nextDayDateForPT = DateFormat('dd MMM yyyy')
      .format(DateTime(now.year, now.month, now.day + 1));

  var next2DayDateForPT = DateFormat('dd MMM yyyy')
      .format(DateTime(now.year, now.month, now.day + 2));

  var nextDayDateForDaily = DateFormat('yyyy-MM-dd')
      .format(DateTime(now.year, now.month, now.day + 1));

  String currentDate = DateFormat('yyyy-MM-dd').format(DateTime.now());

  boxList = await (prayerTimeBox
      .get(PrayerTimeApiBloc.prayerTimeKey, defaultValue: []));

  prayerTimes = List<PrayerTime>.from(boxList);

  if (prayerTimes.isNotEmpty) {
    PrayerTime currentPrayerTime = prayerTimes.firstWhere(
            (PrayerTime prayerTime) => prayerTime.date!.readable == launchDate);

    // await flutterLocalNotificationsPlugin.reScheduleNotification();

    bool isScheduled = false;
    if (currentPrayerTime != null) {
      // isScheduled =
      await currentPrayerTime.scheduleNotifications();
      // log('isScheduled 1: $isScheduled');
    }

    currentPrayerTime = prayerTimes.firstWhere((PrayerTime prayerTime) =>
    prayerTime.date!.readable == nextDayDateForPT);
    if (currentPrayerTime != null) {
      // isScheduled =
      await currentPrayerTime.scheduleNotifications();
      // log('isScheduled 2: $isScheduled');
    }
    // log('before getting Next Day 2');
    currentPrayerTime = prayerTimes.firstWhere((PrayerTime prayerTime) =>
    prayerTime.date!.readable == next2DayDateForPT);
    // log('after getting Next Day 2');
    if (currentPrayerTime != null) {
      // isScheduled =
      await currentPrayerTime.scheduleNotifications();
      // log('isScheduled 3: $isScheduled');
    }

    List<PendingNotificationRequest> pendignList = await NotificationService()
        .notificationsPlugin
        .pendingNotificationRequests();

    // await NotificationService().showNotification(
    //     title: 'Prayer Time', body: 'Count ${pendignList.length}', id: 505);



  }

}

Future loadNextYear() async {
  DateTime now = DateTime.now();
  var year = DateFormat('yyyy').format(DateTime(now.year));
  var nextYear = DateFormat('yyyy').format(DateTime(now.year + 1));

  final String? country, city;
  var url;
  List<String>? countryAndCity =
  await LocationHelper().getCachedCountryAndCity();
  country = countryAndCity![0];
  city = countryAndCity![1];
  if (country != null && city != null) {
    bool loaded = false;
    late Box prayerTimeBox;
    if (now.month == DateTime.december) {
      // log('getPrayerTimes year: ${nextYear}, country: ${country}, city: ${city}');
      url = Uri.https(
          PrayerTimeApiBloc.url_base,
          'v1/calendarByCity/${nextYear}',
          {'method': '4', 'country': country, 'city': city});
    } else {
      // log('getPrayerTimes year: ${year}, country: ${country}, city: ${city}');
      url = Uri.https(PrayerTimeApiBloc.url_base, 'v1/calendarByCity/${year}',
          {'method': '4', 'country': country, 'city': city});
    }
    log('url: ${url}');
    var response = await http.get(url);
    if (response != null) {
      log('response: ${response}');
    }
    print('Response status: ${response.statusCode}');
    if (response.statusCode == 200) {
      // print('Response body: ${response.body}');

      Map<String, dynamic> months = jsonDecode(response.body)['data'];
      log('months count: ${months.length}');
      List<PrayerTime> list = [];
      List<dynamic> days;
      String currentDate = DateFormat('dd MMM yyyy').format(DateTime.now());
      int fullDayTimstamp = (1000 * 60 * 60 * 24);
      PrayerTime prayerTime = PrayerTime();
      bool foundToday = false;

      months.forEach((key, value) {
        // log('${key}:: ${value}');
        days = value as List;
        for (var day in days) {
          String prayerTimeDate = day['date']['readable'];
          // log('day : ${prayerTimeDate}, current day:${currentDate}');
          if (foundToday) {
            prayerTime = PrayerTime.fromJson(day["timings"]);
            prayerTime.date = Date.fromJson(day['date']);
            // log('added PrayerTime ${prayerTime.date!.readable}');

            list.add(prayerTime);
          } else if (prayerTimeDate == currentDate) {
            prayerTime = PrayerTime.fromJson(day["timings"]);
            prayerTime.date = Date.fromJson(day['date']);
            // log('added PrayerTime ${prayerTime.date!.readable}');

            list.add(prayerTime);
            foundToday = true;
          }
        }
      });
      // log('date: ${list[0].date!.gregorian!.weekday!.en!}');
      //
      // log('fajer: ${list[0].fajr}');
      // log('date: ${list[0].date!.hijri!.weekday!.ar!}');
      // log('PtayerTimesCount: ${list.length}');

      // await NotificationService().showNotification(
      //     title: 'Prayer Time', body: '', id: 999);
      prayerTimeBox = await Hive.openBox(PrayerTimeApiBloc.prayerTimeKey);

      await prayerTimeBox.put(PrayerTimeApiBloc.prayerTimeKey, list);
    }
  }
}

class MyApp extends StatelessWidget {
  MyApp({super.key});

  // This widget is the root of your application.
  @override
  Widget build(BuildContext context) {
    return MultiBlocProvider(
      providers: [
        BlocProvider(create: (context) => LocalCubit()..getSavedLanguage()),
        BlocProvider(create: (contxt) => TimeFormatCubit()..getTimeFormat()),
        BlocProvider(create: (contxt) => ThemeModeCubit()..getSavedTheme()),
        BlocProvider(create: (contxt) => InternetBloc()..add(InitialEvent())),
      ],
      child: BlocBuilder<LocalCubit, ChangedLocalState>(
          builder: (context, localState) {
        return BlocBuilder<ThemeModeCubit, ThemeModeChangedState>(
          builder: (context, themeState) {
            return MaterialApp(
              debugShowCheckedModeBanner: false,
              theme: themeState.theme == 'light' ? lightTheme : darkTheme,
              // ),
              locale: localState.locale,
              supportedLocales: [
                Locale('en'),
                Locale('ar'),
              ],
              localizationsDelegates: [
                // LocalJsonLocalization.delegate,
                AppLocalizations.delegate,
                GlobalMaterialLocalizations.delegate,
                GlobalWidgetsLocalizations.delegate,
                GlobalCupertinoLocalizations.delegate,
              ],

              title: 'Prayer Times',

              home: MyHomePage(),
            );
          },
        );
        // });
      }),
    );
  }

}

class MyHttpOverrides extends HttpOverrides {
  @override
  HttpClient createHttpClient(SecurityContext? context) {
    return super.createHttpClient(context)
      ..badCertificateCallback =
          (X509Certificate cert, String host, int port) => true;
  }
}

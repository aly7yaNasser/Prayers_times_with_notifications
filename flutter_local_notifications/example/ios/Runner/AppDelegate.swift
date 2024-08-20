import UIKit
import Flutter
import flutter_local_notifications
import workmanager

@main

@objc class AppDelegate: FlutterAppDelegate {

  override func application(
    _ application: UIApplication,
    didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
  ) -> Bool {
    // This is required to make any communication available in the action isolate.
    FlutterLocalNotificationsPlugin.setPluginRegistrantCallback { (registry) in
        GeneratedPluginRegistrant.register(with: registry)
}

WorkmanagerPlugin.setPluginRegistrantCallback { registry in
            // Registry in this case is the FlutterEngine that is created in Workmanager's
            // performFetchWithCompletionHandler or BGAppRefreshTask.
            // This will make other plugins available during a background operation.
            GeneratedPluginRegistrant.register(with: registry)
        }
 WorkmanagerPlugin.registerBGProcessingTask(withIdentifier: "be.tramckrijte.workmanagerExample.taskId")
        WorkmanagerPlugin.registerBGProcessingTask(withIdentifier: "be.tramckrijte.workmanagerExample.rescheduledTask")
        WorkmanagerPlugin.registerBGProcessingTask(withIdentifier: "be.tramckrijte.workmanagerExample.simpleDelayedTask")
        WorkmanagerPlugin.registerBGProcessingTask(withIdentifier: "be.tramckrijte.workmanagerExample.iOSBackgroundProcessingTask")
        WorkmanagerPlugin.registerPeriodicTask(withIdentifier: "be.tramckrijte.workmanagerExample.iOSBackgroundAppRefresh", frequency: NSNumber(value: 20 * 60))
 UIApplication.shared.setMinimumBackgroundFetchInterval(TimeInterval(60*15))

    if #available(iOS 10.0, *) {
      UNUserNotificationCenter.current().delegate = self as? UNUserNotificationCenterDelegate
    }

    GeneratedPluginRegistrant.register(with: self)
    return super.application(application, didFinishLaunchingWithOptions: launchOptions)
  }
}

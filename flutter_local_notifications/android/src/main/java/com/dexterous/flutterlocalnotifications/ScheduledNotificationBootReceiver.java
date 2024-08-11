package com.dexterous.flutterlocalnotifications;

import android.content.BroadcastReceiver;
import android.content.Context;
import android.content.Intent;
import androidx.core.app.NotificationCompat;

import android.app.AlarmManager;
import android.app.Notification;
import android.app.NotificationChannel;
import android.app.NotificationManager;
import android.app.PendingIntent;
import android.app.Service;
import android.content.ComponentName;

import android.os.AsyncTask;
import android.os.Build;
import android.os.IBinder;
import android.provider.Settings;
import android.util.Log;

import androidx.annotation.Nullable;
import androidx.annotation.Keep;
import com.dexterous.flutterlocalnotifications.FlutterLocalNotificationsPlugin;
import com.dexterous.flutterlocalnotifications.models.*;
import java.util.ArrayList;


@Keep
public class ScheduledNotificationBootReceiver extends BroadcastReceiver {
  @Override
  @SuppressWarnings("deprecation")
  public void onReceive(final Context context, Intent intent) {
    ArrayList<NotificationDetails> scheduledNotifications = FlutterLocalNotificationsPlugin.loadScheduledNotifications(context);
    Log.e("boot", "count:" +String.valueOf(scheduledNotifications.size()));
//    FlutterLocalNotificationsPlugin.NotifMe(context, "on Recive",76, scheduledNotifications.get(0));

    String action = intent.getAction();
    if (action != null) {
      if (action.equals(android.content.Intent.ACTION_BOOT_COMPLETED)
              || action.equals(Intent.ACTION_MY_PACKAGE_REPLACED)
              || action.equals("android.intent.action.QUICKBOOT_POWERON")
              || action.equals("com.htc.intent.action.QUICKBOOT_POWERON")) {
        FlutterLocalNotificationsPlugin.rescheduleNotifications(context);
      }
    }
  }
}


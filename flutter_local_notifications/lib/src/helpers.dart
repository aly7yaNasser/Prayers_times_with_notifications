import 'dart:developer';

import 'package:clock/clock.dart';
import 'package:timezone/timezone.dart';

import 'types.dart';

/// Helper method for validating a date/time value represents a future point in
/// time where `matchDateTimeComponents` is null.
void validateDateIsInTheFuture(
  TZDateTime scheduledDate,
  DateTimeComponents? matchDateTimeComponents,
) {
  // log('tz6 starts');
  // log("tz6 dateTime: ${scheduledDate.toString()}");
  if (matchDateTimeComponents != null) {
    return;
  }
  if (scheduledDate.isBefore(clock.now())) {
    throw ArgumentError.value(
        scheduledDate, 'scheduledDate', 'Must be a date in the future');
  }
  // log('tz6 ends');

}

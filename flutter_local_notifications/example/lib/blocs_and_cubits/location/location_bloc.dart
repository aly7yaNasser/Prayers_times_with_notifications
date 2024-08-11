import 'dart:async';
import 'dart:convert';
import 'dart:developer';
import 'dart:io';
import 'dart:isolate';
import 'package:bloc/bloc.dart';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter/cupertino.dart';
import 'package:geocoding/geocoding.dart';
import 'package:geolocator/geolocator.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:meta/meta.dart';
import 'package:intl/intl.dart';
import 'package:workmanager/workmanager.dart';

import '../../general/general_static.dart';
import '../../models/prayer_time.dart';
import '../../services/notification_service.dart';
import '../../shared_preferemces/location_helper.dart';
import '../prayer_times_api/prayer_time_api_bloc.dart';

part 'location_event.dart';
part 'location_state.dart';

class LocationBloc extends Bloc<LocationEvent, LocationState>
    with WidgetsBindingObserver {
  late bool isServiceEnabled = false,
      isLocationChange = false,
      isLocationPermission = false;
  late LocationPermission permission;
  late Box prayerTimeBox;
  Position? position= null;

  final GeolocatorPlatform _geolocatorPlatform = GeolocatorPlatform.instance;
  StreamSubscription? _subscription;
  String? launchDate;
  LocationBloc() : super(LocationInitial()) {
    on<LocationEvent>((event, emit) async {
      launchDate = DateFormat('dd MMM yyyy').format(DateTime.now());

      if (event is GetMyLocation) {
        log('loc Bloc GetMyLocationEvent');
        await handleLocationPermission(null);
      }
    });
    WidgetsBinding.instance.addObserver(this);

    _subscription = _geolocatorPlatform
        .getServiceStatusStream()
        .listen((ServiceStatus result) async {
      log('location Stream');
      handleLocationPermission(result == ServiceStatus.enabled);
    });
  }
  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    if(_subscription != null) {
      _subscription!.cancel();
    }
  }

  Future<void> didChangeAppLifecycleState(AppLifecycleState state) async {
    // log('Lifecycle Changed');
    if (state == AppLifecycleState.resumed) {
      String nowDate = DateFormat('dd MMM yyyy').format(DateTime.now());
      // log('launchDate: ${launchDate}');
      // log('nowDate: ${nowDate}');
      if (nowDate != launchDate || !GeneralStatic.isPrayertimeShown) {
        // log('isPrayertimeShown: ${GeneralStatic.isPrayertimeShown}');
        // log('Lifecycle Loc Ser = ${isServiceEnabled.toString()}');

        permission = await Geolocator.checkPermission();
        // log('Lifecycle Per : ${permission}');

        if (permission != LocationPermission.denied &&
            permission != LocationPermission.deniedForever &&
            isServiceEnabled) {
          // _context!.read().add(GetMyLocation());
          handleLocationPermission(null);
        }
      }
    }

    // else {
    //   log('Context:  null');
    // }
  }

  Future<bool?> handleLocationPermission(bool? isisServiceEnabled) async {
    // log('1');
    emit(LocationInitial());
    bool s = await showStoredPrayertimes();
    if (s) {
      GeneralStatic.isPrayertimeShown = true;

      // log('2,true');
    } else {
      // log('2,false');

      if (isisServiceEnabled != null) {
        isServiceEnabled = isisServiceEnabled;
      } else {
        isServiceEnabled = await _geolocatorPlatform.isLocationServiceEnabled();
      }

      // log('handle Per : Loc Ser = ${isServiceEnabled.toString()}');

      permission = await _geolocatorPlatform.checkPermission();
      // log('handle Per : Loc Per = ${permission.toString()}');
      // log('3');

      if (permission == LocationPermission.denied ||
          permission == LocationPermission.deniedForever ||
          permission == null) {
        // await _geolocatorPlatform.requestPermission();

        permission = await _geolocatorPlatform.checkPermission();

        // log('handle Per : per = ${permission.toString()}');
      }
      // log('4');

      if (!isServiceEnabled) {
        // log('Services Not enabled');
        emit(LocationNotEnabledState());
      } else if (permission == LocationPermission.denied ||
          permission == LocationPermission.deniedForever) {
        // log('Location Per not Enabled');
        isLocationPermission = false;
        emit(LocationNotAllowedState());
      } else {
        // log('befor getting Location time:${DateTime.now().millisecondsSinceEpoch}');
        getLocation().then((value) async {
          // log('af getting Location time:${DateTime.now().millisecondsSinceEpoch}');
          bool b = await value;
          if (b) {
            // log('5, true');
            // emit(LocationNotEnabledState());
            return true;
          } else {
            // log('5 false');

            // log('6');

            // emit(LocationChangedState(
            //     newMyLocationAR: null,
            //     newMyLocationEN: null,
            //     newCountry: null,
            //     newCity: null));
          }
        });
      }
    }
  }

  Future<bool> getLocation() async {
    final receivePort = ReceivePort();

    if (permission != LocationPermission.denied &&
        permission != LocationPermission.deniedForever &&
        isServiceEnabled) {
      ConnectivityResult result = await Connectivity().checkConnectivity();

      // log('loc Bloc Conn : ${result.toString()}');

      if (result == ConnectivityResult.wifi ||
          result == ConnectivityResult.mobile) {
        // log('Conection State: connected');
        bool isLoaded = false;
        if (position != null){
          await getCity(position!);
        }else {
          // log('before try');
          try {
            // log('try');
            Future getPos = Geolocator.getCurrentPosition(
                desiredAccuracy: LocationAccuracy.lowest,
                forceAndroidLocationManager: Platform.isAndroid,
                timeLimit: Duration(seconds: 5));
            getPos.then((pos) async {
              position = pos;
              if (position != null) {
                // log("try position: ${position!.altitude}");
                if (position != null) {
                  isLoaded = await getCity(position!);
                }
              }
            });
            getPos.whenComplete(() {
              // log('getPos Completed');
            });
            getPos.onError((handleError, stackTrace) {
              // log("error: $handleError, stackTrace: $stackTrace");
              // log("before 2nd loaction");
              if (position == null) {
                // log("postion is null");

                Future getPos2 = Geolocator.getCurrentPosition(
                  desiredAccuracy: LocationAccuracy.lowest,
                  // forceAndroidLocationManager: true
                );
                getPos2.then((pos) async {
                  position = pos;

                  if (position != null) {
                    isLoaded = await getCity(position!);
                    if (!isLoaded) {
                      emit(LocationChangedState(
                          newMyLocationAR: null,
                          newMyLocationEN: null,
                          newCountry: null,
                          newCity: null));
                    }
                  }
                  // log("tyr2 position: ${position!.altitude}");
                  // log('after try2 ');

                  // log('try 3nds2');
                });
                getPos2.whenComplete(() {
                  // log('2nd Completed');
                });
              } else {
                // log("postion is not null");
              }
            });
            // log('after try');
          } catch (e) {
            log('catch');
            Geolocator.getCurrentPosition(
              desiredAccuracy: LocationAccuracy.lowest,
              // forceAndroidLocationManager: true
            ).then((pos) async {
              position = pos;
              if (position != null) {
                isLoaded = await getCity(position!);
              }
              // log("catchposition: ${position!.altitude}");
              // log('after catch');
              // log('after catch message: $e');
              //
              // log('try 3nds2');
            });
          }
        }
        if (isLoaded) {
          return true;
        }
      } else {
        return false;
      }
    } else {
      return false;
    }

    return false;
  }

  Future<bool> getCity(Position position) async {
    try {
      // log(' try bloc');
      List<Placemark> placemarksEN = await placemarkFromCoordinates(
          position.latitude, position.longitude,
          localeIdentifier: 'en');
      log('pos EN: ${placemarksEN[0].country}');
      if (placemarksEN.isNotEmpty) {
        final String country = placemarksEN[0].country!;
        final String city = placemarksEN[0].locality!;
        // final String country = 'Saudi Arabia';
        // final String city = 'Riyadh';

        final myLocationEN = '${country}, ${city}';
        // final myLocationEN = 'Saudi Arabia, Riyadh';

        List<Placemark> placemarksAR = await placemarkFromCoordinates(
            position.latitude, position.longitude,
            localeIdentifier: 'ar');
        if (placemarksAR.isNotEmpty) {
          final String countryAR = placemarksAR[0].country!;
          final String cityAR = placemarksAR[0].locality!;
          final myLocationAR = '${countryAR}, ${cityAR}';
          log('before Caching: EN:${myLocationEN}, AR ${myLocationAR},  countr: ${country},  city: ${city}');

          await LocationHelper()
              .cacheLocation(myLocationAR, myLocationEN, country, city);
          log('before emit');
// emit(LocationNotAllowedState());
// emit(LocationNotEnabledState());
          emit(LocationChangedState(
              newMyLocationAR: myLocationAR,
              newMyLocationEN: myLocationEN,
              newCountry: country,
              newCity: city));
          log('after emit');
          isLocationChange = true;
          return true;
        }
      }
    } catch (e) {
      log('catch: $e');
    }
    return false;
  }

  Future<bool> showStoredPrayertimes() async {
    prayerTimeBox = await Hive.openBox(PrayerTimeApiBloc.prayerTimeKey);
    List boxList = [];
    List<PrayerTime> prayerTimes = [
      // PrayerTime(date: Date(readable: 'hhh'))
    ];
    boxList = await (prayerTimeBox
        .get(PrayerTimeApiBloc.prayerTimeKey, defaultValue: []));
    log('test boxList Empty length ${boxList.length}');

    prayerTimes = List<PrayerTime>.from(boxList);
    // log('text Box : date ${prayerTimes[0].date!.readable}');
    log('test not Empty length ${prayerTimes.length}');

    // prayerTimes.addAll(prayerTimes);
    if (prayerTimes.isNotEmpty) {
      PrayerTime currentPrayerTime = prayerTimes.firstWhere(
          (PrayerTime prayerTime) => prayerTime.date!.readable == launchDate);
      log('Box list count ${prayerTimes.length}');
      log('Box Prayer time date: ${currentPrayerTime.date!.readable}');
      String? myLocationAR, myLocationEN, country, city;

      myLocationEN = await LocationHelper().getCachedLocationEN();
      // log('loc bloc  LocationEN: ${myLocationEN}');

      if (myLocationEN != null) {
        myLocationAR = await LocationHelper().getCachedLocationAR();
        List<String>? countryAndCity =
            await LocationHelper().getCachedCountryAndCity();
        country = countryAndCity![0];
        city = countryAndCity![1];
        // await LocationHelper().cacheLocation(
        //     myLocationAR!, myLocationEN, country, city);
      }
      if (currentPrayerTime != null) {
        log('loc bloc : current PT date ${currentPrayerTime.date!.readable}');
        isLocationChange = false;
        emit(LocationFoundDataState(
            prayerTime: currentPrayerTime,
            newMyLocationAR: myLocationAR,
            newMyLocationEN: myLocationEN,
            newCountry: city,
            newCity: country));
        int currentMonth = DateTime.now().month;
        log('Cur Month: ${currentMonth}');
        // int? ishaTimestampe = currentPrayerTime.getNextPrayerTime();

        if (currentMonth == 12) {
          int nextYear = DateTime.now().year;

          PrayerTimeApiBloc()
              .getPrayerTimes(country: country!, city: city!, year: nextYear);
        }
        return true;
      }
    }
    return false;
  }
}

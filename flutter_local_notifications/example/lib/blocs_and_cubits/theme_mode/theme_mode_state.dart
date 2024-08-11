import 'dart:developer';

import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';

import '../../shared_preferemces/theme_data_helper.dart';

 class ThemeModeChangedState {
   String theme;

   ThemeModeChangedState({required this.theme})  {
     log('theme: ${theme}');
     if (theme == 'init' || theme == 'auto') {
       var brightness = SchedulerBinding.instance.platformDispatcher
           .platformBrightness;
       theme = brightness == Brightness.dark? 'dark':'light';
     }
      themeHelper().cacheTheme(theme);
   }
 }


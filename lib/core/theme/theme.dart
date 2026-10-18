import 'package:flutter/material.dart';
import 'package:flutter/cupertino.dart';
import 'app_colors.dart';
import 'app_text.dart';

class AppTheme {
  static ThemeData get darkTheme {
    return ThemeData(
      brightness: Brightness.dark,
      scaffoldBackgroundColor: AppColors.background,
      fontFamily: AppText.fontFamily,
      colorScheme: const ColorScheme.dark(
        surface: AppColors.surface,
        primary: AppColors.accent,
        onPrimary: Colors.black,
        error: AppColors.bad,
      ),
      appBarTheme: const AppBarTheme(
        backgroundColor: AppColors.background,
        foregroundColor: AppColors.text,
        elevation: 0,
        centerTitle: true,
        titleTextStyle: AppText.headline,
      ),
      cupertinoOverrideTheme: const CupertinoThemeData(
        brightness: Brightness.dark,
        scaffoldBackgroundColor: AppColors.background,
        barBackgroundColor: AppColors.background,
        primaryColor: AppColors.accent,
        textTheme: CupertinoTextThemeData(
          primaryColor: AppColors.text,
          textStyle: AppText.body,
        ),
      ),
    );
  }
}

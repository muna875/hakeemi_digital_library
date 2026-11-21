import 'package:flutter/material.dart';
import 'app_colors.dart';
import 'app_spacing.dart';

class AppTheme {
  AppTheme._();

  static ThemeData lightTheme() {
    const colorScheme = ColorScheme(
      brightness: Brightness.light,
      primary: AppColors.primaryForestGreen,
      onPrimary: AppColors.paperWhite,
      secondary: AppColors.secondarySage,
      onSecondary: AppColors.paperWhite,
      tertiary: AppColors.mutedGold,
      onTertiary: AppColors.mainText,
      error: AppColors.dangerRed,
      onError: AppColors.paperWhite,
      surface: AppColors.paperWhite,
      onSurface: AppColors.mainText,
      surfaceContainerHighest: AppColors.warmIvory,
      outline: AppColors.border,
    );

    return ThemeData(
      useMaterial3: true,
      colorScheme: colorScheme,
      scaffoldBackgroundColor: AppColors.warmIvory,
      fontFamily: 'NotoSans',
      appBarTheme: const AppBarTheme(
        backgroundColor: AppColors.warmIvory,
        foregroundColor: AppColors.mainText,
        elevation: 0,
        scrolledUnderElevation: 1,
        surfaceTintColor: AppColors.warmIvory,
        centerTitle: false,
        titleTextStyle: TextStyle(
          fontFamily: 'NotoSerif',
          fontSize: 20,
          fontWeight: FontWeight.w700,
          color: AppColors.mainText,
          letterSpacing: -0.2,
        ),
      ),
      cardTheme: CardTheme(
        color: AppColors.paperWhite,
        elevation: 0,
        margin: EdgeInsets.zero,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppSpacing.cardRadius),
          side: const BorderSide(color: AppColors.border, width: 1),
        ),
      ),
      dividerTheme: const DividerThemeData(
        color: AppColors.border,
        thickness: 1,
        space: 1,
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: AppColors.paperWhite,
        contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppSpacing.inputRadius),
          borderSide: const BorderSide(color: AppColors.border),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppSpacing.inputRadius),
          borderSide: const BorderSide(color: AppColors.border),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppSpacing.inputRadius),
          borderSide: const BorderSide(
            color: AppColors.primaryForestGreen,
            width: 1.5,
          ),
        ),
        labelStyle: const TextStyle(color: AppColors.secondaryText),
        hintStyle: const TextStyle(color: AppColors.secondaryText),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: AppColors.primaryForestGreen,
          foregroundColor: AppColors.paperWhite,
          elevation: 0,
          minimumSize: const Size(48, 46),
          padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AppSpacing.buttonRadius),
          ),
          textStyle: const TextStyle(
            fontFamily: 'NotoSans',
            fontWeight: FontWeight.w600,
            fontSize: 14,
          ),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: AppColors.primaryForestGreen,
          side: const BorderSide(color: AppColors.primaryForestGreen),
          minimumSize: const Size(48, 46),
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AppSpacing.buttonRadius),
          ),
          textStyle: const TextStyle(
            fontFamily: 'NotoSans',
            fontWeight: FontWeight.w600,
            fontSize: 14,
          ),
        ),
      ),
      navigationBarTheme: NavigationBarThemeData(
        backgroundColor: AppColors.paperWhite,
        surfaceTintColor: AppColors.paperWhite,
        indicatorColor: AppColors.sageTint,
        elevation: 0,
        labelTextStyle: WidgetStateProperty.resolveWith((states) {
          final selected = states.contains(WidgetState.selected);
          return TextStyle(
            fontFamily: 'NotoSans',
            fontSize: 12,
            fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
            color: selected
                ? AppColors.primaryForestGreen
                : AppColors.secondaryText,
          );
        }),
        iconTheme: WidgetStateProperty.resolveWith((states) {
          final selected = states.contains(WidgetState.selected);
          return IconThemeData(
            color: selected
                ? AppColors.primaryForestGreen
                : AppColors.secondaryText,
            size: 22,
          );
        }),
      ),
      textTheme: const TextTheme(
        headlineMedium: TextStyle(
          fontFamily: 'NotoSerif',
          fontSize: 24,
          fontWeight: FontWeight.w700,
          color: AppColors.mainText,
        ),
        titleLarge: TextStyle(
          fontFamily: 'NotoSerif',
          fontSize: 19,
          fontWeight: FontWeight.w700,
          color: AppColors.mainText,
        ),
        titleMedium: TextStyle(
          fontFamily: 'NotoSerif',
          fontSize: 16,
          fontWeight: FontWeight.w600,
          color: AppColors.mainText,
        ),
        bodyLarge: TextStyle(
          fontFamily: 'NotoSans',
          fontSize: 15,
          height: 1.55,
          color: AppColors.mainText,
        ),
        bodyMedium: TextStyle(
          fontFamily: 'NotoSans',
          fontSize: 14,
          height: 1.5,
          color: AppColors.mainText,
        ),
        bodySmall: TextStyle(
          fontFamily: 'NotoSans',
          fontSize: 12,
          height: 1.4,
          color: AppColors.secondaryText,
        ),
      ),
    );
  }
}

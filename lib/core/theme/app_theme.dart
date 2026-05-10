import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'app_colors.dart';
import 'app_radius.dart';
import 'app_text_styles.dart';

class AppTheme {
  AppTheme._();

  static ThemeData get light => ThemeData(
        useMaterial3: true,
        brightness: Brightness.light,
        scaffoldBackgroundColor: AppColors.scaffoldBackground,
        primaryColor: AppColors.primary,
        colorScheme: ColorScheme.fromSeed(
          seedColor: AppColors.primary,
          primary: AppColors.primary,
          surface: AppColors.surface,
        ),
        fontFamily: AppTextStyles.bodyMedium.fontFamily,
        appBarTheme: AppBarTheme(
          backgroundColor: Colors.transparent,
          elevation: 0,
          scrolledUnderElevation: 0,
          centerTitle: true,
          foregroundColor: AppColors.textPrimary,
          titleTextStyle:
              AppTextStyles.h4.copyWith(color: AppColors.textPrimary),
          iconTheme: const IconThemeData(color: AppColors.textPrimary),
          // SystemUiOverlayStyle.dark sets statusBarColor: null, which lets
          // Android paint its default opaque scrim (black) on top of our
          // gradients. Spell out a transparent overlay AND disable the
          // Q+ contrast scrim (*ContrastEnforced: false) so the gradient
          // shows through edge-to-edge under the status bar.
          systemOverlayStyle: const SystemUiOverlayStyle(
            statusBarColor: Colors.transparent,
            statusBarIconBrightness: Brightness.dark,
            statusBarBrightness: Brightness.light,
            systemStatusBarContrastEnforced: false,
            systemNavigationBarColor: Colors.transparent,
            systemNavigationBarIconBrightness: Brightness.dark,
            systemNavigationBarContrastEnforced: false,
          ),
        ),
        textTheme: TextTheme(
          headlineLarge:
              AppTextStyles.h1.copyWith(color: AppColors.textPrimary),
          headlineMedium:
              AppTextStyles.h2.copyWith(color: AppColors.textPrimary),
          headlineSmall:
              AppTextStyles.h3.copyWith(color: AppColors.textPrimary),
          titleLarge:
              AppTextStyles.h4.copyWith(color: AppColors.textPrimary),
          bodyLarge:
              AppTextStyles.bodyLarge.copyWith(color: AppColors.textPrimary),
          bodyMedium:
              AppTextStyles.bodyMedium.copyWith(color: AppColors.textPrimary),
          bodySmall: AppTextStyles.bodySmall,
          labelLarge: AppTextStyles.label,
        ),
        inputDecorationTheme: InputDecorationTheme(
          filled: true,
          fillColor: AppColors.surface,
          contentPadding:
              const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          hintStyle: AppTextStyles.bodyMedium.copyWith(
            color: AppColors.textHint,
            fontWeight: FontWeight.w400,
          ),
          labelStyle: AppTextStyles.label.copyWith(color: AppColors.textSecondary),
          border: OutlineInputBorder(
            borderRadius: AppRadius.inputRadius,
            borderSide: const BorderSide(color: AppColors.cardBorder),
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: AppRadius.inputRadius,
            borderSide: const BorderSide(color: AppColors.cardBorder),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: AppRadius.inputRadius,
            borderSide: const BorderSide(color: AppColors.primary, width: 1.5),
          ),
          errorBorder: OutlineInputBorder(
            borderRadius: AppRadius.inputRadius,
            borderSide: const BorderSide(color: AppColors.urgent),
          ),
          focusedErrorBorder: OutlineInputBorder(
            borderRadius: AppRadius.inputRadius,
            borderSide: const BorderSide(color: AppColors.urgent, width: 1.5),
          ),
        ),
        elevatedButtonTheme: ElevatedButtonThemeData(
          style: ElevatedButton.styleFrom(
            backgroundColor: AppColors.primary,
            foregroundColor: Colors.white,
            elevation: 0,
            padding: const EdgeInsets.symmetric(vertical: 16),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(50),
            ),
            textStyle: AppTextStyles.button,
          ),
        ),
        cardTheme: CardThemeData(
          color: AppColors.surface,
          elevation: 0,
          shape: RoundedRectangleBorder(
            borderRadius: AppRadius.xlRadius,
            side: const BorderSide(color: AppColors.cardBorder),
          ),
        ),
        // Dialog + sheet themes are explicitly wired so AlertDialog /
        // showModalBottomSheet pick up the right surface + text colors
        // in both modes — without these, Material 3 falls back to its
        // own colorScheme defaults, which made dialog body text appear
        // off-contrast in light mode.
        dialogTheme: DialogThemeData(
          backgroundColor: AppColors.surface,
          surfaceTintColor: Colors.transparent,
          shape: RoundedRectangleBorder(borderRadius: AppRadius.lgRadius),
          titleTextStyle:
              AppTextStyles.h4.copyWith(color: AppColors.textPrimary),
          contentTextStyle:
              AppTextStyles.bodyMedium.copyWith(color: AppColors.textPrimary),
        ),
        bottomSheetTheme: const BottomSheetThemeData(
          backgroundColor: AppColors.surface,
          surfaceTintColor: Colors.transparent,
          modalBackgroundColor: AppColors.surface,
          elevation: 0,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
          ),
        ),
        popupMenuTheme: PopupMenuThemeData(
          color: AppColors.surface,
          surfaceTintColor: Colors.transparent,
          textStyle:
              AppTextStyles.bodyMedium.copyWith(color: AppColors.textPrimary),
          shape: RoundedRectangleBorder(borderRadius: AppRadius.mdRadius),
        ),
        listTileTheme: ListTileThemeData(
          textColor: AppColors.textPrimary,
          iconColor: AppColors.textSecondary,
          titleTextStyle:
              AppTextStyles.bodyMedium.copyWith(color: AppColors.textPrimary),
          subtitleTextStyle: AppTextStyles.bodySmall
              .copyWith(color: AppColors.textSecondary),
        ),
        dividerTheme: const DividerThemeData(
          color: AppColors.divider,
          thickness: 1,
          space: 1,
        ),
      );

  static ThemeData get dark => ThemeData(
        useMaterial3: true,
        brightness: Brightness.dark,
        scaffoldBackgroundColor: AppColors.darkScaffoldBackground,
        primaryColor: AppColors.primary,
        colorScheme: ColorScheme.fromSeed(
          seedColor: AppColors.primary,
          brightness: Brightness.dark,
          primary: AppColors.primary,
          surface: AppColors.darkSurface,
        ),
        fontFamily: AppTextStyles.bodyMedium.fontFamily,
        appBarTheme: AppBarTheme(
          backgroundColor: Colors.transparent,
          elevation: 0,
          scrolledUnderElevation: 0,
          centerTitle: true,
          foregroundColor: AppColors.darkTextPrimary,
          titleTextStyle:
              AppTextStyles.h4.copyWith(color: AppColors.darkTextPrimary),
          iconTheme: const IconThemeData(color: AppColors.darkTextPrimary),
          // Mirror of the light-mode override: explicit transparent
          // status bar + disable the Q+ contrast scrim so dark-mode
          // gradients render edge-to-edge instead of getting masked.
          systemOverlayStyle: const SystemUiOverlayStyle(
            statusBarColor: Colors.transparent,
            statusBarIconBrightness: Brightness.light,
            statusBarBrightness: Brightness.dark,
            systemStatusBarContrastEnforced: false,
            systemNavigationBarColor: Colors.transparent,
            systemNavigationBarIconBrightness: Brightness.light,
            systemNavigationBarContrastEnforced: false,
          ),
        ),
        textTheme: TextTheme(
          headlineLarge:
              AppTextStyles.h1.copyWith(color: AppColors.darkTextPrimary),
          headlineMedium:
              AppTextStyles.h2.copyWith(color: AppColors.darkTextPrimary),
          headlineSmall:
              AppTextStyles.h3.copyWith(color: AppColors.darkTextPrimary),
          titleLarge:
              AppTextStyles.h4.copyWith(color: AppColors.darkTextPrimary),
          bodyLarge: AppTextStyles.bodyLarge
              .copyWith(color: AppColors.darkTextPrimary),
          bodyMedium: AppTextStyles.bodyMedium
              .copyWith(color: AppColors.darkTextPrimary),
          bodySmall: AppTextStyles.bodySmall
              .copyWith(color: AppColors.darkTextSecondary),
          labelLarge:
              AppTextStyles.label.copyWith(color: AppColors.darkTextPrimary),
        ),
        inputDecorationTheme: InputDecorationTheme(
          filled: true,
          fillColor: AppColors.darkSurface,
          contentPadding:
              const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          hintStyle: AppTextStyles.bodyMedium.copyWith(
            color: AppColors.darkTextTertiary,
            fontWeight: FontWeight.w400,
          ),
          labelStyle: AppTextStyles.label.copyWith(color: AppColors.darkTextSecondary),
          border: OutlineInputBorder(
            borderRadius: AppRadius.inputRadius,
            borderSide: const BorderSide(color: AppColors.darkCardBorder),
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: AppRadius.inputRadius,
            borderSide: const BorderSide(color: AppColors.darkCardBorder),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: AppRadius.inputRadius,
            borderSide: const BorderSide(color: AppColors.primary, width: 1.5),
          ),
          errorBorder: OutlineInputBorder(
            borderRadius: AppRadius.inputRadius,
            borderSide: const BorderSide(color: AppColors.urgent),
          ),
          focusedErrorBorder: OutlineInputBorder(
            borderRadius: AppRadius.inputRadius,
            borderSide: const BorderSide(color: AppColors.urgent, width: 1.5),
          ),
        ),
        elevatedButtonTheme: ElevatedButtonThemeData(
          style: ElevatedButton.styleFrom(
            backgroundColor: AppColors.primary,
            foregroundColor: Colors.white,
            elevation: 0,
            padding: const EdgeInsets.symmetric(vertical: 16),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(50),
            ),
            textStyle: AppTextStyles.button,
          ),
        ),
        cardTheme: CardThemeData(
          color: AppColors.darkSurface,
          elevation: 0,
          shape: RoundedRectangleBorder(
            borderRadius: AppRadius.xlRadius,
            side: const BorderSide(color: AppColors.darkCardBorder),
          ),
        ),
        dialogTheme: DialogThemeData(
          backgroundColor: AppColors.darkSurface,
          surfaceTintColor: Colors.transparent,
          shape: RoundedRectangleBorder(borderRadius: AppRadius.lgRadius),
          titleTextStyle:
              AppTextStyles.h4.copyWith(color: AppColors.darkTextPrimary),
          contentTextStyle: AppTextStyles.bodyMedium
              .copyWith(color: AppColors.darkTextPrimary),
        ),
        bottomSheetTheme: const BottomSheetThemeData(
          backgroundColor: AppColors.darkSurface,
          surfaceTintColor: Colors.transparent,
          modalBackgroundColor: AppColors.darkSurface,
          elevation: 0,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
          ),
        ),
        popupMenuTheme: PopupMenuThemeData(
          color: AppColors.darkSurface,
          surfaceTintColor: Colors.transparent,
          textStyle: AppTextStyles.bodyMedium
              .copyWith(color: AppColors.darkTextPrimary),
          shape: RoundedRectangleBorder(borderRadius: AppRadius.mdRadius),
        ),
        listTileTheme: ListTileThemeData(
          textColor: AppColors.darkTextPrimary,
          iconColor: AppColors.darkTextSecondary,
          titleTextStyle: AppTextStyles.bodyMedium
              .copyWith(color: AppColors.darkTextPrimary),
          subtitleTextStyle: AppTextStyles.bodySmall
              .copyWith(color: AppColors.darkTextSecondary),
        ),
        dividerTheme: const DividerThemeData(
          color: AppColors.darkCardBorder,
          thickness: 1,
          space: 1,
        ),
      );
}

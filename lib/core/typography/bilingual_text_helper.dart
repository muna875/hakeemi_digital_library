import 'package:flutter/material.dart';

/// Bilingual Urdu/English detection, normalization, and typography helper.
class BilingualTextHelper {
  BilingualTextHelper._();

  static final RegExp _urduArabicRegex = RegExp(
    r'[؀-ۿݐ-ݿﭐ-﷿ﹰ-﻿]',
  );

  static final RegExp _latinRegex = RegExp(r'[A-Za-z]');

  static bool containsUrdu(String text) => _urduArabicRegex.hasMatch(text);

  static bool containsEnglish(String text) => _latinRegex.hasMatch(text);

  static bool isMixedLanguage(String text) =>
      containsUrdu(text) && containsEnglish(text);

  /// Determines natural paragraph direction when direction is set to 'auto'.
  static TextDirection resolveDirection(
    String text, {
    String explicitDirection = 'auto',
  }) {
    if (explicitDirection == 'rtl') return TextDirection.rtl;
    if (explicitDirection == 'ltr') return TextDirection.ltr;

    int urduCount = 0;
    int latinCount = 0;
    for (final rune in text.runes) {
      if ((rune >= 0x0600 && rune <= 0x06FF) ||
          (rune >= 0x0750 && rune <= 0x077F) ||
          (rune >= 0xFB50 && rune <= 0xFDFF) ||
          (rune >= 0xFE70 && rune <= 0xFEFF)) {
        urduCount++;
      } else if ((rune >= 0x41 && rune <= 0x5A) ||
          (rune >= 0x61 && rune <= 0x7A)) {
        latinCount++;
      }
    }
    return urduCount >= latinCount && urduCount > 0
        ? TextDirection.rtl
        : TextDirection.ltr;
  }

  /// Resolves optimal font family based on script and role.
  static String resolveFontFamily(
    String text, {
    bool isHeading = false,
    String explicitDirection = 'auto',
  }) {
    final isUrdu = explicitDirection == 'rtl' ||
        (explicitDirection == 'auto' && containsUrdu(text));
    if (isUrdu) {
      return 'NotoNastaliqUrdu';
    }
    return isHeading ? 'NotoSerif' : 'NotoSans';
  }

  /// Resolves comfortable line height; Nastaliq needs taller line height
  /// to preserve vertical ligatures and diacritics without clipping.
  static double resolveLineHeight(
    String text, {
    bool isHeading = false,
    String explicitDirection = 'auto',
  }) {
    final isUrdu = explicitDirection == 'rtl' ||
        (explicitDirection == 'auto' && containsUrdu(text));
    if (isUrdu) {
      return isHeading ? 1.85 : 2.05;
    }
    return isHeading ? 1.32 : 1.58;
  }

  /// Builds a Flutter TextStyle suited for Urdu, English, or mixed text.
  static TextStyle buildTextStyle({
    required String text,
    required double fontSize,
    required Color color,
    bool isHeading = false,
    bool isBold = false,
    bool isItalic = false,
    bool isUnderline = false,
    String explicitDirection = 'auto',
  }) {
    final family = resolveFontFamily(
      text,
      isHeading: isHeading,
      explicitDirection: explicitDirection,
    );
    final lineHeight = resolveLineHeight(
      text,
      isHeading: isHeading,
      explicitDirection: explicitDirection,
    );
    return TextStyle(
      fontFamily: family,
      fontFamilyFallback: const ['NotoNaskhArabic', 'NotoSans'],
      fontSize: fontSize,
      height: lineHeight,
      color: color,
      fontWeight: (isBold || isHeading) ? FontWeight.w700 : FontWeight.w400,
      fontStyle: isItalic ? FontStyle.italic : FontStyle.normal,
      decoration: isUnderline ? TextDecoration.underline : TextDecoration.none,
    );
  }

  /// Normalizes Urdu/Arabic variants for reliable offline search matching.
  /// Unifies Yeh (ی/ي/ے), Kaf (ک/ك), Heh (ہ/ه/ھ), Alef variants, and strips diacritics.
  static String normalizeForSearch(String input) {
    var s = input.trim().toLowerCase();
    // Strip Arabic/Urdu diacritical marks (Zabar, Zer, Pesh, Shadda, etc.)
    s = s.replaceAll(RegExp(r'[ً-ٰٟۖ-ۭ]'), '');
    // Normalize Arabic/Urdu letter variants
    s = s
        .replaceAll('ي', 'ی') // ي -> ی
        .replaceAll('ى', 'ی') // ى -> ی
        .replaceAll('ك', 'ک') // ك -> ک
        .replaceAll('ه', 'ہ') // ه -> ہ
        .replaceAll('ة', 'ہ') // ة -> ہ
        .replaceAll('آ', 'ا') // آ -> ا
        .replaceAll('أ', 'ا') // أ -> ا
        .replaceAll('إ', 'ا'); // إ -> ا
    return s;
  }
}

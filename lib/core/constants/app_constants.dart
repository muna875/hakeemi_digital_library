class AppConstants {
  AppConstants._();

  static const String appName = 'Hakeemi Digital Library';
  static const int permanentBookCount = 4;
  static const int databaseVersion = 1;
  static const String databaseFileName = 'hakeemi_digital_library.db';

  // A4-like editorial book page dimensions in logical points (1 pt = 1/72 in)
  static const double pageWidthPt = 595.28;
  static const double pageHeightPt = 841.89;
  static const double pageMarginHorizontalPt = 54.0;
  static const double pageMarginTopPt = 54.0;
  static const double pageMarginBottomPt = 54.0;
  static const double pageHeaderHeightPt = 28.0;
  static const double pageFooterHeightPt = 28.0;

  static double get printableWidthPt =>
      pageWidthPt - (pageMarginHorizontalPt * 2);
  static double get printableHeightPt =>
      pageHeightPt -
      pageMarginTopPt -
      pageMarginBottomPt -
      pageHeaderHeightPt -
      pageFooterHeightPt;
}

import 'dart:io';
import 'package:flutter/services.dart';
import 'package:pdf/widgets.dart' as pw;

class PdfFontBundle {
  final pw.Font serifRegular;
  final pw.Font serifBold;
  final pw.Font serifItalic;
  final pw.Font sansRegular;
  final pw.Font sansBold;
  final pw.Font urduRegular;
  final pw.Font urduBold;
  final pw.Font naskhFallback;

  const PdfFontBundle({
    required this.serifRegular,
    required this.serifBold,
    required this.serifItalic,
    required this.sansRegular,
    required this.sansBold,
    required this.urduRegular,
    required this.urduBold,
    required this.naskhFallback,
  });

  List<pw.Font> get urduFallbacks => [naskhFallback, sansRegular];
  List<pw.Font> get englishFallbacks => [urduRegular, naskhFallback];
}

class FontService {
  PdfFontBundle? _cached;

  /// Loads embedded offline fonts from Flutter assets (or local filesystem in unit tests).
  Future<PdfFontBundle> loadPdfFonts({String? localAssetsRoot}) async {
    if (_cached != null) return _cached!;

    Future<pw.Font> load(String assetPath) async {
      if (localAssetsRoot != null) {
        final file = File('$localAssetsRoot/$assetPath');
        final bytes = await file.readAsBytes();
        return pw.Font.ttf(bytes.buffer.asByteData());
      }
      final data = await rootBundle.load(assetPath);
      return pw.Font.ttf(data);
    }

    _cached = PdfFontBundle(
      serifRegular: await load('assets/fonts/NotoSerif-Regular.ttf'),
      serifBold: await load('assets/fonts/NotoSerif-Bold.ttf'),
      serifItalic: await load('assets/fonts/NotoSerif-Italic.ttf'),
      sansRegular: await load('assets/fonts/NotoSans-Regular.ttf'),
      sansBold: await load('assets/fonts/NotoSans-Bold.ttf'),
      urduRegular: await load('assets/fonts/NotoNastaliqUrdu-Regular.ttf'),
      urduBold: await load('assets/fonts/NotoNastaliqUrdu-Bold.ttf'),
      naskhFallback: await load('assets/fonts/NotoNaskhArabic-Regular.ttf'),
    );
    return _cached!;
  }
}

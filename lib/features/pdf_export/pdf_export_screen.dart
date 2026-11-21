import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:printing/printing.dart';
import 'package:provider/provider.dart';
import 'package:share_plus/share_plus.dart';

import '../../app/app_state.dart';
import '../../app/theme/app_colors.dart';
import '../../app/theme/app_spacing.dart';
import '../../services/pdf/pdf_export_service.dart';
import '../../shared/widgets/editorial_card.dart';

class PdfExportScreen extends StatefulWidget {
  final String bookId;

  const PdfExportScreen({super.key, required this.bookId});

  @override
  State<PdfExportScreen> createState() => _PdfExportScreenState();
}

class _PdfExportScreenState extends State<PdfExportScreen> {
  bool _includeCover = true;
  bool _includeTitlePage = true;
  bool _includeAuthorPage = true;
  bool _includeToc = true;
  bool _includeBackCover = true;
  Uint8List? _lastGeneratedBytes;
  String? _savedPath;
  bool _busy = false;

  PdfExportOptions _buildOptions(AppState state) => PdfExportOptions(
        includeFrontCover: _includeCover,
        includeTitlePage: _includeTitlePage,
        includeAuthorPage: _includeAuthorPage,
        includeTableOfContents: _includeToc,
        includeBackCover: _includeBackCover,
        showRunningHeaders: state.settings.showRunningHeaders,
        showPageNumbers: state.settings.showPageNumbers,
      );

  Future<Uint8List> _generateBytes(AppState state) async {
    final doc = state.paginatedForBook(widget.bookId)!;
    final res = await state.pdfExportService.buildBookPdf(
      document: doc,
      options: _buildOptions(state),
    );
    _lastGeneratedBytes = res.bytes;
    return res.bytes;
  }

  Future<void> _saveToDevice(AppState state) async {
    setState(() => _busy = true);
    try {
      final book = state.getBook(widget.bookId)!;
      final bytes = _lastGeneratedBytes ?? await _generateBytes(state);
      final file = await state.pdfExportService.savePdfToDevice(
        book: book,
        bytes: bytes,
      );
      setState(() => _savedPath = file.path);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('PDF saved to: ${file.path}')),
        );
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _sharePdf(AppState state) async {
    setState(() => _busy = true);
    try {
      final book = state.getBook(widget.bookId)!;
      final bytes = _lastGeneratedBytes ?? await _generateBytes(state);
      final file = await state.pdfExportService.savePdfToDevice(
        book: book,
        bytes: bytes,
      );
      await Share.shareXFiles([XFile(file.path)], text: book.title);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final state = context.watch<AppState>();
    final book = state.getBook(widget.bookId);
    final doc = state.paginatedForBook(widget.bookId);

    if (book == null || doc == null) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    return Scaffold(
      appBar: AppBar(
        title: Text('PDF Export • ${book.title}'),
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(AppSpacing.md),
            child: EditorialCard(
              padding: const EdgeInsets.all(AppSpacing.sm),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Publishing Options (${doc.totalPages} body pages synced with Reader)',
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 8,
                    runSpacing: 4,
                    children: [
                      FilterChip(
                        label: const Text('Front Cover'),
                        selected: _includeCover,
                        onSelected: (v) => setState(() => _includeCover = v),
                      ),
                      FilterChip(
                        label: const Text('Title Page'),
                        selected: _includeTitlePage,
                        onSelected: (v) => setState(() => _includeTitlePage = v),
                      ),
                      FilterChip(
                        label: const Text('Author Page'),
                        selected: _includeAuthorPage,
                        onSelected: (v) =>
                            setState(() => _includeAuthorPage = v),
                      ),
                      FilterChip(
                        label: const Text('Auto TOC'),
                        selected: _includeToc,
                        onSelected: (v) => setState(() => _includeToc = v),
                      ),
                      FilterChip(
                        label: const Text('Back Cover'),
                        selected: _includeBackCover,
                        onSelected: (v) => setState(() => _includeBackCover = v),
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),
                  Row(
                    children: [
                      Expanded(
                        child: ElevatedButton.icon(
                          onPressed: _busy ? null : () => _saveToDevice(state),
                          icon: const Icon(Icons.save_alt, size: 18),
                          label: const Text('Save PDF'),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: OutlinedButton.icon(
                          onPressed: _busy ? null : () => _sharePdf(state),
                          icon: const Icon(Icons.share_outlined, size: 18),
                          label: const Text('Share PDF'),
                        ),
                      ),
                    ],
                  ),
                  if (_savedPath != null) ...[
                    const SizedBox(height: 6),
                    Text(
                      'Saved: $_savedPath',
                      style: const TextStyle(
                        fontSize: 11,
                        color: AppColors.primaryForestGreen,
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ),
          Expanded(
            child: PdfPreview(
              canChangeOrientation: false,
              canChangePageFormat: false,
              canDebug: false,
              allowPrinting: true,
              allowSharing: true,
              build: (_) => _generateBytes(state),
            ),
          ),
        ],
      ),
    );
  }
}

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:provider/provider.dart';

import '../../app/app_state.dart';
import '../../app/theme/app_colors.dart';
import '../../app/theme/app_spacing.dart';
import '../../models/book/book_model.dart';
import '../../shared/widgets/book_cover_widget.dart';
import '../../shared/widgets/editorial_card.dart';

class CoverDesignerScreen extends StatefulWidget {
  final String bookId;

  const CoverDesignerScreen({super.key, required this.bookId});

  @override
  State<CoverDesignerScreen> createState() => _CoverDesignerScreenState();
}

class _CoverDesignerScreenState extends State<CoverDesignerScreen> {
  late TextEditingController _titleCtrl;
  late TextEditingController _subtitleCtrl;
  late TextEditingController _authorCtrl;
  late TextEditingController _pubCtrl;
  late CoverTemplate _template;
  String? _customImagePath;
  bool _loaded = false;

  void _initFromBook(BookModel book) {
    if (_loaded) return;
    _titleCtrl = TextEditingController(text: book.title);
    _subtitleCtrl = TextEditingController(text: book.subtitle);
    _authorCtrl = TextEditingController(text: book.authorName);
    _pubCtrl = TextEditingController(text: book.publicationInfo);
    _template = book.coverTemplate;
    _customImagePath = book.customCoverImagePath;
    _loaded = true;
  }

  @override
  void dispose() {
    if (_loaded) {
      _titleCtrl.dispose();
      _subtitleCtrl.dispose();
      _authorCtrl.dispose();
      _pubCtrl.dispose();
    }
    super.dispose();
  }

  Future<void> _pickCoverImage(AppState state) async {
    final picker = ImagePicker();
    final picked = await picker.pickImage(source: ImageSource.gallery);
    if (picked == null) return;
    final stored = await state.imageStorage.persistImageFile(picked.path);
    setState(() {
      _customImagePath = stored;
      _template = CoverTemplate.customImage;
    });
  }

  @override
  Widget build(BuildContext context) {
    final state = context.watch<AppState>();
    final book = state.getBook(widget.bookId);
    if (book == null) {
      return const Scaffold(body: Center(child: Text('Book not found.')));
    }
    _initFromBook(book);

    final previewBook = book.copyWith(
      title: _titleCtrl.text,
      subtitle: _subtitleCtrl.text,
      authorName: _authorCtrl.text,
      publicationInfo: _pubCtrl.text,
      coverTemplate: _template,
      customCoverImagePath: _customImagePath,
    );

    return Scaffold(
      appBar: AppBar(
        title: const Text('Book Cover Designer'),
        actions: [
          TextButton(
            onPressed: () async {
              await state.updateBook(previewBook);
              if (context.mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text(
                      'Cover saved. This cover will appear as Page 1 of your exported PDF.',
                    ),
                  ),
                );
                Navigator.pop(context);
              }
            },
            child: const Text('Save Cover'),
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(AppSpacing.md),
        children: [
          // Live Cover Preview (A4-proportioned)
          Center(
            child: BookCoverWidget(
              book: previewBook,
              width: 210,
              height: 297,
            ),
          ),
          const SizedBox(height: AppSpacing.lg),
          EditorialCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Cover Template',
                  style: Theme.of(context).textTheme.titleMedium,
                ),
                const SizedBox(height: 10),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: CoverTemplate.values.map((t) {
                    return ChoiceChip(
                      label: Text(t.displayName),
                      selected: _template == t,
                      selectedColor: AppColors.sageTint,
                      onSelected: (_) => setState(() => _template = t),
                    );
                  }).toList(),
                ),
                const SizedBox(height: 12),
                OutlinedButton.icon(
                  onPressed: () => _pickCoverImage(state),
                  icon: const Icon(Icons.upload_file_outlined),
                  label: const Text('Upload Custom Cover Image'),
                ),
              ],
            ),
          ),
          const SizedBox(height: AppSpacing.md),
          EditorialCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Cover Typography & Metadata',
                  style: Theme.of(context).textTheme.titleMedium,
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: _titleCtrl,
                  onChanged: (_) => setState(() {}),
                  decoration: const InputDecoration(labelText: 'Book Title'),
                ),
                const SizedBox(height: 10),
                TextField(
                  controller: _subtitleCtrl,
                  onChanged: (_) => setState(() {}),
                  decoration: const InputDecoration(labelText: 'Subtitle'),
                ),
                const SizedBox(height: 10),
                TextField(
                  controller: _authorCtrl,
                  onChanged: (_) => setState(() {}),
                  decoration: const InputDecoration(labelText: 'Author Name'),
                ),
                const SizedBox(height: 10),
                TextField(
                  controller: _pubCtrl,
                  onChanged: (_) => setState(() {}),
                  decoration: const InputDecoration(
                    labelText: 'Publication Information',
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

import '../../models/book/book_model.dart';

/// Exactly four permanent book slots created on first launch.
/// Never pre-populated with invented medical formulations.
class DefaultBooks {
  DefaultBooks._();

  static const String book1Id = 'book_01_hakeemi_nuskhe';
  static const String book2Id = 'book_02_mufradat_o_advia';
  static const String book3Id = 'book_03_murakkabat';
  static const String book4Id = 'book_04_tibbi_maloomat';

  static List<BookModel> createInitialBooks(DateTime now) {
    return [
      BookModel(
        id: book1Id,
        slotOrder: 1,
        title: 'Hakeemi Nuskhe',
        subtitle: 'Traditional Herbal Formulations',
        authorName: '',
        description:
            'Personal compendium of traditional Hakeemi formulations, preparations, and clinical observations.',
        publicationInfo: 'Personal Manuscript Edition',
        coverTemplate: CoverTemplate.botanicalForest,
        coverAccentHex: '#174C3C',
        createdAt: now,
        updatedAt: now,
      ),
      BookModel(
        id: book2Id,
        slotOrder: 2,
        title: 'Mufradat-o-Advia',
        subtitle: 'Medicinal Plants and Substances',
        authorName: '',
        description:
            'Reference volume on single medicinal herbs, temperaments (Mizaj), botanical properties, and natural substances.',
        publicationInfo: 'Personal Manuscript Edition',
        coverTemplate: CoverTemplate.botanicalSage,
        coverAccentHex: '#103B30',
        createdAt: now,
        updatedAt: now,
      ),
      BookModel(
        id: book3Id,
        slotOrder: 3,
        title: 'Murakkabat',
        subtitle: 'Compound Formulations',
        authorName: '',
        description:
            'Structured record of compound herbal preparations, Majoon, Sharbat, Safoof, and multi-ingredient formulations.',
        publicationInfo: 'Personal Manuscript Edition',
        coverTemplate: CoverTemplate.academicGold,
        coverAccentHex: '#174C3C',
        createdAt: now,
        updatedAt: now,
      ),
      BookModel(
        id: book4Id,
        slotOrder: 4,
        title: 'Tibbi Maloomat',
        subtitle: 'General Medical Knowledge',
        authorName: '',
        description:
            'Medical reference notes, diagnostic principles, dietary guidance, and bilingual educational monographs.',
        publicationInfo: 'Personal Manuscript Edition',
        coverTemplate: CoverTemplate.minimalistIvory,
        coverAccentHex: '#174C3C',
        createdAt: now,
        updatedAt: now,
      ),
    ];
  }
}

import 'dart:io';
import 'package:flutter/material.dart';
import '../../app/theme/app_colors.dart';
import '../../app/theme/app_spacing.dart';
import '../../core/typography/bilingual_text_helper.dart';
import '../../models/book/book_model.dart';

/// Realistic editorial book cover widget supporting all 5 templates
/// (Botanical Forest, Botanical Sage, Academic Reference, Minimalist Ivory, Custom Image).
class BookCoverWidget extends StatelessWidget {
  final BookModel book;
  final double width;
  final double height;
  final bool compact;

  const BookCoverWidget({
    super.key,
    required this.book,
    this.width = 110,
    this.height = 156,
    this.compact = false,
  });

  Color _backgroundColor() {
    switch (book.coverTemplate) {
      case CoverTemplate.botanicalForest:
        return AppColors.primaryForestGreen;
      case CoverTemplate.botanicalSage:
        return AppColors.deepGreen;
      case CoverTemplate.academicGold:
        return const Color(0xFF1A3A32);
      case CoverTemplate.minimalistIvory:
        return AppColors.warmIvory;
      case CoverTemplate.customImage:
        return AppColors.primaryForestGreen;
    }
  }

  @override
  Widget build(BuildContext context) {
    final isIvory = book.coverTemplate == CoverTemplate.minimalistIvory;
    final fg = isIvory ? AppColors.primaryForestGreen : AppColors.paperWhite;
    final subFg =
        isIvory ? AppColors.secondaryText : AppColors.warmIvory.withOpacity(0.85);
    final hasCustomImage = book.coverTemplate == CoverTemplate.customImage &&
        book.customCoverImagePath != null &&
        File(book.customCoverImagePath!).existsSync();

    return Container(
      width: width,
      height: height,
      decoration: BoxDecoration(
        color: _backgroundColor(),
        borderRadius: BorderRadius.circular(AppSpacing.bookCoverRadius),
        border: Border.all(
          color: isIvory ? AppColors.border : AppColors.mutedGold.withOpacity(0.6),
          width: 1.2,
        ),
        boxShadow: [
          BoxShadow(
            color: AppColors.mainText.withOpacity(0.14),
            blurRadius: 10,
            offset: const Offset(2, 4),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(AppSpacing.bookCoverRadius - 1),
        child: Stack(
          fit: StackFit.expand,
          children: [
            if (hasCustomImage)
              Image.file(
                File(book.customCoverImagePath!),
                fit: BoxFit.cover,
              ),
            if (hasCustomImage)
              Container(color: AppColors.deepGreen.withOpacity(0.48)),
            // Book spine crease
            Positioned(
              left: 0,
              top: 0,
              bottom: 0,
              width: compact ? 6 : 10,
              child: Container(
                color: Colors.black.withOpacity(isIvory ? 0.06 : 0.22),
              ),
            ),
            // Inner gold/editorial frame
            Padding(
              padding: EdgeInsets.all(compact ? 7 : 14),
              child: Container(
                decoration: BoxDecoration(
                  border: Border.all(
                    color: AppColors.mutedGold.withOpacity(isIvory ? 0.7 : 0.65),
                    width: compact ? 0.8 : 1.2,
                  ),
                  borderRadius: BorderRadius.circular(4),
                ),
                padding: EdgeInsets.symmetric(
                  horizontal: compact ? 6 : 12,
                  vertical: compact ? 8 : 14,
                ),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    Text(
                      'VOL. 0${book.slotOrder}',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontFamily: 'NotoSans',
                        fontSize: compact ? 8 : 10,
                        letterSpacing: 1.5,
                        fontWeight: FontWeight.w700,
                        color: AppColors.mutedGold,
                      ),
                    ),
                    Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        if (book.coverTemplate == CoverTemplate.botanicalForest ||
                            book.coverTemplate == CoverTemplate.botanicalSage)
                          Padding(
                            padding: EdgeInsets.only(bottom: compact ? 4 : 8),
                            child: Icon(
                              Icons.eco_outlined,
                              size: compact ? 16 : 24,
                              color: AppColors.mutedGold,
                            ),
                          ),
                        Text(
                          book.title,
                          textAlign: TextAlign.center,
                          maxLines: compact ? 2 : 3,
                          overflow: TextOverflow.ellipsis,
                          textDirection:
                              BilingualTextHelper.resolveDirection(book.title),
                          style: BilingualTextHelper.buildTextStyle(
                            text: book.title,
                            fontSize: compact ? 11 : 17,
                            color: fg,
                            isHeading: true,
                          ),
                        ),
                        SizedBox(height: compact ? 4 : 8),
                        Container(
                          width: compact ? 24 : 44,
                          height: 1.2,
                          color: AppColors.mutedGold,
                        ),
                        if (!compact) ...[
                          const SizedBox(height: 8),
                          Text(
                            book.subtitle,
                            textAlign: TextAlign.center,
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              fontFamily: 'NotoSerif',
                              fontStyle: FontStyle.italic,
                              fontSize: 11,
                              color: subFg,
                            ),
                          ),
                        ],
                      ],
                    ),
                    Text(
                      book.authorName.trim().isEmpty
                          ? 'Hakeemi Library'
                          : book.authorName,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontFamily: 'NotoSans',
                        fontSize: compact ? 7.5 : 10,
                        color: subFg,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

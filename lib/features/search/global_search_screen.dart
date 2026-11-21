import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../app/app_state.dart';
import '../../app/router.dart';
import '../../app/theme/app_colors.dart';
import '../../app/theme/app_spacing.dart';
import '../../core/typography/bilingual_text_helper.dart';
import '../../services/search/search_service.dart';
import '../../shared/widgets/editorial_card.dart';
import '../../shared/widgets/empty_state_widget.dart';

class GlobalSearchScreen extends StatefulWidget {
  final String? initialBookIdFilter;

  const GlobalSearchScreen({super.key, this.initialBookIdFilter});

  @override
  State<GlobalSearchScreen> createState() => _GlobalSearchScreenState();
}

class _GlobalSearchScreenState extends State<GlobalSearchScreen> {
  final TextEditingController _queryController = TextEditingController();
  String? _bookFilter;
  List<SearchResultItem> _results = const [];
  bool _searching = false;

  @override
  void initState() {
    super.initState();
    _bookFilter = widget.initialBookIdFilter;
  }

  @override
  void dispose() {
    _queryController.dispose();
    super.dispose();
  }

  Future<void> _runSearch(String q) async {
    if (q.trim().isEmpty) {
      setState(() => _results = const []);
      return;
    }
    setState(() => _searching = true);
    final res = await context
        .read<AppState>()
        .search(q, bookIdFilter: _bookFilter);
    if (mounted) {
      setState(() {
        _results = res;
        _searching = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final state = context.watch<AppState>();
    final books = state.books;

    return Scaffold(
      appBar: AppBar(
        title: Text(
          _bookFilter == null
              ? 'Global Offline Search'
              : 'Search • ${state.getBook(_bookFilter!)?.title ?? ''}',
        ),
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(AppSpacing.md),
            child: Column(
              children: [
                TextField(
                  controller: _queryController,
                  textInputAction: TextInputAction.search,
                  onChanged: _runSearch,
                  onSubmitted: _runSearch,
                  decoration: InputDecoration(
                    prefixIcon: const Icon(Icons.search),
                    hintText:
                        'Search Urdu (اردو), English, Nuskha, ingredient, or page…',
                    suffixIcon: _queryController.text.isNotEmpty
                        ? IconButton(
                            icon: const Icon(Icons.clear),
                            onPressed: () {
                              _queryController.clear();
                              setState(() => _results = const []);
                            },
                          )
                        : null,
                  ),
                ),
                const SizedBox(height: 10),
                SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: Row(
                    children: [
                      FilterChip(
                        label: const Text('All 4 Books'),
                        selected: _bookFilter == null,
                        onSelected: (_) {
                          setState(() => _bookFilter = null);
                          _runSearch(_queryController.text);
                        },
                      ),
                      const SizedBox(width: 6),
                      for (final b in books) ...[
                        FilterChip(
                          label: Text(b.title),
                          selected: _bookFilter == b.id,
                          onSelected: (_) {
                            setState(() => _bookFilter = b.id);
                            _runSearch(_queryController.text);
                          },
                        ),
                        const SizedBox(width: 6),
                      ],
                    ],
                  ),
                ),
              ],
            ),
          ),
          if (_searching) const LinearProgressIndicator(),
          Expanded(
            child: _queryController.text.trim().isEmpty
                ? const EmptyStateWidget(
                    icon: Icons.manage_search,
                    title: 'Search Across All Four Books',
                    subtitle:
                        'Find Urdu words, English terms, Nuskha names, ingredients, chapters, sections, or jump directly by page number.',
                  )
                : _results.isEmpty
                    ? const EmptyStateWidget(
                        icon: Icons.search_off,
                        title: 'No Matching Records Found',
                        subtitle:
                            'Try another Urdu or English keyword, ingredient name, or page number.',
                      )
                    : ListView.separated(
                        padding: const EdgeInsets.fromLTRB(
                          AppSpacing.md,
                          0,
                          AppSpacing.md,
                          AppSpacing.md,
                        ),
                        itemCount: _results.length,
                        separatorBuilder: (_, __) => const SizedBox(height: 8),
                        itemBuilder: (context, i) {
                          final item = _results[i];
                          return EditorialCard(
                            onTap: () {
                              if (item.entityType == 'nuskha') {
                                Navigator.pushNamed(
                                  context,
                                  AppRoutes.nuskhaManager,
                                );
                              } else {
                                Navigator.pushNamed(
                                  context,
                                  AppRoutes.reader,
                                  arguments: ReaderArgs(
                                    bookId: item.bookId,
                                    initialPage: item.pageNumber,
                                  ),
                                );
                              }
                            },
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  children: [
                                    Container(
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: 8,
                                        vertical: 3,
                                      ),
                                      decoration: BoxDecoration(
                                        color: AppColors.sageTint,
                                        borderRadius: BorderRadius.circular(6),
                                      ),
                                      child: Text(
                                        item.bookTitle,
                                        style: const TextStyle(
                                          fontSize: 11,
                                          fontWeight: FontWeight.w700,
                                          color: AppColors.primaryForestGreen,
                                        ),
                                      ),
                                    ),
                                    const SizedBox(width: 8),
                                    Expanded(
                                      child: Text(
                                        item.chapterTitle,
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                        style: const TextStyle(
                                          fontSize: 12,
                                          fontWeight: FontWeight.w600,
                                          color: AppColors.secondaryText,
                                        ),
                                      ),
                                    ),
                                    Text(
                                      'Page ${item.pageNumber}',
                                      style: const TextStyle(
                                        fontFamily: 'NotoSerif',
                                        fontWeight: FontWeight.w700,
                                        fontSize: 12,
                                        color: AppColors.primaryForestGreen,
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 8),
                                Directionality(
                                  textDirection:
                                      BilingualTextHelper.resolveDirection(
                                    item.snippet,
                                  ),
                                  child: Text(
                                    item.snippet,
                                    maxLines: 3,
                                    overflow: TextOverflow.ellipsis,
                                    style: BilingualTextHelper.buildTextStyle(
                                      text: item.snippet,
                                      fontSize: 13.5,
                                      color: AppColors.mainText,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          );
                        },
                      ),
          ),
        ],
      ),
    );
  }
}

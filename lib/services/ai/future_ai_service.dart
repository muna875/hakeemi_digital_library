/// Optional future AI service abstraction.
/// Core features (pagination, TOC, search, PDF export, persistence) NEVER depend on AI,
/// and original medical formulations are NEVER modified without explicit user approval.
class AiSuggestion {
  final String category;
  final String suggestionText;
  final bool requiresExplicitApproval;

  const AiSuggestion({
    required this.category,
    required this.suggestionText,
    this.requiresExplicitApproval = true,
  });
}

abstract class FutureAiService {
  bool get isEnabled;

  Future<List<AiSuggestion>> suggestHeadings(String rawText);
  Future<List<AiSuggestion>> suggestCategorization(String rawText);
  Future<List<AiSuggestion>> suggestChapterPlacement(String rawText);
  Future<List<AiSuggestion>> suggestSpellingCorrections(String rawText);
}

/// Default offline implementation: strictly inactive so the app works 100% offline.
class OfflineDisabledAiService implements FutureAiService {
  const OfflineDisabledAiService();

  @override
  bool get isEnabled => false;

  @override
  Future<List<AiSuggestion>> suggestHeadings(String rawText) async => const [];

  @override
  Future<List<AiSuggestion>> suggestCategorization(String rawText) async =>
      const [];

  @override
  Future<List<AiSuggestion>> suggestChapterPlacement(String rawText) async =>
      const [];

  @override
  Future<List<AiSuggestion>> suggestSpellingCorrections(String rawText) async =>
      const [];
}

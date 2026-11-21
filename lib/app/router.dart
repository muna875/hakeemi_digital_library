import 'package:flutter/material.dart';

import '../features/backup/backup_restore_screen.dart';
import '../features/book_details/book_details_screen.dart';
import '../features/chapter_manager/chapter_manager_screen.dart';
import '../features/contents/table_of_contents_screen.dart';
import '../features/cover_designer/cover_designer_screen.dart';
import '../features/editor/book_editor_screen.dart';
import '../features/library/library_screen.dart';
import '../features/nuskha_manager/nuskha_manager_screen.dart';
import '../features/page_manager/page_manager_screen.dart';
import '../features/pdf_export/pdf_export_screen.dart';
import '../features/reader/book_reader_screen.dart';
import '../features/search/global_search_screen.dart';
import '../features/settings/settings_screen.dart';

class AppRoutes {
  AppRoutes._();

  static const String home = '/';
  static const String bookDetails = '/book-details';
  static const String reader = '/reader';
  static const String editor = '/editor';
  static const String tableOfContents = '/table-of-contents';
  static const String chapterManager = '/chapter-manager';
  static const String pageManager = '/page-manager';
  static const String search = '/search';
  static const String nuskhaManager = '/nuskha-manager';
  static const String coverDesigner = '/cover-designer';
  static const String pdfExport = '/pdf-export';
  static const String backupRestore = '/backup-restore';
  static const String settings = '/settings';
}

class ReaderArgs {
  final String bookId;
  final int initialPage;

  const ReaderArgs({required this.bookId, this.initialPage = 1});
}

class EditorArgs {
  final String bookId;
  final String? initialChapterId;

  const EditorArgs({required this.bookId, this.initialChapterId});
}

class AppRouter {
  static Route<dynamic> onGenerateRoute(RouteSettings routeSettings) {
    switch (routeSettings.name) {
      case AppRoutes.home:
        return MaterialPageRoute(builder: (_) => const MainShellScreen());
      case AppRoutes.bookDetails:
        final bookId = routeSettings.arguments as String;
        return MaterialPageRoute(
          builder: (_) => BookDetailsScreen(bookId: bookId),
        );
      case AppRoutes.reader:
        final args = routeSettings.arguments as ReaderArgs;
        return MaterialPageRoute(
          builder: (_) => BookReaderScreen(
            bookId: args.bookId,
            initialPage: args.initialPage,
          ),
        );
      case AppRoutes.editor:
        final args = routeSettings.arguments as EditorArgs;
        return MaterialPageRoute(
          builder: (_) => BookEditorScreen(
            bookId: args.bookId,
            initialChapterId: args.initialChapterId,
          ),
        );
      case AppRoutes.tableOfContents:
        final bookId = routeSettings.arguments as String;
        return MaterialPageRoute(
          builder: (_) => TableOfContentsScreen(bookId: bookId),
        );
      case AppRoutes.chapterManager:
        final bookId = routeSettings.arguments as String;
        return MaterialPageRoute(
          builder: (_) => ChapterManagerScreen(bookId: bookId),
        );
      case AppRoutes.pageManager:
        final bookId = routeSettings.arguments as String;
        return MaterialPageRoute(
          builder: (_) => PageManagerScreen(bookId: bookId),
        );
      case AppRoutes.search:
        final bookIdFilter = routeSettings.arguments as String?;
        return MaterialPageRoute(
          builder: (_) => GlobalSearchScreen(
            initialBookIdFilter: bookIdFilter,
          ),
        );
      case AppRoutes.nuskhaManager:
        return MaterialPageRoute(builder: (_) => const NuskhaManagerScreen());
      case AppRoutes.coverDesigner:
        final bookId = routeSettings.arguments as String;
        return MaterialPageRoute(
          builder: (_) => CoverDesignerScreen(bookId: bookId),
        );
      case AppRoutes.pdfExport:
        final bookId = routeSettings.arguments as String;
        return MaterialPageRoute(
          builder: (_) => PdfExportScreen(bookId: bookId),
        );
      case AppRoutes.backupRestore:
        return MaterialPageRoute(builder: (_) => const BackupRestoreScreen());
      case AppRoutes.settings:
        return MaterialPageRoute(builder: (_) => const SettingsScreen());
      default:
        return MaterialPageRoute(builder: (_) => const MainShellScreen());
    }
  }
}

/// Primary bottom-navigation shell connecting Library, Search, Nuskhas, Backup, and Settings.
class MainShellScreen extends StatefulWidget {
  const MainShellScreen({super.key});

  @override
  State<MainShellScreen> createState() => _MainShellScreenState();
}

class _MainShellScreenState extends State<MainShellScreen> {
  int _tabIndex = 0;

  void _selectTab(int idx) => setState(() => _tabIndex = idx);

  @override
  Widget build(BuildContext context) {
    final screens = [
      LibraryScreen(onSelectTab: _selectTab),
      const GlobalSearchScreen(),
      const NuskhaManagerScreen(),
      const BackupRestoreScreen(),
      const SettingsScreen(),
    ];

    return Scaffold(
      body: IndexedStack(index: _tabIndex, children: screens),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _tabIndex,
        onDestinationSelected: _selectTab,
        destinations: const [
          NavigationDestination(
            icon: Icon(Icons.menu_book_outlined),
            selectedIcon: Icon(Icons.menu_book),
            label: 'Library',
          ),
          NavigationDestination(
            icon: Icon(Icons.search),
            label: 'Search',
          ),
          NavigationDestination(
            icon: Icon(Icons.medication_liquid_outlined),
            selectedIcon: Icon(Icons.medication_liquid),
            label: 'Nuskhas',
          ),
          NavigationDestination(
            icon: Icon(Icons.backup_outlined),
            selectedIcon: Icon(Icons.backup),
            label: 'Backup',
          ),
          NavigationDestination(
            icon: Icon(Icons.settings_outlined),
            selectedIcon: Icon(Icons.settings),
            label: 'Settings',
          ),
        ],
      ),
    );
  }
}

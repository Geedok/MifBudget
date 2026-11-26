import 'package:material_ui/material_ui.dart';

import 'models/settings.dart';
import 'state/budget_store.dart';
import 'theme.dart';
import 'ui/home_shell.dart';
import 'ui/setup_screen.dart';

class MifBudgetApp extends StatelessWidget {
  const MifBudgetApp({super.key, required this.store});

  final BudgetStore store;

  @override
  Widget build(BuildContext context) => StoreScope(
    store: store,
    child: ListenableBuilder(
      listenable: store,
      builder: (context, _) => MaterialApp(
        title: 'MifBudget',
        debugShowCheckedModeBanner: false,
        locale: const Locale('fr', 'FR'),
        supportedLocales: const [Locale('fr', 'FR')],
        localizationsDelegates: GlobalMaterialLocalizations.delegates,
        theme: buildTheme(Brightness.light),
        darkTheme: buildTheme(Brightness.dark),
        themeMode: switch (store.settings.theme) {
          ThemeChoice.system => ThemeMode.system,
          ThemeChoice.light => ThemeMode.light,
          ThemeChoice.dark => ThemeMode.dark,
        },
        home: store.settings.setupDone
            ? const HomeShell()
            : const SetupScreen(),
      ),
    ),
  );
}

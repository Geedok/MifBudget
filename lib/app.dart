import 'package:material_ui/material_ui.dart';

import 'models/settings.dart';
import 'state/budget_store.dart';
import 'sync/app_controller.dart';
import 'theme.dart';
import 'ui/home_shell.dart';
import 'ui/lock.dart';
import 'ui/setup_screen.dart';

class MifBudgetApp extends StatelessWidget {
  /// Avec un [store] seul (tests), ou un [controller] qui peut passer du
  /// stockage local au foyer partagé.
  const MifBudgetApp({super.key, this.store, this.controller})
    : assert(store != null || controller != null);

  final BudgetStore? store;
  final AppController? controller;

  @override
  Widget build(BuildContext context) {
    final c = controller;
    if (c == null) return _app(store!);
    return AppScope(
      controller: c,
      child: ListenableBuilder(
        listenable: c,
        builder: (context, _) => _app(c.store),
      ),
    );
  }

  Widget _app(BudgetStore store) => StoreScope(
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
        // Le code de verrouillage recouvre toute l'application.
        builder: (context, child) => LockGate(child: child!),
        home: store.settings.setupDone
            ? const HomeShell()
            : const SetupScreen(),
      ),
    ),
  );
}

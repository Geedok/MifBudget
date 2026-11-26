import 'dart:io';

import 'package:intl/date_symbol_data_local.dart';
import 'package:material_ui/material_ui.dart';
import 'package:path_provider/path_provider.dart';

import 'app.dart';
import 'data/repository.dart';
import 'state/budget_store.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await initializeDateFormatting('fr_FR');
  final dir = await getApplicationDocumentsDirectory();
  final repo = LocalJsonRepository(File('${dir.path}/mifbudget.json'));
  final store = await BudgetStore.open(repo);
  runApp(MifBudgetApp(store: store));
}

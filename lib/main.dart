import 'dart:io';

import 'package:firebase_core/firebase_core.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:material_ui/material_ui.dart';
import 'package:path_provider/path_provider.dart';

import 'app.dart';
import 'sync/app_controller.dart';
import 'sync/household_service.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await initializeDateFormatting('fr_FR');
  // Configuration lue dans android/app/google-services.json.
  await Firebase.initializeApp();
  final dir = await getApplicationDocumentsDirectory();
  final controller = await AppController.open(
    File('${dir.path}/mifbudget.json'),
    HouseholdService(),
  );
  runApp(MifBudgetApp(controller: controller, showIntro: true));
}

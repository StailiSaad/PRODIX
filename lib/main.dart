import 'package:flutter/widgets.dart';

import 'app_root.dart';
import 'core/config/app_config.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await bootstrapProdix(const AppConfig.fromEnvironment());
}

import "package:flutter/cupertino.dart";
import "package:flutter_riverpod/flutter_riverpod.dart";
import "package:supabase_flutter/supabase_flutter.dart";

import "app.dart";

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Supabase.initialize(
    url: "https://yeufnwiuqlukftfxcest.supabase.co",
    publishableKey: "sb_publishable_0X0g3iZPYzyViV2hKM9uaQ_RXST6ihd",
  );
  runApp(const ProviderScope(child: MyApp()));
}

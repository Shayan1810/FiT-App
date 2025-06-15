
import 'package:flutter/material.dart';
import 'pages/home.dart';
import 'services/hive_service.dart';

Future main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await HiveService.initHive();
  runApp(MyApp());
}

class MyApp extends StatelessWidget {
@override
Widget build(BuildContext context) {
return MaterialApp(
debugShowCheckedModeBanner: false,
home: HomePage(),
);
}
} 
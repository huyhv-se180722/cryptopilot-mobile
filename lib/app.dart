import 'package:flutter/material.dart';

/// Root widget. Routing, theme and copy arrive with T-088.
class CryptoPilotApp extends StatelessWidget {
  const CryptoPilotApp({super.key});

  @override
  Widget build(BuildContext context) {
    return const MaterialApp(
      title: 'CryptoPilot',
      debugShowCheckedModeBanner: false,
      home: Scaffold(body: Center(child: Text('CryptoPilot'))),
    );
  }
}

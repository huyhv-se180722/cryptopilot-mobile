import 'package:flutter/material.dart';

/// The owner-supplied logo (the web's `assets/brand`); the dark variant reads on
/// dark surfaces.
class BrandLogo extends StatelessWidget {
  const BrandLogo({this.height = 32, this.markOnly = false, super.key});

  final double height;
  final bool markOnly;

  @override
  Widget build(BuildContext context) {
    final dark = Theme.of(context).brightness == Brightness.dark;
    final name = markOnly ? 'mark' : 'logo';
    return Image.asset(
      'assets/brand/$name-${dark ? 'dark' : 'light'}.png',
      height: height,
      semanticLabel: 'CryptoPilot',
    );
  }
}

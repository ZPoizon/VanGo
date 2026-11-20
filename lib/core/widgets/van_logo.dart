import 'package:flutter/material.dart';

class VanLogo extends StatelessWidget {
  const VanLogo({
    super.key,
    this.size = 44,
    this.usarLogoCompleta = false,
  });

  final double size;
  final bool usarLogoCompleta;

  @override
  Widget build(BuildContext context) {
    if (usarLogoCompleta) {
      return Image.asset(
        'assets/images/vango_logo.png',
        width: size * 2.5,
        height: size,
        fit: BoxFit.contain,
      );
    }

    return Image.asset(
      'assets/images/vango_simbolo.png',
      width: size,
      height: size,
      fit: BoxFit.contain,
    );
  }
}

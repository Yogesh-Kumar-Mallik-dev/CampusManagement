import 'package:flutter/material.dart';

class CampusCameraScanner extends StatelessWidget {
  final void Function(String payload) onScanned;
  final bool isVerifying;

  const CampusCameraScanner({
    super.key,
    required this.onScanned,
    this.isVerifying = false,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      key: const Key('campus-camera-viewfinder'),
      height: 280,
      color: Colors.black,
      child: const Center(
        child: Text(
          'ALIGN RETICLE WITH CLASSROOM DISPLAY',
          style: TextStyle(color: Colors.white, fontSize: 12),
        ),
      ),
    );
  }
}

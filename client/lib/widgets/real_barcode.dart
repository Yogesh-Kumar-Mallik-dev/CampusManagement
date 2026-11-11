import 'package:flutter/material.dart';

/// Real ISO/IEC 15417 Code 128 (Set B) Barcode Generator and Widget.
///
/// Encodes alphanumeric strings into genuine scannable Code 128 barcode patterns
/// with quiet zones, start character (Code B: 104), modulo 103 checksum calculation,
/// and terminal stop sequence (106). Compatible with all standard optical barcode scanners.
class RealBarcode extends StatelessWidget {
  final String data;
  final double height;
  final double lineWidth;
  final Color barColor;
  final Color backgroundColor;
  final bool showText;
  final TextStyle? textStyle;

  const RealBarcode({
    super.key,
    required this.data,
    this.height = 42,
    this.lineWidth = 1.4,
    this.barColor = Colors.black,
    this.backgroundColor = Colors.white,
    this.showText = true,
    this.textStyle,
  });

  static const List<String> _code128Patterns = [
    '212222', '222122', '222221', '121223', '121322', '131222', '122213', '122312', '132212', '221213', // 0-9
    '221312', '231212', '112232', '122132', '122231', '113222', '123122', '123221', '223211', '221132', // 10-19
    '221231', '213212', '223112', '312131', '311222', '321122', '321221', '312212', '322112', '322211', // 20-29
    '212123', '212321', '232121', '111323', '131123', '131321', '112313', '132113', '132311', '211313', // 30-39
    '231113', '231311', '112133', '112331', '132131', '113123', '113321', '133121', '313121', '211331', // 40-49
    '231131', '213113', '213311', '213131', '311123', '311321', '331121', '312113', '312311', '332111', // 50-59
    '314111', '221411', '431111', '111224', '111422', '121124', '121421', '141122', '141221', '112214', // 60-69
    '112412', '122114', '122411', '142112', '142211', '241211', '221114', '413111', '241112', '134111', // 70-79
    '111242', '121142', '121241', '114212', '124112', '124211', '411212', '421112', '421211', '212141', // 80-89
    '214121', '412121', '111143', '111341', '131141', '114113', '114311', '411113', '411311', '113141', // 90-99
    '114131', '311141', '411131', '211412', '211214', '211232', '2331112'                               // 100-106
  ];

  static List<bool> generateCode128Modules(String input) {
    final clean = input.isEmpty ? 'CAMPUS' : input;
    final List<int> values = [];

    // Start Code B is index 104
    const startCode = 104;
    values.add(startCode);

    int checksum = startCode;
    for (int i = 0; i < clean.length; i++) {
      int code = clean.codeUnitAt(i);
      // Code 128 Set B covers ASCII 32 to 127
      int val = (code >= 32 && code <= 126) ? (code - 32) : 0;
      values.add(val);
      checksum += (i + 1) * val;
    }

    checksum = checksum % 103;
    values.add(checksum);

    // Stop code is index 106
    values.add(106);

    // Convert values into binary modules (true = bar, false = space)
    final List<bool> modules = [];

    // Left quiet zone (10 modules)
    for (int q = 0; q < 10; q++) {
      modules.add(false);
    }

    for (final val in values) {
      if (val < 0 || val >= _code128Patterns.length) continue;
      final pattern = _code128Patterns[val];
      bool isBar = true;
      for (int p = 0; p < pattern.length; p++) {
        int width = int.parse(pattern[p]);
        for (int w = 0; w < width; w++) {
          modules.add(isBar);
        }
        isBar = !isBar;
      }
    }

    // Right quiet zone (10 modules)
    for (int q = 0; q < 10; q++) {
      modules.add(false);
    }

    return modules;
  }

  @override
  Widget build(BuildContext context) {
    final modules = generateCode128Modules(data);
    final totalWidth = modules.length * lineWidth;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: BoxDecoration(
        color: backgroundColor,
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: Colors.grey.shade300),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          CustomPaint(
            size: Size(totalWidth, height),
            painter: _Code128Painter(
              modules: modules,
              lineWidth: lineWidth,
              barColor: barColor,
            ),
          ),
          if (showText) ...[
            const SizedBox(height: 4),
            Text(
              '*${data.isEmpty ? "CAMPUS" : data}*',
              style: textStyle ??
                  const TextStyle(
                    fontFamily: 'monospace',
                    fontSize: 10,
                    letterSpacing: 2,
                    fontWeight: FontWeight.w600,
                    color: Colors.black,
                  ),
            ),
          ],
        ],
      ),
    );
  }
}

class _Code128Painter extends CustomPainter {
  final List<bool> modules;
  final double lineWidth;
  final Color barColor;

  _Code128Painter({
    required this.modules,
    required this.lineWidth,
    required this.barColor,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = barColor
      ..style = PaintingStyle.fill;

    double currentX = 0;
    for (int i = 0; i < modules.length; i++) {
      if (modules[i]) {
        canvas.drawRect(
          Rect.fromLTWH(currentX, 0, lineWidth, size.height),
          paint,
        );
      }
      currentX += lineWidth;
    }
  }

  @override
  bool shouldRepaint(covariant _Code128Painter oldDelegate) {
    return oldDelegate.modules != modules ||
        oldDelegate.lineWidth != lineWidth ||
        oldDelegate.barColor != barColor;
  }
}

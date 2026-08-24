import 'package:flutter/material.dart';

import '../app/app_theme.dart';

class AppIcon extends StatelessWidget {
  final double size;

  const AppIcon({super.key, this.size = 48});

  @override
  Widget build(BuildContext context) => Image.asset(
    'assets/images/app_icon.png',
    width: size,
    height: size,
    fit: BoxFit.contain,
    filterQuality: FilterQuality.high,
    semanticLabel: 'Clash RS',
  );
}

class ScreenshotAppBar extends StatelessWidget implements PreferredSizeWidget {
  final String title;
  final List<Widget> actions;

  const ScreenshotAppBar({
    super.key,
    required this.title,
    this.actions = const [],
  });

  @override
  Size get preferredSize => const Size.fromHeight(58);

  @override
  Widget build(BuildContext context) => AppBar(
    toolbarHeight: 58,
    leadingWidth: 62,
    leading: IconButton(
      icon: const Icon(Icons.arrow_back, size: 28),
      onPressed: () => Navigator.maybePop(context),
    ),
    title: Text(title),
    actions: [...actions, const SizedBox(width: 12)],
  );
}

class ClashLogo extends StatelessWidget {
  final double size;
  const ClashLogo({super.key, this.size = 48});

  @override
  Widget build(BuildContext context) => SizedBox.square(
    dimension: size,
    child: CustomPaint(painter: _ClashLogoPainter()),
  );
}

class _ClashLogoPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final s = size.width;
    final blue = Paint()
      ..color = const Color(0xFF3279BA)
      ..style = PaintingStyle.stroke
      ..strokeWidth = s * .16
      ..strokeCap = StrokeCap.square
      ..strokeJoin = StrokeJoin.round;
    final path = Path()
      ..moveTo(s * .17, s * .68)
      ..lineTo(s * .17, s * .18)
      ..lineTo(s * .48, s * .47)
      ..lineTo(s * .82, s * .18)
      ..lineTo(s * .82, s * .68);
    canvas.drawPath(path, blue);
    final dot = Paint()..color = const Color(0xFF3279BA);
    canvas.drawCircle(Offset(s * .5, s * .76), s * .035, dot);
    final orange = Paint()
      ..color = const Color(0xFFF59A16)
      ..strokeWidth = s * .035
      ..strokeCap = StrokeCap.round;
    for (var i = 0; i < 2; i++) {
      final y = s * (.76 + i * .11);
      canvas.drawLine(Offset(s * .12, y), Offset(s * .32, y - .04 * s), orange);
      canvas.drawLine(Offset(s * .68, y - .04 * s), Offset(s * .88, y), orange);
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

class MenuRow extends StatelessWidget {
  final IconData icon;
  final String title;
  final VoidCallback onTap;

  const MenuRow({
    super.key,
    required this.icon,
    required this.title,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) => InkWell(
    onTap: onTap,
    child: SizedBox(
      height: 64,
      child: Row(
        children: [
          SizedBox(width: 68, child: Icon(icon, size: 26, color: Colors.white)),
          const SizedBox(width: 3),
          Text(title, style: const TextStyle(fontSize: 15, letterSpacing: 1.5)),
        ],
      ),
    ),
  );
}

class ClashCard extends StatelessWidget {
  final Widget child;
  final Color color;
  final VoidCallback? onTap;
  final EdgeInsetsGeometry padding;

  const ClashCard({
    super.key,
    required this.child,
    this.color = AppColors.card,
    this.onTap,
    this.padding = const EdgeInsets.symmetric(horizontal: 10, vertical: 9),
  });

  @override
  Widget build(BuildContext context) => Material(
    color: color,
    borderRadius: BorderRadius.circular(9),
    child: InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(9),
      child: Padding(padding: padding, child: child),
    ),
  );
}

String formatBytes(int value) {
  if (value < 1024) return '$value B';
  if (value < 1024 * 1024) return '${(value / 1024).toStringAsFixed(2)} KiB';
  if (value < 1024 * 1024 * 1024) {
    return '${(value / 1024 / 1024).toStringAsFixed(2)} MiB';
  }
  return '${(value / 1024 / 1024 / 1024).toStringAsFixed(2)} GiB';
}

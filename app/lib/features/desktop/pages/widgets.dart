import 'package:flutter/material.dart';

import '../../../l10n/rs_text.dart';
import '../desktop_app.dart' show DesktopColors;

/// 通用卡片容器：左侧图标块 + 标题 + 右侧 trailing + 内容（无分隔线，紧凑布局）。
class RsCard extends StatelessWidget {
  final String title;
  final IconData icon;
  final Color accent;
  final Widget child;
  final Widget? trailing;
  final Widget? titleSuffix;
  final EdgeInsets contentPadding;
  final double iconSize;
  final int iconQuarterTurns;
  final TextStyle? titleStyle;
  final bool translateTitle;

  const RsCard({
    super.key,
    required this.title,
    required this.icon,
    required this.child,
    this.accent = const Color(0xFF168BFA),
    this.trailing,
    this.titleSuffix,
    this.iconSize = 22,
    this.iconQuarterTurns = 0,
    this.titleStyle,
    this.translateTitle = true,
    this.contentPadding = const EdgeInsets.fromLTRB(16, 12, 16, 16),
  });

  @override
  Widget build(BuildContext context) => Container(
    decoration: BoxDecoration(
      color: Theme.of(context).colorScheme.surface,
      borderRadius: BorderRadius.circular(8),
    ),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      mainAxisSize: MainAxisSize.min,
      children: [
        SizedBox(
          height: 54,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Row(
              children: [
                Container(
                  width: 38,
                  height: 38,
                  decoration: BoxDecoration(
                    color: accent.withValues(alpha: .13),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: RotatedBox(
                    quarterTurns: iconQuarterTurns,
                    child: Icon(icon, color: accent, size: iconSize),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Row(
                    children: [
                      Flexible(
                        child: translateTitle
                            ? RsText(
                                title,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style:
                                    titleStyle ??
                                    const TextStyle(
                                      fontSize: 16,
                                      fontWeight: FontWeight.w700,
                                    ),
                              )
                            : Text(
                                title,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style:
                                    titleStyle ??
                                    const TextStyle(
                                      fontSize: 16,
                                      fontWeight: FontWeight.w700,
                                    ),
                              ),
                      ),
                      if (titleSuffix != null) ...[
                        const SizedBox(width: 6),
                        titleSuffix!,
                      ],
                    ],
                  ),
                ),
                ?trailing,
              ],
            ),
          ),
        ),
        Divider(height: 1, thickness: 1, color: Theme.of(context).dividerColor),
        Padding(padding: contentPadding, child: child),
      ],
    ),
  );
}

/// 通用空态：图标 + 标题 + 副标题。
class RsEmpty extends StatelessWidget {
  final IconData icon;
  final String title;
  final String? subtitle;
  final double iconSize;
  const RsEmpty({
    super.key,
    required this.icon,
    required this.title,
    this.subtitle,
    this.iconSize = 56,
  });

  @override
  Widget build(BuildContext context) => Center(
    child: Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: iconSize, color: const Color(0xFF168BFA)),
        const SizedBox(height: 8),
        RsText(title, style: const TextStyle(fontSize: 13)),
        if (subtitle != null) ...[
          const SizedBox(height: 4),
          RsText(
            subtitle!,
            style: const TextStyle(color: DesktopColors.muted, fontSize: 11),
          ),
        ],
      ],
    ),
  );
}

/// 工具栏：左搜索 / 中 chip / 右按钮组合。
class RsToolbar extends StatelessWidget {
  final List<Widget> children;
  const RsToolbar({super.key, required this.children});

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.fromLTRB(12, 9, 12, 7),
    child: Row(
      children: [
        for (final c in children) ...[c, const SizedBox(width: 6)],
      ],
    ),
  );
}

/// 圆形状态点（绿/灰/红/橙）。
class StatusDot extends StatelessWidget {
  final Color color;
  final double size;
  const StatusDot({super.key, required this.color, this.size = 8});

  @override
  Widget build(BuildContext context) => Container(
    width: size,
    height: size,
    decoration: BoxDecoration(color: color, shape: BoxShape.circle),
  );
}

/// 通用小标签：背景半透明 + 圆角 + 文字。
class RsChip extends StatelessWidget {
  final String text;
  final Color? color;
  final IconData? icon;
  final EdgeInsets padding;
  const RsChip({
    super.key,
    required this.text,
    this.color,
    this.icon,
    this.padding = const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
  });

  @override
  Widget build(BuildContext context) => Container(
    padding: padding,
    decoration: BoxDecoration(
      color: (color ?? const Color(0xFF168BFA)).withValues(alpha: .12),
      borderRadius: BorderRadius.circular(3),
    ),
    child: Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        if (icon != null) ...[
          Icon(icon, size: 13, color: color ?? const Color(0xFF168BFA)),
          const SizedBox(width: 4),
        ],
        Text(
          text,
          style: TextStyle(
            fontSize: 10,
            color: color ?? const Color(0xFF168BFA),
            fontWeight: FontWeight.w500,
          ),
        ),
      ],
    ),
  );
}

/// 通用分隔线。
class RsDivider extends StatelessWidget {
  final double indent;
  const RsDivider({super.key, this.indent = 0});

  @override
  Widget build(BuildContext context) => Divider(
    height: 1,
    thickness: 0.6,
    indent: indent,
    color: Theme.of(context).dividerColor,
  );
}

/// 大数字显示（流量/速度）。
class RsMetric extends StatelessWidget {
  final String label;
  final String value;
  final String? unit;
  final Color color;
  final IconData? icon;
  const RsMetric({
    super.key,
    required this.label,
    required this.value,
    required this.color,
    this.unit,
    this.icon,
  });

  @override
  Widget build(BuildContext context) => Row(
    children: [
      if (icon != null) ...[
        Container(
          width: 26,
          height: 26,
          decoration: BoxDecoration(
            color: color.withValues(alpha: .12),
            borderRadius: BorderRadius.circular(3),
          ),
          child: Icon(icon, color: color, size: 15),
        ),
        const SizedBox(width: 7),
      ],
      Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          RsText(
            label,
            style: const TextStyle(color: DesktopColors.muted, fontSize: 10),
          ),
          const SizedBox(height: 2),
          Row(
            crossAxisAlignment: CrossAxisAlignment.baseline,
            textBaseline: TextBaseline.alphabetic,
            children: [
              Text(
                value,
                style: TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w700,
                  color: color,
                ),
              ),
              if (unit != null) ...[
                const SizedBox(width: 4),
                Text(
                  unit!,
                  style: const TextStyle(
                    fontSize: 10,
                    color: DesktopColors.muted,
                  ),
                ),
              ],
            ],
          ),
        ],
      ),
    ],
  );
}

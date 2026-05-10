import 'package:flutter/material.dart';

class SwipeActionTile extends StatelessWidget {
  final Key dismissKey;
  final Widget child;
  final VoidCallback? onDelete;
  final VoidCallback? onArchive;
  final Future<bool> Function()? confirmDelete;
  final Future<bool> Function()? confirmArchive;
  final IconData archiveIcon;
  final String archiveLabel;
  final Color archiveColor;
  final IconData deleteIcon;
  final String deleteLabel;
  final Color deleteColor;
  final BorderRadius borderRadius;

  const SwipeActionTile({
    super.key,
    required this.dismissKey,
    required this.child,
    this.onDelete,
    this.onArchive,
    this.confirmDelete,
    this.confirmArchive,
    this.archiveIcon = Icons.archive_outlined,
    this.archiveLabel = 'Archive',
    this.archiveColor = const Color(0xFFF59E0B),
    this.deleteIcon = Icons.delete_outline_rounded,
    this.deleteLabel = 'Delete',
    this.deleteColor = const Color(0xFFEF4444),
    this.borderRadius = const BorderRadius.all(Radius.circular(16)),
  });

  DismissDirection get _direction {
    if (onArchive != null && onDelete != null) {
      return DismissDirection.horizontal;
    }
    if (onArchive != null) return DismissDirection.startToEnd;
    if (onDelete != null) return DismissDirection.endToStart;
    return DismissDirection.none;
  }

  @override
  Widget build(BuildContext context) {
    return Dismissible(
      key: dismissKey,
      direction: _direction,
      background: _ActionBackground(
        alignment: Alignment.centerLeft,
        color: archiveColor,
        icon: archiveIcon,
        label: archiveLabel,
        borderRadius: borderRadius,
      ),
      secondaryBackground: _ActionBackground(
        alignment: Alignment.centerRight,
        color: deleteColor,
        icon: deleteIcon,
        label: deleteLabel,
        borderRadius: borderRadius,
      ),
      confirmDismiss: (direction) async {
        if (direction == DismissDirection.startToEnd) {
          if (confirmArchive != null) return confirmArchive!();
          return true;
        }
        if (confirmDelete != null) return confirmDelete!();
        return true;
      },
      onDismissed: (direction) {
        if (direction == DismissDirection.startToEnd) {
          onArchive?.call();
        } else {
          onDelete?.call();
        }
      },
      child: child,
    );
  }
}

class _ActionBackground extends StatelessWidget {
  final Alignment alignment;
  final Color color;
  final IconData icon;
  final String label;
  final BorderRadius borderRadius;

  const _ActionBackground({
    required this.alignment,
    required this.color,
    required this.icon,
    required this.label,
    required this.borderRadius,
  });

  @override
  Widget build(BuildContext context) {
    final isLeft = alignment == Alignment.centerLeft;
    return Container(
      alignment: alignment,
      padding: const EdgeInsets.symmetric(horizontal: 24),
      decoration: BoxDecoration(
        color: color,
        borderRadius: borderRadius,
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (isLeft) ...[
            Icon(icon, color: Colors.white, size: 22),
            const SizedBox(width: 8),
            Text(
              label,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 13,
                fontWeight: FontWeight.w600,
              ),
            ),
          ] else ...[
            Text(
              label,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 13,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(width: 8),
            Icon(icon, color: Colors.white, size: 22),
          ],
        ],
      ),
    );
  }
}

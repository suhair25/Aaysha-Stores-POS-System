import 'package:flutter/material.dart';
import 'package:aaysha_stores/config/app_theme.dart';

class AnimatedPrimaryButton extends StatefulWidget {
  final String label;
  final VoidCallback? onPressed;
  final double height;

  const AnimatedPrimaryButton({super.key, required this.label, this.onPressed, this.height = 52});

  @override
  State<AnimatedPrimaryButton> createState() => _AnimatedPrimaryButtonState();
}

class _AnimatedPrimaryButtonState extends State<AnimatedPrimaryButton> with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(vsync: this, duration: const Duration(milliseconds: 180), lowerBound: 0.0, upperBound: 6.0);
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  void _onTapDown(TapDownDetails _) => _ctrl.forward();
  void _onTapUp(TapUpDetails _) => _ctrl.reverse();
  void _onTapCancel() => _ctrl.reverse();

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTapDown: widget.onPressed != null ? _onTapDown : null,
      onTapUp: widget.onPressed != null ? _onTapUp : null,
      onTapCancel: widget.onPressed != null ? _onTapCancel : null,
      onTap: widget.onPressed,
      child: AnimatedBuilder(
        animation: _ctrl,
        builder: (context, child) {
          final elevation = 6 - _ctrl.value;
          return PhysicalModel(
            color: AppColors.primary,
            elevation: elevation,
            borderRadius: BorderRadius.circular(AppRadius.sm),
            child: Container(
              height: widget.height,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                gradient: AppColors.primaryGradient,
                borderRadius: BorderRadius.circular(AppRadius.sm),
              ),
              child: child,
            ),
          );
        },
        child: Text(
          widget.label,
          style: Theme.of(context).textTheme.labelLarge?.copyWith(color: AppColors.white),
        ),
      ),
    );
  }
}

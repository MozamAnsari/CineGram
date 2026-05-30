import 'dart:ui';
import 'package:flutter/material.dart';

class GlassmorphicCard extends StatefulWidget {
  final Widget child;
  final double borderRadius;
  final double blur;
  final double borderWidth;
  final double? width;
  final double? height;
  final EdgeInsetsGeometry? padding;
  final EdgeInsetsGeometry? margin;
  final VoidCallback? onTap;
  final bool isSelected;
  final bool enableHoverScale;

  const GlassmorphicCard({
    Key? key,
    required this.child,
    this.borderRadius = 20.0,
    this.blur = 15.0,
    this.borderWidth = 1.0,
    this.width,
    this.height,
    this.padding,
    this.margin,
    this.onTap,
    this.isSelected = false,
    this.enableHoverScale = true,
  }) : super(key: key);

  @override
  State<GlassmorphicCard> createState() => _GlassmorphicCardState();
}

class _GlassmorphicCardState extends State<GlassmorphicCard> with SingleTickerProviderStateMixin {
  bool _isHovered = false;
  late AnimationController _controller;
  late Animation<double> _scaleAnimation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      duration: const Duration(milliseconds: 200),
      vsync: this,
    );
    _scaleAnimation = Tween<double>(begin: 1.0, end: 1.04).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeOutCubic),
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final bool active = _isHovered || widget.isSelected;
    
    final Color primaryColor = Theme.of(context).primaryColor;
    final Color activeBorderColor = primaryColor.withOpacity(0.55); // Shimmer
    final Color inactiveBorderColor = Colors.white.withOpacity(0.08);
    final Color activeGlowColor = primaryColor.withOpacity(0.12);

    return MouseRegion(
      onEnter: (_) {
        setState(() => _isHovered = true);
        if (widget.enableHoverScale) _controller.forward();
      },
      onExit: (_) {
        setState(() => _isHovered = false);
        if (widget.enableHoverScale) _controller.reverse();
      },
      child: GestureDetector(
        onTapDown: widget.onTap != null ? (_) => _controller.forward() : null,
        onTapUp: widget.onTap != null ? (_) => _controller.reverse() : null,
        onTapCancel: widget.onTap != null ? () => _controller.reverse() : null,
        onTap: widget.onTap,
        child: ScaleTransition(
          scale: _scaleAnimation,
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 250),
            margin: widget.margin,
            width: widget.width,
            height: widget.height,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(widget.borderRadius),
              boxShadow: [
                BoxShadow(
                  color: active ? activeGlowColor : Colors.black.withOpacity(0.4),
                  blurRadius: active ? 25.0 : 15.0,
                  spreadRadius: active ? 1.0 : -3.0,
                  offset: active ? const Offset(0, 8) : const Offset(0, 4),
                ),
              ],
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(widget.borderRadius),
              child: BackdropFilter(
                filter: ImageFilter.blur(sigmaX: widget.blur, sigmaY: widget.blur),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 250),
                  padding: widget.padding ?? const EdgeInsets.all(16.0),
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(widget.borderRadius),
                    gradient: LinearGradient(
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                      colors: [
                        Colors.white.withOpacity(active ? 0.08 : 0.04),
                        Colors.white.withOpacity(active ? 0.03 : 0.01),
                        Colors.white.withOpacity(0.0),
                      ],
                      stops: const [0.0, 0.5, 1.0],
                    ),
                    border: Border.all(
                      color: active ? activeBorderColor : inactiveBorderColor,
                      width: widget.borderWidth,
                    ),
                  ),
                  child: widget.child,
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

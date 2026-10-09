import 'package:flutter/material.dart';
import '../core/theme/mathalino_tokens.dart';

/// Chunky 3D Pill Button
/// Interactive button with 3D bottom shadow that depresses 4px when pressed
class Chunky3DButton extends StatefulWidget {
  final String text;
  final VoidCallback? onPressed;
  final bool isLoading;
  final bool enabled;
  final bool iconLeading;
  final IconData? icon;
  final double height;
  final double fontSize;
  final EdgeInsetsGeometry? margin;

  const Chunky3DButton({
    super.key,
    required this.text,
    this.onPressed,
    this.isLoading = false,
    this.enabled = true,
    this.iconLeading = false,
    this.icon = Icons.arrow_forward_rounded,
    this.height = 64.0,
    this.fontSize = 23.0,
    this.margin,
  });

  @override
  State<Chunky3DButton> createState() => _Chunky3DButtonState();
}

class _Chunky3DButtonState extends State<Chunky3DButton> {
  bool _isPressed = false;

  bool get _isClickable => widget.enabled && !widget.isLoading && widget.onPressed != null;

  @override
  Widget build(BuildContext context) {
    final pressed = _isPressed && _isClickable;

    Widget content;
    if (widget.isLoading) {
      content = const SizedBox(
        width: 26,
        height: 26,
        child: CircularProgressIndicator(
          strokeWidth: 3.0,
          valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
        ),
      );
    } else {
      final labelWidget = Text(
        widget.text,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: TextStyle(
          fontFamily: AppTokens.fontBaloo2,
          fontSize: widget.fontSize,
          fontWeight: FontWeight.w700,
          color: Colors.white,
          height: 1.1,
        ),
      );

      final iconWidget = widget.icon != null
          ? Icon(
              widget.icon,
              color: Colors.white,
              size: 24,
            )
          : null;

      if (iconWidget != null) {
        if (widget.iconLeading) {
          content = Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              mainAxisSize: MainAxisSize.min,
              children: [
                iconWidget,
                const SizedBox(width: 10),
                Flexible(child: FittedBox(fit: BoxFit.scaleDown, child: labelWidget)),
              ],
            ),
          );
        } else {
          content = Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              mainAxisSize: MainAxisSize.min,
              children: [
                Flexible(child: FittedBox(fit: BoxFit.scaleDown, child: labelWidget)),
                const SizedBox(width: 10),
                iconWidget,
              ],
            ),
          );
        }
      } else {
        content = Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: FittedBox(fit: BoxFit.scaleDown, child: labelWidget),
        );
      }
    }

    Widget button = GestureDetector(
      onTapDown: _isClickable ? (_) => setState(() => _isPressed = true) : null,
      onTapUp: _isClickable
          ? (_) {
              setState(() => _isPressed = false);
              widget.onPressed?.call();
            }
          : null,
      onTapCancel: () {
        if (_isPressed) setState(() => _isPressed = false);
      },
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 70),
        curve: Curves.easeOut,
        margin: EdgeInsets.only(
          top: pressed ? 4.0 : 0.0,
          bottom: pressed ? 2.0 : 6.0,
        ),
        height: widget.height,
        width: double.infinity,
        decoration: BoxDecoration(
          color: _isClickable
              ? AppTokens.primaryIndigo
              : AppTokens.primaryIndigo.withValues(alpha: 0.6),
          borderRadius: BorderRadius.circular(AppTokens.radiusPill),
          boxShadow: [
            BoxShadow(
              color: AppTokens.primaryShadow,
              offset: Offset(0, pressed ? 2.0 : 6.0),
              blurRadius: 0,
              spreadRadius: 0,
            ),
          ],
        ),
        alignment: Alignment.center,
        child: content,
      ),
    );

    if (widget.margin != null) {
      button = Padding(
        padding: widget.margin!,
        child: button,
      );
    }

    return Semantics(
      button: true,
      enabled: _isClickable,
      label: widget.text,
      child: button,
    );
  }
}

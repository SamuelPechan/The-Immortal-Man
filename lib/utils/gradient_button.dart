import 'package:flutter/material.dart';

class GradientButton extends StatefulWidget {
  final String text;
  final VoidCallback? onPressed;
  final double? width;
  final double height;
  final double borderRadius;
  final TextStyle? textStyle;
  final Widget? child;
  final bool isLoading;
  final String loadingText;
  
  const GradientButton({
    Key? key,
    this.text = '',
    required this.onPressed,
    this.width,
    this.height = 50.0,
    this.borderRadius = 8.0,
    this.textStyle,
    this.child,
    this.isLoading = false,
    this.loadingText = 'Loading...',
  }) : super(key: key);

  @override
  State<GradientButton> createState() => _GradientButtonState();
}

class _GradientButtonState extends State<GradientButton> {
  bool _isPressed = false;

  @override
  Widget build(BuildContext context) {
    // Determine if the button should be disabled
    final bool isDisabled = widget.onPressed == null || widget.isLoading || _isPressed;

    return Container(
      width: widget.width,
      height: widget.height,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(widget.borderRadius),
        gradient: isDisabled 
            ? const LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [Colors.grey, Colors.grey],
              )
            : const LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [Colors.orangeAccent, Colors.amber],
              ),
      ),
      child: ElevatedButton(
        onPressed: isDisabled 
            ? null 
            : () {
                // Set pressed state to prevent multiple clicks 
                setState(() {
                  _isPressed = true;
                });
                
                // Call the original callback
                widget.onPressed?.call();
                
                // Optional: reset after a short delay if the button remains visible
                Future.delayed(const Duration(seconds: 2), () {
                  if (mounted) {
                    setState(() {
                      _isPressed = false;
                    });
                  }
                });
              },
        style: ElevatedButton.styleFrom(
          backgroundColor: Colors.transparent,
          foregroundColor: Colors.black,
          elevation: 0,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(widget.borderRadius),
          ),
          padding: const EdgeInsets.symmetric(horizontal: 16),
          // Override the disabled color to be transparent to show the gradient
          disabledBackgroundColor: Colors.transparent,
          disabledForegroundColor: Colors.black.withOpacity(0.5),
        ),
        child: widget.isLoading || _isPressed
            ? Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(
                      color: Colors.black,
                      strokeWidth: 2,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Text(
                    widget.loadingText,
                    style: widget.textStyle ?? const TextStyle(
                      color: Colors.black,
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              )
            : widget.child ?? Text(
                widget.text,
                style: widget.textStyle ?? const TextStyle(
                  color: Colors.black,
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                ),
              ),
      ),
    );
  }
}

// Extension for AppBar to easily create a gradient AppBar
extension GradientAppBar on AppBar {
  static AppBar create({
    required String title,
    List<Widget>? actions,
    PreferredSizeWidget? bottom,
    Widget? leading,
    bool centerTitle = true,
  }) {
    return AppBar(
      backgroundColor: Colors.transparent,
      elevation: 0,
      flexibleSpace: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [Colors.orangeAccent, Colors.amber],
          ),
        ),
      ),
      title: Text(
        title,
        style: const TextStyle(
          color: Colors.black,
          fontSize: 20,
          fontWeight: FontWeight.bold,
        ),
      ),
      centerTitle: centerTitle,
      actions: actions,
      bottom: bottom,
      leading: leading,
    );
  }
} 
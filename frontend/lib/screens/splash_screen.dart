import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'home_screen.dart';
import 'login_screen.dart';

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _carTranslationX;

  double _screenWidth = 0.0;
  final List<double> _letterScreenX = [];
  double _textWidth = 0.0;

  static const String _appName = 'Ridify';

  static const TextStyle _ridifyStyle = TextStyle(
    fontSize: 170,
    fontWeight: FontWeight.bold,
    color: Colors.black,
    fontFamily: 'Georgia',
    height: 1.0,
  );

  // Car faces RIGHT → bonnet (front/hood) is on the right side of the image.
  // 0.85 means the bonnet tip is roughly at 85% of the image width from the left edge.
  static const double _bonnetFraction = 0.85;

  @override
  void initState() {
    super.initState();

    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 4000),
    );

    _controller.addStatusListener((status) {
      if (status == AnimationStatus.completed) {
        Future.delayed(
          const Duration(milliseconds: 300),
          _checkSessionAndNavigate,
        );
      }
    });
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final newWidth = MediaQuery.of(context).size.width;

    if (newWidth != _screenWidth) {
      _screenWidth = newWidth;

      _carTranslationX = Tween<double>(
        begin: -_screenWidth,
        end: 0.0,
      ).animate(CurvedAnimation(parent: _controller, curve: Curves.easeOut));

      _computeLetterPositions();
    }

    if (!_controller.isAnimating &&
        _controller.status != AnimationStatus.completed) {
      _controller.forward();
    }
  }

  /// Uses TextPainter to find the exact screen X of each letter's left edge.
  void _computeLetterPositions() {
    final painter = TextPainter(
      text: TextSpan(text: _appName, style: _ridifyStyle),
      textDirection: TextDirection.ltr,
    )..layout(maxWidth: double.infinity);

    _textWidth = painter.width;

    // Since text is centered, find where the text block starts on screen.
    final double textLeftEdge = (_screenWidth - _textWidth) / 2.0;

    _letterScreenX.clear();
    for (int i = 0; i < _appName.length; i++) {
      final caretOffset = painter.getOffsetForCaret(
        TextPosition(offset: i),
        Rect.zero,
      );
      // Absolute X position of letter i on the screen
      _letterScreenX.add(textLeftEdge + caretOffset.dx);
    }
  }

  /// The current screen X position of the car's bonnet (front tip).
  ///
  /// How this works:
  ///   - Align(0, …) centers the car horizontally → car center = screenWidth / 2
  ///   - Transform.translate shifts the car by _carTranslationX.value
  ///   - So car LEFT EDGE = screenWidth/2 + translationX - screenWidth/2 = translationX
  ///   - Bonnet is at bonnetFraction of the car image width from the left edge
  double get _bonnetScreenX =>
      _carTranslationX.value + _screenWidth * _bonnetFraction;

  /// Smooth 0→1 opacity for letter [index].
  /// The letter fades in over 25 logical pixels of bonnet travel past it.
  double _opacityFor(int index) {
    if (_letterScreenX.isEmpty) return 0.0;
    // Safety net: if animation is nearly done, snap all remaining letters to fully visible.
    if (_controller.value >= 0.97) return 1.0;
    final double diff = _bonnetScreenX - _letterScreenX[index];
    return (diff / 25.0).clamp(0.0, 1.0);
  }

  Future<void> _checkSessionAndNavigate() async {
    final prefs = await SharedPreferences.getInstance();
    final savedName = prefs.getString('user_name');
    final savedAge = prefs.getString('user_age');
    final savedEmail = prefs.getString('user_email');

    final bool hasSession =
        savedName != null && savedEmail != null && savedAge != null;

    if (!mounted) return;

    Navigator.pushReplacement(
      context,
      PageRouteBuilder(
        transitionDuration: const Duration(milliseconds: 500),
        pageBuilder: (_, animation, __) => hasSession
            ? HomeScreen(
                userName: savedName,
                userAge: savedAge,
                userEmail: savedEmail,
              )
            : const LoginScreen(),
        transitionsBuilder: (_, animation, __, child) =>
            FadeTransition(opacity: animation, child: child),
      ),
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: AnimatedBuilder(
        animation: _controller,
        builder: (context, _) {
          return Stack(
            children: [
              // ── 1. "Ridify" — each letter fades in as bonnet sweeps past it ──
              Align(
                alignment: const Alignment(0, -0.35),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    for (int i = 0; i < _appName.length; i++)
                      Opacity(
                        opacity: _opacityFor(i),
                        child: Text(_appName[i], style: _ridifyStyle),
                      ),
                  ],
                ),
              ),

              // ── 2. The Car — slides in from the left ──
              Align(
                alignment: const Alignment(0, 0.35),
                child: Transform.translate(
                  offset: Offset(_carTranslationX.value, 0),
                  child: SizedBox(
                    width: _screenWidth,
                    child: Image.asset(
                      'assets/splashScreenCar.png',
                      fit: BoxFit.contain,
                    ),
                  ),
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}

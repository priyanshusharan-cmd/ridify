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
  double _screenHeight = 0.0;
  final List<double> _letterScreenX = [];
  double _textWidth = 0.0;

  static const String _appName = 'Ridify';

  // Font size scales with screen width, clamped between phone and desktop sizes.
  double get _fontSize => (_screenWidth * 0.22).clamp(60.0, 170.0);

  TextStyle get _ridifyStyle => TextStyle(
    fontSize: _fontSize,
    fontWeight: FontWeight.bold,
    color: Colors.black,
    fontFamily: 'Georgia',
    height: 1.0,
  );

  // Car faces RIGHT → bonnet (front/hood) is on the right side of the image.
  static const double _bonnetFraction = 0.85;

  // ── CHANGE: Fixed pixel gap between the bottom of the text and top of the
  // car image. This value never changes regardless of screen size or aspect ratio.
  static const double _gapBetweenTextAndCar = -75.0;

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
    final size = MediaQuery.of(context).size;
    final newWidth = size.width;
    final newHeight = size.height;

    if (newWidth != _screenWidth || newHeight != _screenHeight) {
      _screenWidth = newWidth;
      _screenHeight = newHeight;

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

  void _computeLetterPositions() {
    final painter = TextPainter(
      text: TextSpan(text: _appName, style: _ridifyStyle),
      textDirection: TextDirection.ltr,
    )..layout(maxWidth: double.infinity);

    _textWidth = painter.width;

    final double textLeftEdge = (_screenWidth - _textWidth) / 2.0;

    _letterScreenX.clear();
    for (int i = 0; i < _appName.length; i++) {
      final caretOffset = painter.getOffsetForCaret(
        TextPosition(offset: i),
        Rect.zero,
      );
      _letterScreenX.add(textLeftEdge + caretOffset.dx);
    }
  }

  double get _bonnetScreenX =>
      _carTranslationX.value + _screenWidth * _bonnetFraction;

  double _opacityFor(int index) {
    if (_letterScreenX.isEmpty) return 0.0;
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
        pageBuilder: (context, animation, secondaryAnimation) => hasSession
            ? HomeScreen(
                userName: savedName,
                userAge: savedAge,
                userEmail: savedEmail,
              )
            : const LoginScreen(),
        transitionsBuilder: (context, animation, secondaryAnimation, child) =>
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
    // ── CHANGE: Compute the vertical layout using fixed pixel sizes so the
    // gap between text and car is always exactly _gapBetweenTextAndCar pixels,
    // regardless of screen width or aspect ratio.
    //
    // Layout logic:
    //   carImageHeight  ≈ screenWidth * 0.45  (car fills full width, ~45% tall)
    //   textHeight      = fontSize             (height:1.0 means no extra line spacing)
    //   totalBlockHeight = textHeight + gap + carImageHeight
    //   blockTop        = (screenHeight - totalBlockHeight) / 2   ← centers the pair
    //   textTop         = blockTop
    //   carTop          = blockTop + textHeight + gap

    final double carImageHeight = _screenWidth * 0.45;
    final double textHeight = _fontSize;
    final double totalBlockHeight =
        textHeight + _gapBetweenTextAndCar + carImageHeight;
    final double blockTop = (_screenHeight - totalBlockHeight) / 2.0;
    final double textTop = blockTop;
    final double carTop = blockTop + textHeight + _gapBetweenTextAndCar;

    return Scaffold(
      backgroundColor: Colors.white,
      body: AnimatedBuilder(
        animation: _controller,
        builder: (context, _) {
          return Stack(
            children: [
              // ── 1. "Ridify" — positioned at a fixed pixel top offset ──
              Positioned(
                top: textTop,
                left: 0,
                right: 0,
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
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

              // ── 2. The Car — positioned directly below text with fixed gap ──
              Positioned(
                top: carTop,
                left: 0,
                right: 0,
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

import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../services/config_service.dart';
import '../services/token_service.dart';
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

  // Guards against starting the animation before the image is decoded.
  bool _imageReady = false;

  static const String _appName = 'Ridify';
  static const String _carAsset = 'assets/splashScreenCar.png';

  // Font size scales with screen width, clamped between phone and desktop sizes.
  double get _fontSize => (_screenWidth * 0.22).clamp(60.0, 170.0);

  TextStyle _ridifyStyle(BuildContext context) => TextStyle(
    fontSize: _fontSize,
    fontWeight: FontWeight.bold,
    color: Theme.of(context).textTheme.bodyLarge?.color,
    fontFamily: 'Georgia',
    height: 1.0,
  );

  // Car faces RIGHT → bonnet (front/hood) is on the right side of the image.
  static const double _bonnetFraction = 0.85;

  // ── Fixed pixel gap between the bottom of the text and top of the
  // car image. This value never changes regardless of screen size or aspect ratio.
  static const double _gapBetweenTextAndCar = -75.0;

  @override
  void initState() {
    super.initState();

    // Fire off a background request to wake up the Render backend server.
    // This happens asynchronously and will NOT block the splash animation.
    _wakeBackendServer();

    // ── CHANGE: Use a cubic Bézier that mimics a real car's acceleration
    // profile — a brief "pull-away" ease-in that transitions into a smooth,
    // decelerating glide. This gives the entrance a cinematic automotive feel
    // (as opposed to the symmetric easeOut which feels more digital/generic).
    //
    // Curve breakdown:
    //   • Starts slightly slow  (car "pulls away from rest")
    //   • Accelerates through the mid-point
    //   • Decelerates sharply at the end  (car "parks" precisely under the text)
    //
    // The slightly longer duration (2600 ms vs 2400 ms) gives the deceleration
    // phase extra room to breathe without making the overall animation feel slow.
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2250),
    );

    _controller.addStatusListener((status) {
      if (status == AnimationStatus.completed) {
        Future.delayed(
          const Duration(milliseconds: 300),
          _checkSessionAndNavigate,
        );
      }
    });

    // ── CHANGE: Precache the PNG so the GPU texture is resident before the
    // very first frame of the animation. We do this in initState so the load
    // starts as early as possible (before didChangeDependencies fires and
    // before the AnimationController begins).
    //
    // _startAnimationWhenReady() is called once both the image AND the layout
    // metrics are available, whichever arrives last.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _precacheCarImage();
    });
  }

  /// Precaches [_carAsset] and sets [_imageReady] = true when done,
  /// then attempts to start the animation.
  Future<void> _precacheCarImage() async {
    // precacheImage resolves only after the image is fully decoded and
    // uploaded to the GPU — eliminating the first-frame pop-in.
    await precacheImage(const AssetImage(_carAsset), context);
    if (!mounted) return;
    setState(() => _imageReady = true);
    _startAnimationWhenReady();
  }

  /// Starts the controller only when BOTH the layout metrics AND the image
  /// are ready. Called from both didChangeDependencies and _precacheCarImage
  /// so whichever finishes last actually kicks off the animation.
  void _startAnimationWhenReady() {
    if (!_imageReady) return; // image not decoded yet
    if (_screenWidth == 0.0) return; // layout not measured yet
    if (_controller.isAnimating) return; // already running
    if (_controller.status == AnimationStatus.completed) return;
    _controller.forward();
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

      // ── CHANGE: Replaced Curves.easeOut with a custom cubic that delivers
      // an automotive "pull-away and park" feel:
      //
      //   Cubic(0.25, 0.0, 0.15, 1.0)
      //   p1=(0.25, 0.00) → gentle initial torque (not an instant launch)
      //   p2=(0.15, 1.00) → aggressive late deceleration (precision stop)
      //
      // This matches how a well-engineered car actually accelerates from
      // standstill and glides to a halt — the hallmark of a premium feel.
      _carTranslationX = Tween<double>(begin: -_screenWidth, end: 0.0).animate(
        CurvedAnimation(
          parent: _controller,
          curve: const Cubic(0.25, 0.0, 0.15, 1.0),
        ),
      );

      _computeLetterPositions();
    }

    // ── CHANGE: Animation start is now gated by _startAnimationWhenReady()
    // instead of being fired unconditionally. This prevents the controller
    // from advancing even a single tick before the image texture is resident.
    _startAnimationWhenReady();
  }

  void _computeLetterPositions() {
    final painter = TextPainter(
      text: TextSpan(text: _appName, style: _ridifyStyle(context)),
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
    final savedIsAdmin = prefs.getBool('is_admin') ?? false;

    // Check for valid token using TokenService
    final hasToken = await TokenService.hasValidToken();

    final bool hasSession = savedName != null &&
        savedEmail != null &&
        savedAge != null &&
        hasToken;

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
                isAdmin: savedIsAdmin,
              )
            : const LoginScreen(),
        transitionsBuilder: (context, animation, secondaryAnimation, child) =>
            FadeTransition(opacity: animation, child: child),
      ),
    );
  }

  /// Sends a lightweight, non-blocking ping to the backend server.
  /// Since the backend is hosted on a free tier (e.g., Render), it might
  /// be asleep. Waking it up during the splash screen ensures it's ready
  /// by the time the user interacts with the app.
  void _wakeBackendServer() async {
    await ConfigService.fetchConfig();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // ── Compute the vertical layout using fixed pixel sizes so the
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
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
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
                        child: Text(_appName[i], style: _ridifyStyle(context)),
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
                    child: Image.asset(_carAsset, fit: BoxFit.contain),
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

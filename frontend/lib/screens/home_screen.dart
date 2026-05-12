import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'dart:async';
import 'package:socket_io_client/socket_io_client.dart' as io;
import 'find_ride_screen.dart';
import 'offer_ride_screen.dart';
import 'profile_screen.dart';
import 'ride_history_screen.dart';
import '../widgets/active_rides_tab.dart';
import 'completion_screen.dart';
import '../core/constants.dart';

// ─────────────────────────────────────────────────────────────────────────────
//  Animation constants
//
//  STARTUP Timeline (controller 0.0 → 1.0, total = 5 s):
//
//    0.000 → 0.600  Phase 1  – car enters from far-left (-200 px, fully hidden),
//                              sweeps across screen, "paints" Ridify text as its
//                              BACK BUMPER passes each letter, then exits fully
//                              off the right edge.
//                              Curve: easeIn  → stationary start, fastest exit.
//
//    0.600 → 0.605  Teleport – car snaps instantly back to x = -200 (invisible).
//
//    0.605 → 1.000  Phase 2  – car drives in from far-left again, decelerates
//                              and comes to a dead stop exactly to the right of
//                              "Ridify".  No second adjustment.
//                              Curve: easeOut → fast entry, smooth dead-stop.
//
//  VICTORY LAP Timeline (controller 0.0 → 1.0, total = 3 s):
//
//    0.000 → 0.450  Phase A  – car accelerates from parking spot, exits right.
//                              Curve: easeIn  → smooth departure, fastest exit.
//
//    0.450 → 0.500  Teleport – car snaps instantly back to x = _kCarOffLeft.
//
//    0.500 → 1.000  Phase B  – car enters from left, decelerates, re-parks.
//                              Curve: easeOut → fast entry, smooth dead-stop.
//
//    Text stays fully visible (revealFactor = 1.0) for the entire victory lap.
// ─────────────────────────────────────────────────────────────────────────────
const double _kCarW = 75.0; // car width  – never changes
const double _kCarH = 120.0; // car height – never changes
const double _kCarOffLeft = -125.0; // guaranteed off-screen starting X
const double _kCarGap = 8.0; // px gap between text right-edge and car
const double _kPhase1End = 0.600; // startup: fraction where Phase 1 ends
const double _kTeleportEnd =
    0.560; // startup: fraction where teleport ends / Phase 2 starts

// Victory lap phase boundaries
const double _kVPhase1End = 0.450; // fraction where car exits right
const double _kVTeleportEnd =
    0.500; // fraction where teleport snaps / Phase B starts

class HomeScreen extends StatefulWidget {
  final String userName;
  final String userAge;
  final String userEmail;

  const HomeScreen({
    super.key,
    this.userName = "Unknown",
    this.userAge = "18",
    this.userEmail = "email@example.com",
  });

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

// TickerProviderStateMixin (not Single) because we now have TWO controllers.
class _HomeScreenState extends State<HomeScreen> with TickerProviderStateMixin {
  int _currentIndex = 0;
  late io.Socket socket;
  List<dynamic> allRides = [];
  Timer? _pollingTimer;

  // ── Startup animation ──────────────────────────────────────────────────────
  late AnimationController _startupController;
  static bool _hasPlayedStartupAnimation = false;

  // ── Victory Lap animation ──────────────────────────────────────────────────
  late AnimationController _victoryController;

  /// True while the victory lap car is in motion.
  /// Extra taps are ignored while this is true (anti-spam guard).
  bool _isVictoryLapRunning = false;

  /// Exact pixel width of the "Ridify" label, measured once at startup via
  /// TextPainter using the identical TextStyle as the real Text widget.
  late final double _ridifyTextWidth;

  /// X-coordinate of the car's LEFT edge when it is parked (startup Phase 2 final pos).
  late final double _parkingX;

  // ── initState ──────────────────────────────────────────────────────────────
  @override
  void initState() {
    super.initState();

    // Measure "Ridify" exactly once so parkingX is always pixel-perfect.
    final tp = TextPainter(
      text: const TextSpan(
        text: 'Ridify',
        style: TextStyle(
          color: Colors.white,
          fontSize: 28,
          fontWeight: FontWeight.bold,
          letterSpacing: -1,
        ),
      ),
      textDirection: TextDirection.ltr,
    )..layout();
    _ridifyTextWidth = tp.width;
    _parkingX = _ridifyTextWidth + _kCarGap;

    // Startup controller – runs linearly; all easing is applied per-phase.
    _startupController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 5000),
    );

    if (!_hasPlayedStartupAnimation) {
      _startupController.forward();
      _hasPlayedStartupAnimation = true;
    } else {
      _startupController.value = 1.0;
    }

    // Victory lap controller – 3 s total.
    _victoryController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 3000),
    );

    fetchRides();
    initSocket();
    _pollingTimer = Timer.periodic(
      const Duration(seconds: 3),
      (_) => fetchRides(),
    );
  }

  // ── Animation helpers ──────────────────────────────────────────────────────

  /// Returns the car's left-edge X for the STARTUP animation.
  double _carX(double progress, double screenWidth) {
    if (progress < _kPhase1End) {
      // Phase 1: easeIn → starts stationary, accelerates, exits at full speed.
      final double t = progress / _kPhase1End;
      final double eased = Curves.easeIn.transform(t);
      return _kCarOffLeft + (screenWidth - _kCarOffLeft + _kCarW) * eased;
    } else if (progress < _kTeleportEnd) {
      // Teleport: snap instantly; car is invisible off the left edge.
      return _kCarOffLeft;
    } else {
      // Phase 2: easeOut → fast entry, smooth deceleration, dead stop.
      final double t = (progress - _kTeleportEnd) / (1.0 - _kTeleportEnd);
      final double eased = Curves.easeOut.transform(t);
      return _kCarOffLeft + (_parkingX - _kCarOffLeft) * eased;
    }
  }

  /// Returns the car's left-edge X for the VICTORY LAP animation.
  ///
  /// Phase A : car accelerates out of parking spot and exits off the right.
  /// Teleport: car snaps back to the far-left (invisible).
  /// Phase B : car enters from left, decelerates, and re-parks.
  double _victoryCarX(double progress, double screenWidth) {
    if (progress < _kVPhase1End) {
      // Phase A: easeIn – smooth launch from parking spot → off right edge.
      final double t = progress / _kVPhase1End;
      final double eased = Curves.easeIn.transform(t);
      // Travel: _parkingX → (screenWidth + _kCarW)  [fully off-right]
      return _parkingX + (screenWidth + _kCarW - _parkingX) * eased;
    } else if (progress < _kVTeleportEnd) {
      // Teleport: invisible wrap to the left.
      return _kCarOffLeft;
    } else {
      // Phase B: easeOut – fast entry from left → dead stop at _parkingX.
      final double t = (progress - _kVTeleportEnd) / (1.0 - _kVTeleportEnd);
      final double eased = Curves.easeOut.transform(t);
      return _kCarOffLeft + (_parkingX - _kCarOffLeft) * eased;
    }
  }

  /// Fraction of the "Ridify" text that should be visible (0.0 – 1.0).
  ///
  /// During the VICTORY LAP, text is always 1.0 (already fully painted).
  /// During the STARTUP animation, text is revealed behind the car's back bumper.
  double _revealFactor(double progress, double carX) {
    if (progress >= _kPhase1End) return 1.0;
    return ((carX + 5.0) / _ridifyTextWidth).clamp(0.0, 1.0);
  }

  // ── Victory Lap trigger ────────────────────────────────────────────────────

  /// Starts the victory lap.  Silently ignored if:
  ///   • The startup animation is still playing (car is busy).
  ///   • A victory lap is already in progress (anti-spam guard).
  void _triggerVictoryLap() {
    if (_isVictoryLapRunning) return;
    if (_startupController.isAnimating) return;

    setState(() => _isVictoryLapRunning = true);

    _victoryController.forward(from: 0.0).then((_) {
      if (mounted) setState(() => _isVictoryLapRunning = false);
    });
  }

  // ── Data fetching ──────────────────────────────────────────────────────────
  Future<void> fetchRides() async {
    try {
      final response = await http.get(Uri.parse("$kBaseUrl/api/rides"));
      if (response.statusCode == 200 && mounted) {
        setState(() => allRides = jsonDecode(response.body));
      }
    } catch (e) {
      debugPrint("❌ Fetch Error: $e");
    }
  }

  void initSocket() {
    socket = io.io(kBaseUrl, <String, dynamic>{
      'transports': ['websocket'],
      'autoConnect': true,
    });
    socket.on('new_ride_request', (_) => fetchRides());
    socket.on('ride_accepted', (_) => fetchRides());
    socket.on('ride_cancelled', (_) => fetchRides());

    // ride_ended: only the DRIVER sees the green completion screen
    // Riders are handled via passenger_dropped in live_tracking_screen
    socket.on('ride_ended', (data) {
      fetchRides();
      if (mounted && data != null) {
        final bool iAmDriver = data['riderName'] == widget.userName;
        if (iAmDriver) {
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (!mounted) return;
            Navigator.of(context).popUntil((route) => route.isFirst);
            Navigator.of(context).push(
              MaterialPageRoute(builder: (_) => CompletionScreen(
                isDriver: true,
                rideId: data['rideId']?.toString() ?? '',
                myName: widget.userName,
                fareAmount: 0,
              )),
            );
            setState(() => _currentIndex = 0);
          });
        }
      }
    });

    socket.on('database_wiped', (_) {
      fetchRides();
      if (mounted) Navigator.popUntil(context, (route) => route.isFirst);
    });
  }

  @override
  void dispose() {
    _pollingTimer?.cancel();
    socket.dispose();
    _startupController.dispose();
    _victoryController.dispose();
    super.dispose();
  }

  // ── Build ──────────────────────────────────────────────────────────────────
  @override
  Widget build(BuildContext context) {
    int requestsForMeCount = 0;
    for (final r in allRides.where(
      (r) =>
          r['riderName'] == widget.userName &&
          r['status'] != 'cancelled' &&
          r['status'] != 'completed',
    )) {
      requestsForMeCount += (r['requests'] as List?)?.length ?? 0;
    }

    final List<Widget> pages = [
      _buildHomeTab(),
      ActiveRidesTab(
        rides: allRides,
        myName: widget.userName,
        onRefresh: fetchRides,
        onGoHome: () => setState(() => _currentIndex = 0),
      ),
      RideHistoryScreen(userName: widget.userName),
      ProfileScreen(
        userName: widget.userName,
        userAge: widget.userAge,
        userEmail: widget.userEmail,
      ),
    ];

    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      appBar: AppBar(
        backgroundColor: Theme.of(context).appBarTheme.backgroundColor,
        elevation: 0,
        centerTitle: false,
        titleSpacing: 24,
        title: LayoutBuilder(
          builder: (context, constraints) {
            // We merge both controllers so the builder fires on every tick of
            // whichever controller is currently active.
            return AnimatedBuilder(
              animation: Listenable.merge([
                _startupController,
                _victoryController,
              ]),
              builder: (context, _) {
                final double screenWidth = constraints.maxWidth;
                final double carX;
                final double revealF;

                if (_isVictoryLapRunning) {
                  // ── Victory Lap mode ───────────────────────────────────────
                  // Text is already fully painted — keep revealF at 1.0 the
                  // whole time so "Ridify" never disappears during the lap.
                  carX = _victoryCarX(_victoryController.value, screenWidth);
                  revealF = 1.0;
                } else {
                  // ── Startup / idle mode ────────────────────────────────────
                  final double progress = _startupController.value;
                  carX = _carX(progress, screenWidth);
                  revealF = _revealFactor(progress, carX);
                }

                // ── Title Stack ──────────────────────────────────────────────
                //
                // This Stack is ALWAYS used – even after all animation ends.
                // When frozen at idle: revealF == 1.0 and carX == _parkingX.
                // Because _parkingX is derived from the same TextPainter style
                // as the Text widget, the frozen Stack is pixel-identical to
                // what a static Row would produce – with zero visual jump.
                return Stack(
                  clipBehavior: Clip.none, // car can overhang during Phase 1
                  alignment: Alignment.centerLeft,
                  children: [
                    // ── "Ridify" label – left-to-right reveal ────────────────
                    ClipRect(
                      child: Align(
                        alignment: Alignment.centerLeft,
                        widthFactor: revealF,
                        child: const Text(
                          'Ridify',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 28,
                            fontWeight: FontWeight.bold,
                            letterSpacing: -1,
                          ),
                        ),
                      ),
                    ),

                    // ── Car logo ──────────────────────────────────────────────
                    Transform.translate(
                      offset: Offset(carX, 0),
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(10),
                        child: Image.asset(
                          'assets/iconWithoutBackground.png',
                          width: _kCarW,
                          height: _kCarH,
                          fit: BoxFit.cover,
                        ),
                      ),
                    ),
                  ],
                );
              },
            );
          },
        ),
        actions: [
          if (kAdminEmails.contains(widget.userEmail.toLowerCase()))
            IconButton(
              icon: const Icon(Icons.delete_sweep, color: Colors.redAccent),
              tooltip: 'Admin: Wipe All Rides',
              onPressed: () async {
                final confirmed = await showDialog<bool>(
                  context: context,
                  builder: (ctx) => AlertDialog(
                    title: const Text(
                      '⚠️ Wipe All Rides',
                      style: TextStyle(fontWeight: FontWeight.bold),
                    ),
                    content: const Text(
                      'This wipes the database of all rides and broadcasts a reset to all connected users. Are you sure?',
                    ),
                    actions: [
                      TextButton(
                        onPressed: () => Navigator.pop(ctx, false),
                        child: const Text(
                          'Cancel',
                          style: TextStyle(color: Colors.black),
                        ),
                      ),
                      ElevatedButton(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.red,
                        ),
                        onPressed: () => Navigator.pop(ctx, true),
                        child: const Text(
                          'Yes, Wipe',
                          style: TextStyle(color: Colors.white),
                        ),
                      ),
                    ],
                  ),
                );
                if (confirmed == true && mounted) {
                  await http.delete(
                    Uri.parse("$kBaseUrl/api/rides"),
                    headers: {'x-admin-email': widget.userEmail},
                  );
                  if (context.mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text("All rides wiped!"),
                        backgroundColor: Colors.red,
                      ),
                    );
                  }
                }
              },
            ),
        ],
      ),
      body: pages[_currentIndex],
      bottomNavigationBar: BottomNavigationBar(
        backgroundColor: Theme.of(context).bottomNavigationBarTheme.backgroundColor,
        currentIndex: _currentIndex,
        onTap: (index) {
          // ── Easter Egg ───────────────────────────────────────────────────
          // If the user is already on the Home tab and taps Home again,
          // trigger the Victory Lap instead of a normal nav switch.
          if (index == 0 && _currentIndex == 0) {
            _triggerVictoryLap();
            return; // don't call setState – we're already on index 0
          }
          setState(() => _currentIndex = index);
        },
        type: BottomNavigationBarType.fixed,
        selectedItemColor: Theme.of(context).bottomNavigationBarTheme.selectedItemColor,
        unselectedItemColor: Theme.of(context).bottomNavigationBarTheme.unselectedItemColor,
        items: [
          const BottomNavigationBarItem(icon: Icon(Icons.home), label: "Home"),
          BottomNavigationBarItem(
            icon: Badge(
              isLabelVisible: requestsForMeCount > 0,
              label: Text('$requestsForMeCount'),
              child: const Icon(Icons.directions_car),
            ),
            label: "Rides",
          ),
          const BottomNavigationBarItem(
            icon: Icon(Icons.receipt_long),
            label: "History",
          ),
          const BottomNavigationBarItem(
            icon: Icon(Icons.person),
            label: "Account",
          ),
        ],
      ),
    );
  }

  // ── Home tab ───────────────────────────────────────────────────────────────
  Widget _buildHomeTab() {
    final isDarkTheme = Theme.of(context).brightness == Brightness.dark;
    
    final Color earningsBg = isDarkTheme ? const Color(0xFF162B1D) : Colors.green.shade50;
    final Color earningsBorder = isDarkTheme ? const Color(0xFF23472C) : Colors.green.shade100;
    final Color earningsIconBg = isDarkTheme ? const Color(0xFF1E3F26) : Colors.green.shade100;
    final Color earningsText = isDarkTheme ? Colors.green.shade300 : Colors.green;
    
    final Color spendingBg = isDarkTheme ? const Color(0xFF331A1A) : Colors.red.shade50;
    final Color spendingBorder = isDarkTheme ? const Color(0xFF4D2626) : Colors.red.shade100;
    final Color spendingIconBg = isDarkTheme ? const Color(0xFF402020) : Colors.red.shade100;
    final Color spendingText = isDarkTheme ? Colors.red.shade300 : Colors.red;
    
    final Color safetyBg = isDarkTheme ? const Color(0xFF1A2633) : Colors.blue.shade50;
    final Color safetyBorder = isDarkTheme ? const Color(0xFF26394D) : Colors.blue.shade100;
    final Color safetyText = isDarkTheme ? Colors.blue.shade300 : Colors.blue;
    final Color mainTextColor = isDarkTheme ? Colors.white : Colors.black87;

    double totalEarnings = 0;
    double totalSpending = 0;

    for (final ride in allRides) {
      if (ride['status'] == 'completed') {
        final double fare = double.tryParse(ride['fare'].toString()) ?? 0.0;
        final List boarded = ride['boardedPassengers'] as List? ?? [];

        if (ride['riderName'] == widget.userName) {
          int totalAllocatedSeats = 0;
          for (final p in boarded) {
            final Map? allocations = ride['seatAllocations'] as Map?;
            totalAllocatedSeats += (allocations?[p] as num?)?.toInt() ?? 1;
          }
          totalEarnings += fare * totalAllocatedSeats;
        } else if (boarded.contains(widget.userName)) {
          final Map? allocations = ride['seatAllocations'] as Map?;
          final int mySeats =
              (allocations?[widget.userName] as num?)?.toInt() ?? 1;
          totalSpending += fare * mySeats;
        }
      }
    }

    return SafeArea(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              "Hello, ${widget.userName.split(' ')[0]}! 👋",
              style: TextStyle(
                fontSize: 26, 
                fontWeight: FontWeight.bold,
                color: Theme.of(context).textTheme.bodyLarge?.color,
              ),
            ),
            const SizedBox(height: 25),
            _actionCard(
              "Offer a Ride",
              "Share your journey",
              true,
              () =>
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) =>
                          OfferRideScreen(userName: widget.userName),
                    ),
                  ).then((result) {
                    // ── Success Celebration ────────────────────────────────────
                    // offer_ride_screen.dart pops with 'ride_posted' on success.
                    // Only the person who just posted gets this trigger – no
                    // Socket.IO, no broadcast, purely local navigation result.
                    if (result == 'ride_posted') _triggerVictoryLap();
                    fetchRides();
                  }),
            ),
            const SizedBox(height: 16),
            _actionCard(
              "Find a Ride",
              "Get where you need to go",
              false,
              () => Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => FindRideScreen(userName: widget.userName),
                ),
              ).then((_) => fetchRides()),
            ),
            const SizedBox(height: 30),
            Row(
              children: [
                Expanded(
                  child: Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: earningsBg,
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(color: earningsBorder),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Container(
                          padding: const EdgeInsets.all(10),
                          decoration: BoxDecoration(
                            color: earningsIconBg,
                            shape: BoxShape.circle,
                          ),
                          child: Icon(
                            Icons.arrow_downward,
                            color: earningsText,
                            size: 24,
                          ),
                        ),
                        const SizedBox(height: 12),
                        Text(
                          "Total Earnings",
                          style: TextStyle(
                            color: earningsText,
                            fontWeight: FontWeight.bold,
                            fontSize: 14,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          "₹${totalEarnings.toStringAsFixed(0)}",
                          style: TextStyle(
                            color: mainTextColor,
                            fontSize: 22,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: spendingBg,
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(color: spendingBorder),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Container(
                          padding: const EdgeInsets.all(10),
                          decoration: BoxDecoration(
                            color: spendingIconBg,
                            shape: BoxShape.circle,
                          ),
                          child: Icon(
                            Icons.arrow_upward,
                            color: spendingText,
                            size: 24,
                          ),
                        ),
                        const SizedBox(height: 12),
                        Text(
                          "Total Spending",
                          style: TextStyle(
                            color: spendingText,
                            fontWeight: FontWeight.bold,
                            fontSize: 14,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          "₹${totalSpending.toStringAsFixed(0)}",
                          style: TextStyle(
                            color: mainTextColor,
                            fontSize: 22,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: safetyBg,
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: safetyBorder),
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(Icons.security, color: safetyText, size: 30),
                  const SizedBox(width: 15),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          "Safety First",
                          style: TextStyle(
                            color: safetyText,
                            fontWeight: FontWeight.bold,
                            fontSize: 16,
                          ),
                        ),
                        const SizedBox(height: 5),
                        Text(
                          "Always verify your co-passenger's details and share your ride with a friend.",
                          style: TextStyle(
                            color: mainTextColor,
                            fontSize: 13,
                            height: 1.4,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _actionCard(
    String title,
    String subtitle,
    bool isPrimary,
    VoidCallback onTap,
  ) {
    final isDarkTheme = Theme.of(context).brightness == Brightness.dark;
    
    // In light mode: primary card is black, secondary is white.
    // In dark mode: primary card is dark charcoal, secondary is dark grey (cardColor).
    final bgColor = isPrimary 
      ? (isDarkTheme ? const Color(0xFF2C2C2C) : Colors.black)
      : Theme.of(context).cardColor;
      
    final fgColor = isPrimary 
      ? Colors.white
      : Theme.of(context).textTheme.bodyLarge?.color;
      
    final subColor = isPrimary
      ? Colors.white70
      : (isDarkTheme ? Colors.white54 : Colors.black54);
      
    final borderColor = isDarkTheme ? Colors.transparent : Colors.black12;

    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.all(24),
        decoration: BoxDecoration(
          color: bgColor,
          borderRadius: BorderRadius.circular(24),
          border: Border.all(color: isPrimary ? Colors.transparent : borderColor),
        ),
        child: Row(
          children: [
            Icon(
              isPrimary ? Icons.directions_car : Icons.search,
              color: fgColor,
            ),
            const SizedBox(width: 16),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: TextStyle(
                    color: fgColor,
                    fontWeight: FontWeight.bold,
                    fontSize: 18,
                  ),
                ),
                Text(
                  subtitle,
                  style: TextStyle(
                    color: subColor,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

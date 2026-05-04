import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'dart:async';
import 'package:socket_io_client/socket_io_client.dart' as io;
import 'find_ride_screen.dart';
import 'offer_ride_screen.dart';
import 'live_tracking_screen.dart';
import 'match_status_screen.dart';
import 'profile_screen.dart';
import 'ride_history_screen.dart';
import '../utils.dart';
import '../constants.dart';

// ─────────────────────────────────────────────────────────────────────────────
//  Animation constants
//
//  Timeline (controller 0.0 → 1.0, total = 5 s):
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
//  Key design decisions that eliminate each reported glitch:
//
//  ① Dead start        – _kCarOffLeft = -200 guarantees the car is invisible on
//                        the very first frame (progress == 0 → carX == -200).
//
//  ② Ghost text sync   – revealFactor is keyed to the car's BACK BUMPER (carX),
//                        not the front.  Text only appears where the car has
//                        already passed.  _ridifyTextWidth is measured at runtime
//                        with TextPainter (same style as the Text widget) so the
//                        factor is always exact – no hardcoded guesses.
//
//  ③ Constant exit     – Phase 1 uses Curves.easeIn, which is slowest at the
//                        start and FASTEST at the end.  The car never brakes
//                        while leaving the screen.
//
//  ④ Perfect stop      – Phase 2 uses Curves.easeOut (fast entry → smooth stop).
//                        _parkingX is derived from the same TextPainter width, so
//                        the frozen-Stack final state is pixel-identical to a
//                        static Row.  We NEVER switch rendering modes (no static
//                        Row fallback), so there is no layout-jump at completion.
// ─────────────────────────────────────────────────────────────────────────────
const double _kCarW = 75.0; // car width  – never changes
const double _kCarH = 120.0; // car height – never changes
const double _kCarOffLeft = -125.0; // guaranteed off-screen starting X
const double _kCarGap = 8.0; // px gap between text right-edge and car
const double _kPhase1End = 0.600; // fraction where Phase 1 ends
const double _kTeleportEnd =
    0.560; // fraction where teleport ends / Phase 2 starts

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

class _HomeScreenState extends State<HomeScreen>
    with SingleTickerProviderStateMixin {
  int _currentIndex = 0;
  late io.Socket socket;
  List<dynamic> allRides = [];
  Timer? _pollingTimer;

  // ── Startup animation ──────────────────────────────────────────────────────
  late AnimationController _startupController;
  static bool _hasPlayedStartupAnimation = false;

  /// Exact pixel width of the "Ridify" label, measured once at startup via
  /// TextPainter using the identical TextStyle as the real Text widget.
  late final double _ridifyTextWidth;

  /// X-coordinate of the car's LEFT edge when it is parked (Phase 2 final pos).
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

    // Animation controller – runs linearly; all easing is applied per-phase.
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

    fetchRides();
    initSocket();
    _pollingTimer = Timer.periodic(
      const Duration(seconds: 3),
      (_) => fetchRides(),
    );
  }

  // ── Animation helpers ──────────────────────────────────────────────────────

  /// Returns the car's left-edge X in the AppBar title Stack coordinate space.
  double _carX(double progress, double screenWidth) {
    if (progress < _kPhase1End) {
      // Phase 1: easeIn → starts stationary, accelerates, exits at full speed.
      final double t = progress / _kPhase1End; // normalised 0→1
      final double eased = Curves.easeIn.transform(t);
      // Travel: _kCarOffLeft (-200) → (screenWidth + _kCarW)  [fully off-right]
      return _kCarOffLeft + (screenWidth - _kCarOffLeft + _kCarW) * eased;
    } else if (progress < _kTeleportEnd) {
      // Teleport: snap instantly; car is invisible off the left edge.
      return _kCarOffLeft;
    } else {
      // Phase 2: easeOut → fast entry, smooth deceleration, dead stop.
      final double t = (progress - _kTeleportEnd) / (1.0 - _kTeleportEnd);
      final double eased = Curves.easeOut.transform(t);
      // Travel: _kCarOffLeft (-200) → _parkingX (measured parking spot)
      return _kCarOffLeft + (_parkingX - _kCarOffLeft) * eased;
    }
  }

  /// Fraction of the "Ridify" text that should be visible (0.0 – 1.0).
  ///
  /// Text is revealed ONLY behind the car's back bumper (left edge = carX):
  ///   carX ≤ 0           → 0.0  (nothing visible – dead start, car still left)
  ///   0 < carX < textW   → carX / textW  (partial reveal tracks back bumper)
  ///   carX ≥ textW       → 1.0  (fully revealed)
  /// After Phase 1 the text is locked at 1.0 forever.
  double _revealFactor(double progress, double carX) {
    if (progress >= _kPhase1End) return 1.0;
    return ((carX + 5.0) / _ridifyTextWidth).clamp(0.0, 1.0);
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

    socket.on('ride_ended', (data) {
      fetchRides();
      if (mounted && data != null) {
        final List passengers = data['passengers'] is List
            ? data['passengers']
            : [];
        final List boarded = data['boardedPassengers'] is List
            ? data['boardedPassengers']
            : [];

        final bool wasMyRide =
            data['riderName'] == widget.userName ||
            passengers.contains(widget.userName) ||
            boarded.contains(widget.userName);

        if (wasMyRide) {
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (!mounted) return;
            Navigator.of(context).popUntil((route) => route.isFirst);
            Navigator.of(context).push(
              MaterialPageRoute(builder: (_) => const GlobalCompletionScreen()),
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
      _ActiveRidesTab(
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
      backgroundColor: const Color(0xFFF5F5F5),
      appBar: AppBar(
        backgroundColor: Colors.black,
        elevation: 0,
        centerTitle: false,
        titleSpacing: 24,
        title: LayoutBuilder(
          builder: (context, constraints) {
            return AnimatedBuilder(
              animation: _startupController,
              builder: (context, _) {
                final double progress = _startupController.value;
                final double screenWidth = constraints.maxWidth;
                final double carX = _carX(progress, screenWidth);
                final double revealF = _revealFactor(progress, carX);

                // ── Title Stack ────────────────────────────────────────────
                //
                // This Stack is ALWAYS used – even after the animation ends.
                // When progress == 1.0 it is simply frozen:
                //   revealF == 1.0      → text fully visible
                //   carX    == _parkingX → car at rest beside text
                //
                // Because _parkingX is derived from the same TextPainter style
                // as the Text widget, the frozen Stack is pixel-identical to
                // what a Row would produce – with zero visual jump.
                //
                return Stack(
                  clipBehavior: Clip.none, // car can overhang during Phase 1
                  alignment: Alignment.centerLeft,
                  children: [
                    // ── "Ridify" label – left-to-right reveal ──────────────
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

                    // ── Car logo ───────────────────────────────────────────
                    Transform.translate(
                      offset: Offset(carX, 0),
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(10),
                        child: Image.asset(
                          'assets/iconWithoutBackground.png',
                          width: _kCarW, // fixed – never changes
                          height: _kCarH, // fixed – never changes
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
        backgroundColor: Colors.black,
        currentIndex: _currentIndex,
        onTap: (index) => setState(() => _currentIndex = index),
        type: BottomNavigationBarType.fixed,
        selectedItemColor: Colors.white,
        unselectedItemColor: Colors.white54,
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
              style: const TextStyle(fontSize: 26, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 25),
            _actionCard(
              "Offer a Ride",
              "Share your journey",
              true,
              () => Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => OfferRideScreen(userName: widget.userName),
                ),
              ).then((_) => fetchRides()),
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
                      color: Colors.green.shade50,
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(color: Colors.green.shade100),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Container(
                          padding: const EdgeInsets.all(10),
                          decoration: BoxDecoration(
                            color: Colors.green.shade100,
                            shape: BoxShape.circle,
                          ),
                          child: const Icon(
                            Icons.arrow_downward,
                            color: Colors.green,
                            size: 24,
                          ),
                        ),
                        const SizedBox(height: 12),
                        const Text(
                          "Total Earnings",
                          style: TextStyle(
                            color: Colors.green,
                            fontWeight: FontWeight.bold,
                            fontSize: 14,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          "₹${totalEarnings.toStringAsFixed(0)}",
                          style: const TextStyle(
                            color: Colors.black87,
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
                      color: Colors.red.shade50,
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(color: Colors.red.shade100),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Container(
                          padding: const EdgeInsets.all(10),
                          decoration: BoxDecoration(
                            color: Colors.red.shade100,
                            shape: BoxShape.circle,
                          ),
                          child: const Icon(
                            Icons.arrow_upward,
                            color: Colors.red,
                            size: 24,
                          ),
                        ),
                        const SizedBox(height: 12),
                        const Text(
                          "Total Spending",
                          style: TextStyle(
                            color: Colors.red,
                            fontWeight: FontWeight.bold,
                            fontSize: 14,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          "₹${totalSpending.toStringAsFixed(0)}",
                          style: const TextStyle(
                            color: Colors.black87,
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
                color: Colors.blue.shade50,
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: Colors.blue.shade100),
              ),
              child: const Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(Icons.security, color: Colors.blue, size: 30),
                  SizedBox(width: 15),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          "Safety First",
                          style: TextStyle(
                            color: Colors.blue,
                            fontWeight: FontWeight.bold,
                            fontSize: 16,
                          ),
                        ),
                        SizedBox(height: 5),
                        Text(
                          "Always verify your co-passenger's details and share your ride status with a friend.",
                          style: TextStyle(
                            color: Colors.black87,
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
    bool isDark,
    VoidCallback onTap,
  ) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.all(24),
        decoration: BoxDecoration(
          color: isDark ? Colors.black : Colors.white,
          borderRadius: BorderRadius.circular(24),
          border: isDark ? null : Border.all(color: Colors.black12),
        ),
        child: Row(
          children: [
            Icon(
              isDark ? Icons.directions_car : Icons.search,
              color: isDark ? Colors.white : Colors.black,
            ),
            const SizedBox(width: 16),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: TextStyle(
                    color: isDark ? Colors.white : Colors.black,
                    fontWeight: FontWeight.bold,
                    fontSize: 18,
                  ),
                ),
                Text(
                  subtitle,
                  style: TextStyle(
                    color: isDark ? Colors.white70 : Colors.black54,
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

// ─────────────────────────────────────────────────────────────────────────────
//  Active Rides Tab
// ─────────────────────────────────────────────────────────────────────────────
class _ActiveRidesTab extends StatelessWidget {
  final List<dynamic> rides;
  final String myName;
  final VoidCallback onRefresh;
  final VoidCallback onGoHome;

  const _ActiveRidesTab({
    required this.rides,
    required this.myName,
    required this.onRefresh,
    required this.onGoHome,
  });

  Future<void> _action(String url, BuildContext context) async {
    try {
      final res = await http.patch(Uri.parse(url));
      if (res.statusCode == 200) onRefresh();
    } catch (e) {
      debugPrint("$e");
    }
  }

  Future<void> _cancelOfferedRide(String id, BuildContext context) async {
    try {
      final res = await http.delete(Uri.parse("$kBaseUrl/api/rides/$id"));
      if (res.statusCode == 200) {
        if (!context.mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text("Ride offer cancelled"),
            backgroundColor: Colors.red,
          ),
        );
        onRefresh();
      }
    } catch (e) {
      debugPrint("$e");
    }
  }

  @override
  Widget build(BuildContext context) {
    final List activeRidesOnly = rides
        .where((r) => r['status'] != 'cancelled' && r['status'] != 'completed')
        .toList();

    final List myOfferedRides = activeRidesOnly
        .where((r) => r['riderName'] == myName && r['status'] == 'available')
        .toList();

    final List<Map<String, dynamic>> driverRequests = [];
    for (final r in activeRidesOnly.where((r) => r['riderName'] == myName)) {
      for (final requester in (r['requests'] ?? [])) {
        driverRequests.add({"ride": r, "requester": requester});
      }
    }

    final List myPendingRequests = activeRidesOnly
        .where((r) => (r['requests'] ?? []).contains(myName))
        .toList();

    final List liveRides = activeRidesOnly.where((r) {
      final bool isDriver = r['riderName'] == myName;
      final bool isPassenger = (r['passengers'] ?? []).contains(myName);
      final bool isActive =
          r['status'] == 'accepted' ||
          r['status'] == 'full' ||
          r['status'] == 'started';
      return (isDriver || isPassenger) && isActive;
    }).toList();

    final bool isEmpty =
        myOfferedRides.isEmpty &&
        driverRequests.isEmpty &&
        myPendingRequests.isEmpty &&
        liveRides.isEmpty;

    if (isEmpty) {
      return SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Padding(
              padding: EdgeInsets.all(24.0),
              child: Text(
                "Activity",
                style: TextStyle(fontSize: 28, fontWeight: FontWeight.bold),
              ),
            ),
            Expanded(
              child: Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(
                      Icons.directions_car,
                      size: 80,
                      color: Colors.grey.shade300,
                    ),
                    const SizedBox(height: 16),
                    const Text(
                      "No active rides or requests.",
                      style: TextStyle(
                        color: Colors.grey,
                        fontSize: 18,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      );
    }

    return SafeArea(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              "Activity",
              style: TextStyle(fontSize: 28, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 20),

            // ── Your posted rides ──────────────────────────────────────────
            if (myOfferedRides.isNotEmpty) ...[
              const Text(
                "Your Posted Rides",
                style: TextStyle(
                  fontSize: 16,
                  color: Colors.grey,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 10),
              ...myOfferedRides.map(
                (r) => Card(
                  elevation: 0,
                  color: Colors.white,
                  margin: const EdgeInsets.only(bottom: 15),
                  shape: RoundedRectangleBorder(
                    side: const BorderSide(color: Colors.black12),
                    borderRadius: BorderRadius.circular(15),
                  ),
                  child: ListTile(
                    leading: const Icon(
                      Icons.directions_car,
                      color: Colors.black,
                    ),
                    title: Text(
                      "${formatAddress(r['pickupLocation'])} → ${formatAddress(r['destination'])}",
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 14,
                      ),
                    ),
                    subtitle: Text(
                      "${r['availableSeats']} Seats • ${r['departureTime']}",
                      style: const TextStyle(color: Colors.black54),
                    ),
                    trailing: TextButton(
                      onPressed: () => _cancelOfferedRide(r['_id'], context),
                      child: const Text(
                        "Cancel Offer",
                        style: TextStyle(
                          color: Colors.red,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ),
                ),
              ),
              const Divider(height: 30),
            ],

            // ── Driver – incoming match requests ───────────────────────────
            if (driverRequests.isNotEmpty) ...[
              const Text(
                "Match Requests (Needs Action)",
                style: TextStyle(
                  fontSize: 16,
                  color: Colors.grey,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 10),
              ...driverRequests.map((req) {
                final r = req['ride'];
                final requester = req['requester'];
                return Card(
                  elevation: 0,
                  margin: const EdgeInsets.only(bottom: 15),
                  color: Colors.white,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                    side: BorderSide(color: Colors.grey.shade300),
                  ),
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            CircleAvatar(
                              backgroundColor: Colors.black,
                              child: Text(
                                requester.substring(0, 1).toUpperCase(),
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    "$requester wants to join!",
                                    style: const TextStyle(
                                      fontWeight: FontWeight.bold,
                                      fontSize: 16,
                                    ),
                                  ),
                                  Text(
                                    "${formatAddress(r['pickupLocation'])} → ${formatAddress(r['destination'])}",
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: const TextStyle(
                                      color: Colors.grey,
                                      fontSize: 13,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 16),
                        Row(
                          children: [
                            Expanded(
                              child: OutlinedButton(
                                style: OutlinedButton.styleFrom(
                                  side: const BorderSide(color: Colors.red),
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(10),
                                  ),
                                ),
                                onPressed: () => _action(
                                  "$kBaseUrl/api/rides/decline/${r['_id']}/$requester",
                                  context,
                                ),
                                child: const Text(
                                  "Decline",
                                  style: TextStyle(
                                    color: Colors.red,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: ElevatedButton(
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: Colors.green,
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(10),
                                  ),
                                ),
                                onPressed: () => _action(
                                  "$kBaseUrl/api/rides/accept/${r['_id']}/$requester",
                                  context,
                                ),
                                child: const Text(
                                  "Accept",
                                  style: TextStyle(
                                    color: Colors.white,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                );
              }),
              const Divider(height: 30),
            ],

            // ── Passenger – pending requests ───────────────────────────────
            if (myPendingRequests.isNotEmpty) ...[
              const Text(
                "Pending Requests (Rider)",
                style: TextStyle(
                  fontSize: 16,
                  color: Colors.grey,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 10),
              ...myPendingRequests.map(
                (r) => GestureDetector(
                  onTap: () => Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => MatchStatusScreen(
                        driverName: r['riderName'],
                        rideId: r['_id'],
                        riderName: myName,
                      ),
                    ),
                  ),
                  child: Card(
                    elevation: 0,
                    color: Colors.white,
                    margin: const EdgeInsets.only(bottom: 15),
                    shape: RoundedRectangleBorder(
                      side: const BorderSide(color: Colors.black12),
                      borderRadius: BorderRadius.circular(15),
                    ),
                    child: ListTile(
                      leading: const CircularProgressIndicator(
                        strokeWidth: 2,
                        color: Colors.black,
                      ),
                      title: Text(
                        "Waiting for ${r['riderName']}",
                        style: const TextStyle(fontWeight: FontWeight.bold),
                      ),
                      subtitle: const Text("Tap to view status"),
                      trailing: TextButton(
                        onPressed: () => _action(
                          "$kBaseUrl/api/rides/decline/${r['_id']}/$myName",
                          context,
                        ),
                        child: const Text(
                          "Cancel",
                          style: TextStyle(
                            color: Colors.red,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ),
              const Divider(height: 30),
            ],

            // ── Live / ongoing rides ───────────────────────────────────────
            if (liveRides.isNotEmpty) ...[
              const Text(
                "Ongoing Rides",
                style: TextStyle(
                  fontSize: 16,
                  color: Colors.grey,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 10),
              ...liveRides.map(
                (r) => Card(
                  elevation: 4,
                  shadowColor: Colors.black26,
                  color: Colors.black,
                  margin: const EdgeInsets.only(bottom: 15),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: ListTile(
                    contentPadding: const EdgeInsets.all(16),
                    leading: const Icon(
                      Icons.map,
                      color: Colors.white,
                      size: 30,
                    ),
                    title: Text(
                      r['status'] == 'started' ? "In Progress" : "Arriving",
                      style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    subtitle: Text(
                      r['riderName'] == myName
                          ? "You are Driving"
                          : "Riding with ${r['riderName']}",
                      style: const TextStyle(color: Colors.white70),
                    ),
                    trailing: ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.white,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10),
                        ),
                      ),
                      onPressed: () =>
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (_) => LiveTrackingScreen(
                                isDriver: r['riderName'] == myName,
                                isAlreadyAccepted: true,
                                rideId: r['_id'],
                                myName: myName,
                                otherUserName: r['riderName'] == myName
                                    ? "Group"
                                    : r['riderName'],
                              ),
                            ),
                          ).then((_) {
                            onRefresh();
                            onGoHome();
                          }),
                      child: const Text(
                        "Open Map",
                        style: TextStyle(
                          color: Colors.black,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
//  Global Completion Screen
// ─────────────────────────────────────────────────────────────────────────────
class GlobalCompletionScreen extends StatefulWidget {
  const GlobalCompletionScreen({super.key});

  @override
  State<GlobalCompletionScreen> createState() => _GlobalCompletionScreenState();
}

class _GlobalCompletionScreenState extends State<GlobalCompletionScreen> {
  int countdown = 5;
  late Timer _timer;

  @override
  void initState() {
    super.initState();
    _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (countdown <= 1) {
        timer.cancel();
        if (mounted) Navigator.pop(context);
      } else {
        if (mounted) setState(() => countdown--);
      }
    });
  }

  @override
  void dispose() {
    _timer.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.green,
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(
              Icons.check_circle_outline,
              color: Colors.white,
              size: 100,
            ),
            const SizedBox(height: 20),
            const Text(
              "Ride Completed!",
              style: TextStyle(
                color: Colors.white,
                fontSize: 32,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 10),
            Text(
              "Returning to home in $countdown...",
              style: const TextStyle(color: Colors.white70, fontSize: 18),
            ),
          ],
        ),
      ),
    );
  }
}

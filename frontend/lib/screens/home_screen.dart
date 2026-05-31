import 'package:flutter/material.dart';
import 'dart:async';
import '../core/socket_service.dart';
import 'find_ride_screen.dart';
import 'offer_ride_screen.dart';
import 'profile_screen.dart';
import 'ride_history_screen.dart';
import '../widgets/active_rides_tab.dart';

import '../services/ride_service.dart';
import '../services/token_service.dart';
import '../widgets/home/action_card.dart';
import '../widgets/home/earnings_display.dart';
import '../widgets/home/safety_banner.dart';
import '../widgets/home/ridify_app_bar_title.dart';
import '../main.dart';
import 'rider_completing_screen.dart';
import 'driver_completing_screen.dart';
import 'admin_panel_screen.dart';
import 'login_screen.dart';

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
// Animation parameters are mostly encapsulated in RidifyAppBarTitle.

class HomeScreen extends StatefulWidget {
  final String userName;
  final String userAge;
  final String userEmail;
  final bool isAdmin;

  const HomeScreen({
    super.key,
    this.userName = "Unknown",
    this.userAge = "18",
    this.userEmail = "email@example.com",
    this.isAdmin = false,
  });

  static void resetStartupAnimation() {
    _HomeScreenState._hasPlayedStartupAnimation = false;
  }

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

// TickerProviderStateMixin (not Single) because we now have TWO controllers.
class _HomeScreenState extends State<HomeScreen> with TickerProviderStateMixin {
  int _currentIndex = 0;
  List<dynamic> allRides = [];


  // ── Easter Egg state ───────────────────────────────────────────────────────
  int _homeTapCount = 0;
  DateTime _lastHomeTapTime = DateTime.now();

  // ── Startup animation ──────────────────────────────────────────────────────
  late AnimationController _startupController;
  static bool _hasPlayedStartupAnimation = false;

  // ── Victory Lap animation ──────────────────────────────────────────────────
  late AnimationController _victoryController;

  /// True while the victory lap car is in motion.
  /// Extra taps are ignored while this is true (anti-spam guard).
  bool _isVictoryLapRunning = false;
  
  final List<MapEntry<String, void Function(dynamic)>> _socketListeners = [];
  
  void _onSocket(String event, void Function(dynamic) handler) {
    SocketService().on(event, handler);
    _socketListeners.add(MapEntry(event, handler));
  }

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
    _parkingX = _ridifyTextWidth + 8.0; // 8.0 is the gap

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
    _initSocket();
  }

  // ── Animation helpers (extracted to RidifyAppBarTitle) ─────────


  // ── Victory Lap trigger ────────────────────────────────────────────────────

  void _handleEasterEggTap() {
    final now = DateTime.now();
    if (now.difference(_lastHomeTapTime).inMilliseconds < 500) {
      _homeTapCount++;
    } else {
      _homeTapCount = 1;
    }
    _lastHomeTapTime = now;
    
    if (_homeTapCount >= 3) {
      _triggerVictoryLap();
      _homeTapCount = 0;
    }
  }

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
  void _upsertRide(Map<String, dynamic> rideData) {
    if (!mounted) return;
    setState(() {
      final newList = List<dynamic>.from(allRides);
      final idx = newList.indexWhere((r) => r['_id'].toString() == rideData['_id'].toString());
      if (idx >= 0) {
        newList[idx] = rideData;
      } else {
        newList.add(rideData);
      }
      allRides = newList;
    });
  }

  Future<void> fetchRides() async {
    try {
      final rides = await RideService.getAllRides();
      if (mounted) setState(() => allRides = rides);
    } catch (e) {
      debugPrint("❌ Fetch Error: $e");
    }
  }

  Future<void> _initSocket() async {
    final accessToken = await TokenService.getAccessToken();
    if (accessToken == null) return; // Not logged in
    
    final socketService = SocketService();
    socketService.registerUser(widget.userEmail, accessToken); // Pass token
    // socket variable removed

    // Direct state updates — no re-fetch needed
    _onSocket('connect', (_) {
      fetchRides();
    });

    _onSocket('new_ride_request', (data) {
      if (data != null && data['ride'] != null) _upsertRide(Map<String, dynamic>.from(data['ride']));
    });
    _onSocket('all_rides_wiped', (_) {
      if (mounted) setState(() => allRides = []);
    });
    _onSocket('ride_accepted', (data) {
      if (data != null && data['ride'] != null) _upsertRide(Map<String, dynamic>.from(data['ride']));
    });
    _onSocket('ride_cancelled', (data) {
      if (data != null && data['ride'] != null) _upsertRide(Map<String, dynamic>.from(data['ride']));
    });
    _onSocket('driver_arrived', (data) {
      if (data != null && data['ride'] != null) _upsertRide(Map<String, dynamic>.from(data['ride']));
    });
    _onSocket('passenger_boarded', (data) {
      if (data != null && data['ride'] != null) _upsertRide(Map<String, dynamic>.from(data['ride']));
    });
    _onSocket('passenger_dropped', (data) {
      if (data != null && data['ride'] != null) {
        final ride = Map<String, dynamic>.from(data['ride']);
        _upsertRide(ride);
        final droppedUser = data['riderName']?.toString().toLowerCase().trim();
        final myEmailLower = widget.userEmail.toLowerCase().trim();
        if (droppedUser == myEmailLower) {
          final rideId = ride['rideId'] ?? ride['_id'];
          if (rideId != null && !navigatedRides.contains(rideId)) {
            navigatedRides.add(rideId);
            if (navigatorKey.currentState != null) {
              int fare = (data['fare'] as num?)?.toInt() ?? 0;
              navigatorKey.currentState!.push(MaterialPageRoute(
                builder: (_) => RiderCompletingScreen(
                  isDriver: false, rideId: rideId, myName: widget.userName, myEmail: widget.userEmail, fareAmount: fare, initialRideData: ride
                )
              ));
            }
          }
        }
      }
    });
    _onSocket('passenger_kicked', (data) {
      if (data != null && data['ride'] != null) {
        final ride = Map<String, dynamic>.from(data['ride']);
        _upsertRide(ride);
        final kickedUser = data['kickedUser']?.toString().toLowerCase().trim();
        final myEmailLower = widget.userEmail.toLowerCase().trim();
        if (kickedUser == myEmailLower) {
          final rideId = ride['rideId'] ?? ride['_id'];
          if (rideId != null && !navigatedRides.contains(rideId)) {
            navigatedRides.add(rideId);
            final ctx = navigatorKey.currentContext;
            if (ctx != null) {
              showDialog(
                context: ctx, barrierDismissible: false, builder: (_) => AlertDialog(
                  title: const Text("Removed from Ride"), content: const Text("The driver has removed you from this ride."),
                  actions: [TextButton(onPressed: () { Navigator.pop(ctx); Navigator.popUntil(ctx, (route) => route.isFirst); }, child: const Text("OK", style: TextStyle(color: Colors.red, fontWeight: FontWeight.bold)))],
                )
              );
            }
          }
        }
      }
    });
    _onSocket('passenger_paid', (data) {
      if (data != null && data['ride'] != null) _upsertRide(Map<String, dynamic>.from(data['ride']));
    });
    _onSocket('ride_started', (data) {
      if (data != null && data['ride'] != null) _upsertRide(Map<String, dynamic>.from(data['ride']));
    });

    _onSocket('ride_ended', (data) {
      if (data != null && data['ride'] != null) {
        final ride = Map<String, dynamic>.from(data['ride']);
        _upsertRide(ride);
        final driverEmail = ride['riderEmail']?.toString().toLowerCase().trim();
        final myEmailLower = widget.userEmail.toLowerCase().trim();
        if (driverEmail == myEmailLower) {
          final rideId = ride['rideId'] ?? ride['_id'];
          if (rideId != null && !navigatedRides.contains(rideId)) {
            navigatedRides.add(rideId);
            if (navigatorKey.currentState != null) {
              navigatorKey.currentState!.push(MaterialPageRoute(
                builder: (_) => DriverCompletingScreen(rideId: rideId, initialRideData: ride)
              ));
            }
          }
        }
      }
      fetchRides();
    });

    _onSocket('database_wiped', (data) {
      if (mounted) {
        String? excludedEmail;
        if (data is Map) {
          excludedEmail = data['excludedEmail']?.toString().toLowerCase().trim();
        } else if (data is List && data.isNotEmpty && data.first is Map) {
          excludedEmail = data.first['excludedEmail']?.toString().toLowerCase().trim();
        }
        
        final myEmailLower = widget.userEmail.toLowerCase().trim();
        
        if (excludedEmail != null && myEmailLower == excludedEmail) {
          // If we are the admin, just clear rides from the local list but stay on current screen
          setState(() => allRides = []);
        } else {
          TokenService.clearTokens().then((_) {
            if (navigatorKey.currentState != null) {
              navigatorKey.currentState!.pushAndRemoveUntil(
                MaterialPageRoute(builder: (_) => const LoginScreen()),
                (route) => false,
              );
            }
          });
        }
      }
    });
  }

  @override
  void dispose() {
    _startupController.dispose();
    _victoryController.dispose();
    // Clean up only our specific listeners
    final socketService = SocketService();
    for (final entry in _socketListeners) {
      socketService.off(entry.key, entry.value);
    }
    _socketListeners.clear();

    super.dispose();
  }

  // ── Build ──────────────────────────────────────────────────────────────────
  @override
  Widget build(BuildContext context) {
    int requestsForMeCount = 0;
    for (final r in allRides.where(
      (r) =>
          r['riderEmail'] == widget.userEmail &&
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
        myEmail: widget.userEmail,
        onRefresh: fetchRides,
        onGoHome: () => setState(() => _currentIndex = 0),
      ),
      RideHistoryScreen(userName: widget.userName, userEmail: widget.userEmail, allRides: allRides),
      ProfileScreen(
        userName: widget.userName,
        userAge: widget.userAge,
        userEmail: widget.userEmail,
        isAdmin: widget.isAdmin,
      ),
    ];

    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      appBar: AppBar(
        backgroundColor: Theme.of(context).appBarTheme.backgroundColor,
        elevation: 0,
        centerTitle: false,
        titleSpacing: 24,
        title: RidifyAppBarTitle(
          startupController: _startupController,
          victoryController: _victoryController,
          isVictoryLapRunning: _isVictoryLapRunning,
          ridifyTextWidth: _ridifyTextWidth,
          parkingX: _parkingX,
          onCarTapped: _handleEasterEggTap,
        ),
        actions: [
          if (widget.isAdmin)
            IconButton(
              icon: const Icon(Icons.admin_panel_settings, color: Colors.amber),
              tooltip: 'Admin Panel',
              onPressed: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => const AdminPanelScreen()),
                );
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
          // If the user is already on the Home tab and taps Home rapidly 3 times,
          // trigger the Victory Lap.
          if (index == 0 && _currentIndex == 0) {
            _handleEasterEggTap();
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
    double totalEarnings = 0;
    double totalSpending = 0;

    final lowerUserEmail = widget.userEmail.trim().toLowerCase();
    
    for (final ride in allRides) {
      if (ride['status'] == 'completed') {
        final List dropped = (ride['droppedPassengers'] as List?)?.map((e) => e.toString().toLowerCase()).toList() ?? [];
        final Map? riderDetails = ride['riderDetails'] as Map?;
        final double baseFare = double.tryParse(ride['fare'].toString()) ?? 0.0;

        if (ride['riderEmail']?.toString().toLowerCase().trim() == lowerUserEmail || ride['riderEmail'] == widget.userEmail) {
          // Driver earnings
          for (final p in dropped) {
            if (riderDetails != null && riderDetails[p] != null) {
              totalEarnings += (riderDetails[p]['fare'] as num?)?.toDouble() ?? 0.0;
            } else {
              final Map? allocations = ride['seatAllocations'] as Map?;
              final int seats = (allocations?[p] as num?)?.toInt() ?? 1;
              totalEarnings += baseFare * seats;
            }
          }
        } else if (dropped.contains(lowerUserEmail)) {
          // Passenger spending
          final uemailDot = lowerUserEmail.replaceAll('.', '_dot_');
          final details = riderDetails?[lowerUserEmail] ?? riderDetails?[uemailDot];
          
          if (details != null && details['fare'] != null) {
            totalSpending += (details['fare'] as num?)?.toDouble() ?? 0.0;
          } else {
            final Map? allocations = ride['seatAllocations'] as Map?;
            final int mySeats = (allocations?[lowerUserEmail] as num?)?.toInt() ?? 1;
            totalSpending += baseFare * mySeats;
          }
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
            ActionCard(
              title: "Offer a Ride",
              subtitle: "Share your journey",
              isPrimary: true,
              onTap: () =>
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) =>
                          OfferRideScreen(userName: widget.userName, userEmail: widget.userEmail),
                    ),
                  ).then((result) {
                    if (result == 'ride_posted') _triggerVictoryLap();
                    fetchRides();
                  }),
            ),
            const SizedBox(height: 16),
            ActionCard(
              title: "Find a Ride",
              subtitle: "Get where you need to go",
              isPrimary: false,
              onTap: () => Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => FindRideScreen(userName: widget.userName, userEmail: widget.userEmail),
                ),
              ).then((_) => fetchRides()),
            ),
            const SizedBox(height: 30),
            EarningsDisplay(
              totalEarnings: totalEarnings,
              totalSpending: totalSpending,
            ),
            const SizedBox(height: 16),
            const SafetyBanner(),
          ],
        ),
      ),
    );
  }

}

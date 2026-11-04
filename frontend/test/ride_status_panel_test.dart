import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ridify/widgets/live_tracking/ride_status_panel.dart';

Map<String, dynamic> _ride() => {
      '_id': 'r1',
      'riderEmail': 'driver@bmsce.ac.in',
      'pickupLocation': 'BMSCE, Basavanagudi, Bengaluru',
      'destination': 'Kempegowda Airport, Devanahalli, Bengaluru',
      'departureTime': 'Today at 6:30 PM',
      'status': 'accepted',
      'totalSeats': 4,
      'routePreference': 'flexible',
      'passengers': ['p1@bmsce.ac.in', 'p2@bmsce.ac.in'],
      'boardedPassengers': [],
      'droppedPassengers': [],
      'arrivedAt': [],
      'riderDetails': {
        'p1@bmsce.ac.in': {'riderName': 'Prerit', 'seats': 1, 'pickupLocation': 'Jayanagar, Bengaluru', 'destination': 'Hebbal, Bengaluru'},
        'p2@bmsce.ac.in': {'riderName': 'Saket', 'seats': 1, 'pickupLocation': 'Banashankari, Bengaluru', 'destination': 'Yelahanka, Bengaluru'},
      },
    };

Widget _panel({required bool isDriver, required bool fullScreen, String me = 'p1@bmsce.ac.in', Future<void> Function()? onRefresh}) {
  final ride = _ride();
  final panel = RideStatusPanel(
          fullScreen: fullScreen,
          isDriver: isDriver,
          isAccepted: true,
          isStarted: !fullScreen,
          iHaveBoarded: false,
          iAmArrived: false,
          iAmDropped: false,
          canEnd: false,
          otherUserName: 'Priyanshu',
          statusText: isDriver ? 'Ready to Start' : 'Waiting for driver',
          currentlyOccupied: 0,
          totalCap: 4,
          rideData: ride,
          activePassengers: ride['passengers'] as List,
          myName: 'Me',
          myEmail: isDriver ? 'driver@bmsce.ac.in' : me,
          rideId: 'r1',
          processingActionId: null,
          onBoardRide: () {},
          onStartRide: () {},
          onEndRide: () {},
          onDropOffPassenger: (_) {},
          onConfirmKickPassenger: (_) {},
          onDriverArriveForPassenger: (_) {},
        );
  return MaterialApp(
    home: Scaffold(
      body: onRefresh != null
          ? RefreshIndicator(onRefresh: onRefresh, child: panel)
          : Stack(children: [panel]),
    ),
  );
}

void main() {
  testWidgets('driver pre-start panel is full screen with Start and passengers', (tester) async {
    await tester.pumpWidget(_panel(isDriver: true, fullScreen: true));
    expect(find.byType(DraggableScrollableSheet), findsNothing);
    expect(find.text('Start'), findsOneWidget);
    expect(find.textContaining('Live location is off'), findsOneWidget);
    expect(find.text('Prerit'), findsOneWidget);
  });

  testWidgets('passenger pre-start panel shows only their own pickup and drop', (tester) async {
    await tester.pumpWidget(_panel(isDriver: false, fullScreen: true));
    expect(find.byType(DraggableScrollableSheet), findsNothing);
    expect(find.text('YOUR PICKUP'), findsOneWidget);
    expect(find.text('Jayanagar, Bengaluru'), findsOneWidget);
    expect(find.text('Banashankari, Bengaluru'), findsNothing);
    expect(find.text('1 other rider'), findsOneWidget);
  });

  testWidgets('after start the panel is a draggable sheet over the map', (tester) async {
    await tester.pumpWidget(_panel(isDriver: true, fullScreen: false));
    expect(find.byType(DraggableScrollableSheet), findsOneWidget);
    expect(find.textContaining('Live location is off'), findsNothing);
  });

  for (final kind in [PointerDeviceKind.touch, PointerDeviceKind.mouse]) {
    testWidgets('pull-to-refresh on the full-screen panel completes and springs back ($kind)', (tester) async {
      int refreshes = 0;
      await tester.pumpWidget(_panel(
        isDriver: false,
        fullScreen: true,
        onRefresh: () async { refreshes++; },
      ));
      final header = find.text('Priyanshu');
      final before = tester.getTopLeft(header);

      await tester.fling(find.byType(ListView), const Offset(0, 400), 1200, deviceKind: kind);
      await tester.pumpAndSettle();

      expect(refreshes, 1);
      expect(find.byType(RefreshProgressIndicator), findsNothing);
      expect(tester.getTopLeft(header), before); // no stuck gap above the panel
    });
  }
}

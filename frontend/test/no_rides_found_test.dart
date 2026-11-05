import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ridify/widgets/find_ride/no_rides_found.dart';

Widget _host(Widget child, {bool dark = false}) => MaterialApp(
      theme: dark ? ThemeData.dark() : ThemeData.light(),
      home: Scaffold(body: Center(child: SingleChildScrollView(child: child))),
    );

void main() {
  for (final dark in [false, true]) {
    testWidgets('no rides on route: message, illustration and actions (dark=$dark)', (tester) async {
      tester.view.physicalSize = const Size(360, 780);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      var changed = 0;
      await tester.pumpWidget(_host(
        NoRidesFound(
          onChangeSearch: () => changed++,
        ),
        dark: dark,
      ));
      await tester.pumpAndSettle();

      expect(find.text('No rides on this route yet'), findsOneWidget);
      expect(find.byWidgetPredicate((w) => w is CustomPaint && w.painter is EmptyRoadPainter), findsOneWidget);

      await tester.tap(find.text('Change search'));
      expect(changed, 1);

      expect(find.text('Check again'), findsNothing);
      expect(tester.takeException(), isNull);
    });
  }

  testWidgets('filters hide rides: offers to clear filters', (tester) async {
    var cleared = 0;
    await tester.pumpWidget(_host(NoRidesFound(
      filtersHideRides: true,
      vehicleFilter: 'Bike',
      onClearFilters: () => cleared++,
    )));
    await tester.pumpAndSettle();

    expect(find.text('No bike rides right now'), findsOneWidget);
    expect(find.text('Change search'), findsNothing);
    await tester.tap(find.text('Clear filters'));
    expect(cleared, 1);
  });
}

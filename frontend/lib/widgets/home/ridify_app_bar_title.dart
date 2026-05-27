import 'package:flutter/material.dart';

const double _kCarW = 75.0; // car width  – never changes
const double _kCarH = 120.0; // car height – never changes
const double _kCarOffLeft = -125.0; // guaranteed off-screen starting X
const double _kPhase1End = 0.600; // startup: fraction where Phase 1 ends
const double _kTeleportEnd = 0.560; // startup: fraction where teleport ends / Phase 2 starts

// Victory lap phase boundaries
const double _kVPhase1End = 0.450; // fraction where car exits right
const double _kVTeleportEnd = 0.500; // fraction where teleport snaps / Phase B starts

class RidifyAppBarTitle extends StatelessWidget {
  final AnimationController startupController;
  final AnimationController victoryController;
  final bool isVictoryLapRunning;
  final double ridifyTextWidth;
  final double parkingX;
  final VoidCallback? onCarTapped;

  const RidifyAppBarTitle({
    super.key,
    required this.startupController,
    required this.victoryController,
    required this.isVictoryLapRunning,
    required this.ridifyTextWidth,
    required this.parkingX,
    this.onCarTapped,
  });

  static double _carX(double progress, double screenWidth, double parkingX) {
    if (progress < _kPhase1End) {
      final double t = progress / _kPhase1End;
      final double eased = Curves.easeIn.transform(t);
      return _kCarOffLeft + (screenWidth - _kCarOffLeft + _kCarW) * eased;
    } else if (progress < _kTeleportEnd) {
      return _kCarOffLeft;
    } else {
      final double t = (progress - _kTeleportEnd) / (1.0 - _kTeleportEnd);
      final double eased = Curves.easeOut.transform(t);
      return _kCarOffLeft + (parkingX - _kCarOffLeft) * eased;
    }
  }

  static double _victoryCarX(double progress, double screenWidth, double parkingX) {
    if (progress < _kVPhase1End) {
      final double t = progress / _kVPhase1End;
      final double eased = Curves.easeIn.transform(t);
      return parkingX + (screenWidth + _kCarW - parkingX) * eased;
    } else if (progress < _kVTeleportEnd) {
      return _kCarOffLeft;
    } else {
      final double t = (progress - _kVTeleportEnd) / (1.0 - _kVTeleportEnd);
      final double eased = Curves.easeOut.transform(t);
      return _kCarOffLeft + (parkingX - _kCarOffLeft) * eased;
    }
  }

  static double _revealFactor(double progress, double carX, double ridifyTextWidth) {
    if (progress >= _kPhase1End) return 1.0;
    return ((carX + 5.0) / ridifyTextWidth).clamp(0.0, 1.0);
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        return AnimatedBuilder(
          animation: Listenable.merge([
            startupController,
            victoryController,
          ]),
          builder: (context, _) {
            final double screenWidth = constraints.maxWidth;
            final double carX;
            final double revealF;

            if (isVictoryLapRunning) {
              carX = _victoryCarX(victoryController.value, screenWidth, parkingX);
              revealF = 1.0;
            } else {
              final double progress = startupController.value;
              carX = _carX(progress, screenWidth, parkingX);
              revealF = _revealFactor(progress, carX, ridifyTextWidth);
            }

            return Stack(
              clipBehavior: Clip.none,
              alignment: Alignment.centerLeft,
              children: [
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
                Transform.translate(
                  offset: Offset(carX, 0),
                  child: GestureDetector(
                    onTap: onCarTapped,
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
                ),
              ],
            );
          },
        );
      },
    );
  }
}

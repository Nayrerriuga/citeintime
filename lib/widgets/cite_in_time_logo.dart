import 'dart:math' as math;
import 'package:flutter/material.dart';
import '../theme/grand_line_theme.dart';

class CiteInTimeLogoHeader extends StatelessWidget {
  final Animation<double> floatAnimation;
  final Animation<double> compassAnimation;

  const CiteInTimeLogoHeader({
    super.key,
    required this.floatAnimation,
    required this.compassAnimation,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        // Three Institution Crests Row (NEMSU, CITE Day, DCS)
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            _buildCrestBadge('assets/images/nemsuga.png', size: 54),
            const SizedBox(width: 14),
            _buildCrestBadge('assets/images/citeday.png', size: 60),
            const SizedBox(width: 14),
            _buildCrestBadge('assets/images/dcslogo.jpg', size: 54),
          ],
        ),
        const SizedBox(height: 18),

        // Floating CiteInTime Log Pose + Straw Hat Center Emblem
        AnimatedBuilder(
          animation: Listenable.merge([floatAnimation, compassAnimation]),
          builder: (context, _) {
            return Transform.translate(
              offset: Offset(0, floatAnimation.value),
              child: Center(
                child: Stack(
                  alignment: Alignment.center,
                  children: [
                    Container(
                      width: 112,
                      height: 112,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        gradient: RadialGradient(
                          colors: [
                            GrandLinePalette.treasureGold.withValues(
                              alpha: 0.35,
                            ),
                            Colors.transparent,
                          ],
                        ),
                      ),
                    ),
                    Transform.rotate(
                      angle: compassAnimation.value * 2 * math.pi,
                      child: Container(
                        width: 96,
                        height: 96,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          border: Border.all(
                            color: GrandLinePalette.treasureGold.withValues(
                              alpha: 0.65,
                            ),
                            width: 2,
                          ),
                        ),
                        child: CustomPaint(painter: CompassTicksPainter()),
                      ),
                    ),
                    Container(
                      width: 76,
                      height: 76,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: GrandLinePalette.oceanDeep,
                        border: Border.all(
                          color: GrandLinePalette.treasureGold,
                          width: 2.5,
                        ),
                        boxShadow: [
                          BoxShadow(
                            color: GrandLinePalette.treasureGold.withValues(
                              alpha: 0.3,
                            ),
                            blurRadius: 14,
                          ),
                        ],
                      ),
                      child: CustomPaint(painter: StrawHatLogoPainter()),
                    ),
                  ],
                ),
              ),
            );
          },
        ),
        const SizedBox(height: 14),

        // App Title: CiteInTime
        ShaderMask(
          shaderCallback: (bounds) => const LinearGradient(
            colors: [
              Color(0xFFFFE082),
              GrandLinePalette.treasureGold,
              Color(0xFFFF8F00),
            ],
          ).createShader(bounds),
          child: const Text(
            'CiteInTime',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 34,
              fontWeight: FontWeight.w900,
              letterSpacing: 1.5,
              color: Colors.white,
            ),
          ),
        ),
        const SizedBox(height: 4),
        Text(
          'DCS ATTENDANCE by Jeolong',
          textAlign: TextAlign.center,
          style: TextStyle(
            fontSize: 10.5,
            fontWeight: FontWeight.w700,
            letterSpacing: 1.4,
            color: GrandLinePalette.treasureGold.withValues(alpha: 0.85),
          ),
        ),
      ],
    );
  }

  Widget _buildCrestBadge(String assetPath, {required double size}) {
    return Container(
      width: size,
      height: size,
      padding: const EdgeInsets.all(2.5),
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: GrandLinePalette.oceanMid,
        border: Border.all(
          color: GrandLinePalette.treasureGold.withValues(alpha: 0.75),
          width: 1.8,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.4),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: ClipOval(child: Image.asset(assetPath, fit: BoxFit.cover)),
    );
  }
}

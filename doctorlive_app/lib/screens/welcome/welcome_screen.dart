import 'package:flutter/material.dart';

import '../../config/app_theme.dart';
import '../auth/login_screen.dart';

/// First screen shown when DoctorLive starts.
class WelcomeScreen extends StatelessWidget {
  const WelcomeScreen({super.key});

  void _openNextScreen(BuildContext context) {
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (BuildContext context) => const LoginScreen(),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: LayoutBuilder(
        builder: (BuildContext context, BoxConstraints constraints) {
          final bool compact = constraints.maxWidth < 820;

          return Stack(
            fit: StackFit.expand,
            children: <Widget>[
              const CustomPaint(painter: _WelcomeBackgroundPainter()),
              const Positioned(
                left: -45,
                top: 280,
                child: _MedicalPlus(size: 125, opacity: 0.12),
              ),
              const Positioned(
                right: 110,
                top: 130,
                child: _MedicalPlus(size: 72, opacity: 0.13),
              ),
              const Positioned(
                right: 70,
                bottom: 185,
                child: _MedicalPlus(size: 110, opacity: 0.13),
              ),
              if (compact)
                _MobileLayout(onGetStarted: () => _openNextScreen(context))
              else
                _DesktopLayout(
                  screenWidth: constraints.maxWidth,
                  screenHeight: constraints.maxHeight,
                  onGetStarted: () => _openNextScreen(context),
                ),
            ],
          );
        },
      ),
    );
  }
}

class _DesktopLayout extends StatelessWidget {
  const _DesktopLayout({
    required this.screenWidth,
    required this.screenHeight,
    required this.onGetStarted,
  });

  final double screenWidth;
  final double screenHeight;
  final VoidCallback onGetStarted;

  @override
  Widget build(BuildContext context) {
    final double contentWidth = screenWidth > 1500 ? 1160 : screenWidth - 180;
    final double logoPanelWidth = contentWidth < 900 ? 330 : 430;
    final double textPanelWidth = contentWidth - logoPanelWidth - 70;

    return SafeArea(
      child: Stack(
        fit: StackFit.expand,
        children: <Widget>[
          const Positioned(left: 64, top: 44, child: _BrandHeader()),
          Align(
            alignment: const Alignment(0, -0.02),
            child: SizedBox(
              width: contentWidth,
              height: screenHeight < 760 ? screenHeight - 150 : 600,
              child: Row(
                mainAxisSize: MainAxisSize.min,
                mainAxisAlignment: MainAxisAlignment.center,
                children: <Widget>[
                  SizedBox(width: logoPanelWidth, child: const _LargeBrand()),
                  const SizedBox(width: 70),
                  SizedBox(
                    width: textPanelWidth,
                    child: _WelcomeCopy(
                      headlineSize: screenWidth < 1150 ? 39 : 52,
                      onGetStarted: onGetStarted,
                    ),
                  ),
                ],
              ),
            ),
          ),
          const Positioned(
            left: 64,
            bottom: 36,
            child: Text(
              'Developed by Faisal Majeed',
              style: TextStyle(
                color: Color(0xFFD7FFFA),
                fontSize: 14,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _MobileLayout extends StatelessWidget {
  const _MobileLayout({required this.onGetStarted});

  final VoidCallback onGetStarted;

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(24, 24, 24, 28),
        child: ConstrainedBox(
          constraints: BoxConstraints(
            minHeight: MediaQuery.sizeOf(context).height - 76,
          ),
          child: Column(
            children: <Widget>[
              const Align(
                alignment: Alignment.centerLeft,
                child: _BrandHeader(compact: true),
              ),
              const SizedBox(height: 55),
              const _LargeBrand(compact: true),
              const SizedBox(height: 38),
              const _WelcomeCopy(headlineSize: 35, centered: true),
              const SizedBox(height: 42),
              Align(
                alignment: Alignment.centerRight,
                child: _GetStartedButton(onPressed: onGetStarted),
              ),
              const SizedBox(height: 28),
              const Text(
                'Developed by Faisal Majeed',
                style: TextStyle(color: Color(0xFFD7FFFA), fontSize: 13),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _BrandHeader extends StatelessWidget {
  const _BrandHeader({this.compact = false});

  final bool compact;

  @override
  Widget build(BuildContext context) {
    final double size = compact ? 46 : 56;

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: <Widget>[
        Container(
          width: size,
          height: size,
          padding: const EdgeInsets.all(6),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(15),
          ),
          child: _LogoImage(fallbackSize: compact ? 28 : 34),
        ),
        const SizedBox(width: 14),
        Text(
          'DoctorLive',
          style: TextStyle(
            color: Colors.white,
            fontSize: compact ? 21 : 27,
            fontWeight: FontWeight.w800,
          ),
        ),
      ],
    );
  }
}

class _LargeBrand extends StatelessWidget {
  const _LargeBrand({this.compact = false});

  final bool compact;

  @override
  Widget build(BuildContext context) {
    final double logoSize = compact ? 150 : 220;

    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: compact
          ? CrossAxisAlignment.center
          : CrossAxisAlignment.start,
      children: <Widget>[
        Container(
          width: logoSize,
          height: logoSize,
          padding: EdgeInsets.all(compact ? 16 : 23),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(compact ? 34 : 49),
            boxShadow: const <BoxShadow>[
              BoxShadow(
                color: Color.fromRGBO(0, 0, 0, 0.18),
                blurRadius: 28,
                offset: Offset(0, 15),
              ),
            ],
          ),
          child: _LogoImage(fallbackSize: compact ? 88 : 125),
        ),
        const SizedBox(height: 26),
        Text.rich(
          TextSpan(
            children: <InlineSpan>[
              const TextSpan(text: 'Doctor'),
              TextSpan(
                text: 'Live',
                style: TextStyle(color: Colors.tealAccent.shade200),
              ),
            ],
          ),
          textAlign: compact ? TextAlign.center : TextAlign.left,
          style: TextStyle(
            color: Colors.white,
            fontSize: compact ? 43 : 64,
            fontWeight: FontWeight.w900,
            letterSpacing: -1.5,
          ),
        ),
      ],
    );
  }
}

class _LogoImage extends StatelessWidget {
  const _LogoImage({required this.fallbackSize});

  final double fallbackSize;

  @override
  Widget build(BuildContext context) {
    return Image.asset(
      'assets/images/doctorlive_logo.png',
      fit: BoxFit.contain,
      errorBuilder:
          (BuildContext context, Object error, StackTrace? stackTrace) {
            return Icon(
              Icons.health_and_safety_outlined,
              color: AppColors.primary,
              size: fallbackSize,
            );
          },
    );
  }
}

class _WelcomeCopy extends StatelessWidget {
  const _WelcomeCopy({
    required this.headlineSize,
    this.centered = false,
    this.onGetStarted,
  });

  final double headlineSize;
  final bool centered;
  final VoidCallback? onGetStarted;

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: centered
          ? CrossAxisAlignment.center
          : CrossAxisAlignment.start,
      children: <Widget>[
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: 0.12),
            borderRadius: BorderRadius.circular(30),
            border: Border.all(color: Colors.white.withValues(alpha: 0.22)),
          ),
          child: const Text(
            'SMART HEALTHCARE  •  ZERO WAITING',
            style: TextStyle(
              color: Color(0xFFD8FFFA),
              fontSize: 12,
              fontWeight: FontWeight.w700,
              letterSpacing: 1.7,
            ),
          ),
        ),
        const SizedBox(height: 17),
        Text.rich(
          TextSpan(
            children: <InlineSpan>[
              const TextSpan(text: 'Your Doctor.\nYour Time. '),
              TextSpan(
                text: 'Your Health.',
                style: TextStyle(
                  color: Colors.tealAccent.shade100,
                  fontStyle: FontStyle.italic,
                ),
              ),
            ],
          ),
          textAlign: centered ? TextAlign.center : TextAlign.left,
          style: TextStyle(
            color: Colors.white,
            fontSize: headlineSize,
            height: 1.08,
            fontWeight: FontWeight.w900,
            letterSpacing: -1.15,
            shadows: const <Shadow>[
              Shadow(
                color: Color.fromRGBO(0, 35, 33, 0.28),
                blurRadius: 18,
                offset: Offset(0, 6),
              ),
            ],
          ),
        ),
        const SizedBox(height: 23),
        Text(
          'Find trusted doctors, avoid unnecessary waiting, and manage '
          'your healthcare from one secure platform.',
          textAlign: centered ? TextAlign.center : TextAlign.left,
          style: const TextStyle(
            color: Color(0xFFE0FFFB),
            fontSize: 19,
            height: 1.55,
          ),
        ),
        if (onGetStarted != null) ...<Widget>[
          const SizedBox(height: 34),
          Align(
            alignment: Alignment.centerRight,
            child: _GetStartedButton(onPressed: onGetStarted!),
          ),
        ],
      ],
    );
  }
}

class _GetStartedButton extends StatefulWidget {
  const _GetStartedButton({required this.onPressed});

  final VoidCallback onPressed;

  @override
  State<_GetStartedButton> createState() => _GetStartedButtonState();
}

class _GetStartedButtonState extends State<_GetStartedButton> {
  double _progress = 0;

  void _updateProgress(DragUpdateDetails details, double availableDistance) {
    if (availableDistance <= 0) {
      return;
    }

    setState(() {
      _progress = (_progress + details.delta.dx / availableDistance)
          .clamp(0.0, 1.0)
          .toDouble();
    });
  }

  void _finishSlide() {
    if (_progress >= 0.78) {
      setState(() {
        _progress = 1;
      });
      widget.onPressed();
      return;
    }

    setState(() {
      _progress = 0;
    });
  }

  @override
  Widget build(BuildContext context) {
    const double trackHeight = 66;
    const double knobSize = 54;
    const double trackPadding = 6;

    return LayoutBuilder(
      builder: (BuildContext context, BoxConstraints constraints) {
        final double trackWidth = constraints.maxWidth.isFinite
            ? constraints.maxWidth
            : 410;
        final double availableDistance =
            trackWidth - knobSize - (trackPadding * 2);

        return Container(
          width: trackWidth,
          height: trackHeight,
          decoration: BoxDecoration(
            color: const Color.fromRGBO(255, 255, 255, 0.14),
            borderRadius: BorderRadius.circular(trackHeight / 2),
            border: Border.all(
              color: const Color.fromRGBO(255, 255, 255, 0.32),
              width: 1.2,
            ),
            boxShadow: const <BoxShadow>[
              BoxShadow(
                color: Color.fromRGBO(0, 38, 35, 0.24),
                blurRadius: 22,
                offset: Offset(0, 10),
              ),
            ],
          ),
          child: Stack(
            alignment: Alignment.centerLeft,
            children: <Widget>[
              Positioned.fill(
                child: Center(
                  child: AnimatedOpacity(
                    duration: const Duration(milliseconds: 150),
                    opacity: 1 - (_progress * 0.72),
                    child: const Text(
                      'Slide to Get Started',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 16,
                        fontWeight: FontWeight.w700,
                        letterSpacing: 0.35,
                      ),
                    ),
                  ),
                ),
              ),
              Positioned(
                left: trackPadding + (availableDistance * _progress),
                child: MouseRegion(
                  cursor: SystemMouseCursors.grab,
                  child: GestureDetector(
                    behavior: HitTestBehavior.opaque,
                    onHorizontalDragUpdate: (DragUpdateDetails details) {
                      _updateProgress(details, availableDistance);
                    },
                    onHorizontalDragEnd: (_) => _finishSlide(),
                    child: Container(
                      width: knobSize,
                      height: knobSize,
                      decoration: BoxDecoration(
                        gradient: const LinearGradient(
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                          colors: <Color>[Color(0xFF72FFF1), Color(0xFF21D8C8)],
                        ),
                        shape: BoxShape.circle,
                        boxShadow: const <BoxShadow>[
                          BoxShadow(
                            color: Color.fromRGBO(0, 0, 0, 0.24),
                            blurRadius: 12,
                            offset: Offset(0, 5),
                          ),
                        ],
                      ),
                      child: const Icon(
                        Icons.arrow_forward_rounded,
                        color: Color(0xFF064A46),
                        size: 28,
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

class _MedicalPlus extends StatelessWidget {
  const _MedicalPlus({required this.size, required this.opacity});

  final double size;
  final double opacity;

  @override
  Widget build(BuildContext context) {
    return Icon(
      Icons.add_rounded,
      size: size,
      color: Colors.white.withValues(alpha: opacity),
    );
  }
}

class _WelcomeBackgroundPainter extends CustomPainter {
  const _WelcomeBackgroundPainter();

  @override
  void paint(Canvas canvas, Size size) {
    final Rect area = Offset.zero & size;

    const LinearGradient gradient = LinearGradient(
      begin: Alignment.topLeft,
      end: Alignment.bottomRight,
      colors: <Color>[Color(0xFF034C49), Color(0xFF08756F), Color(0xFF18BFB2)],
      stops: <double>[0, 0.55, 1],
    );

    canvas.drawRect(area, Paint()..shader = gradient.createShader(area));

    final Path topWave = Path()
      ..moveTo(0, 0)
      ..lineTo(size.width * 0.43, 0)
      ..quadraticBezierTo(
        size.width * 0.29,
        size.height * 0.2,
        0,
        size.height * 0.25,
      )
      ..close();

    canvas.drawPath(
      topWave,
      Paint()..color = const Color.fromRGBO(37, 218, 204, 0.22),
    );

    final Path darkBottomWave = Path()
      ..moveTo(0, size.height * 0.78)
      ..quadraticBezierTo(
        size.width * 0.33,
        size.height * 0.94,
        size.width * 0.61,
        size.height * 0.74,
      )
      ..quadraticBezierTo(
        size.width * 0.82,
        size.height * 0.6,
        size.width,
        size.height * 0.68,
      )
      ..lineTo(size.width, size.height)
      ..lineTo(0, size.height)
      ..close();

    canvas.drawPath(
      darkBottomWave,
      Paint()..color = const Color.fromRGBO(0, 58, 56, 0.6),
    );

    final Path lightRightWave = Path()
      ..moveTo(size.width * 0.5, size.height)
      ..quadraticBezierTo(
        size.width * 0.72,
        size.height * 0.67,
        size.width,
        size.height * 0.49,
      )
      ..lineTo(size.width, size.height)
      ..close();

    canvas.drawPath(
      lightRightWave,
      Paint()..color = const Color.fromRGBO(190, 255, 247, 0.26),
    );

    final Paint darkEcgPaint = Paint()
      ..color = const Color.fromRGBO(0, 83, 79, 0.92)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 3.4
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;

    final Paint lightEcgPaint = Paint()
      ..color = const Color.fromRGBO(64, 255, 236, 0.82)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 3
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;

    // Double-line heartbeat pattern behind the large DoctorLive wordmark.
    final double y = size.height * 0.68;
    final Path heartbeatPath = Path()
      ..moveTo(0, y)
      ..lineTo(size.width * 0.065, y)
      ..lineTo(size.width * 0.09, y - 58)
      ..lineTo(size.width * 0.115, y + 52)
      ..lineTo(size.width * 0.15, y - 102)
      ..lineTo(size.width * 0.185, y)
      ..lineTo(size.width * 0.225, y - 52)
      ..lineTo(size.width * 0.255, y)
      ..lineTo(size.width * 0.285, y)
      ..lineTo(size.width * 0.315, y + 82)
      ..lineTo(size.width * 0.35, y)
      ..lineTo(size.width * 0.43, y);

    canvas.drawPath(heartbeatPath, darkEcgPaint);

    canvas.drawPath(heartbeatPath.shift(const Offset(0, 9)), lightEcgPaint);
  }

  @override
  bool shouldRepaint(covariant _WelcomeBackgroundPainter oldDelegate) {
    return false;
  }
}

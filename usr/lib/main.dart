import 'dart:async';
import 'dart:math';
import 'package:flutter/material.dart';

// ==========================================
// 🎛️ TUNABLES / CONFIGURATION
// ==========================================
const String kRedirectUrl = 'https://flutter.dev'; // URL to redirect to
const Color kPrimaryColor = Color(0xFF6200EE); // Button Color
const Color kBackgroundColor = Color(0xFF121212); // Page Background
const int kGridSize = 10; // 10x10 grid = 100 fragments
const Duration kAnimationDuration = Duration(milliseconds: 1500);
const double kExplosionForce = 1.5; // Multiplier for distance

void main() {
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Shatter Button Demo',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        useMaterial3: true,
        brightness: Brightness.dark,
        scaffoldBackgroundColor: kBackgroundColor,
        colorScheme: ColorScheme.fromSeed(
          seedColor: kPrimaryColor,
          brightness: Brightness.dark,
        ),
      ),
      // Ensure strict routing for web
      initialRoute: '/',
      routes: {
        '/': (context) => const ShatterPage(),
        '/success': (context) => const SuccessPage(),
      },
    );
  }
}

class ShatterPage extends StatefulWidget {
  const ShatterPage({super.key});

  @override
  State<ShatterPage> createState() => _ShatterPageState();
}

class _ShatterPageState extends State<ShatterPage> with TickerProviderStateMixin {
  final GlobalKey _buttonKey = GlobalKey();
  bool _isShattered = false;
  List<Fragment> _fragments = [];
  late AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: kAnimationDuration,
    );

    _controller.addStatusListener((status) {
      if (status == AnimationStatus.completed) {
        _handleRedirect();
      }
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _handleRedirect() {
    // Simulate redirection
    Navigator.of(context).pushReplacementNamed('/success');
  }

  void _shatterButton() {
    final RenderBox? renderBox = _buttonKey.currentContext?.findRenderObject() as RenderBox?;
    if (renderBox == null) return;

    final Size size = renderBox.size;
    final Offset position = renderBox.localToGlobal(Offset.zero);
    final double fragmentWidth = size.width / kGridSize;
    final double fragmentHeight = size.height / kGridSize;

    final Random random = Random();
    final List<Fragment> newFragments = [];
    final Size screenSize = MediaQuery.of(context).size;

    // Generate fragments
    for (int i = 0; i < kGridSize; i++) {
      for (int j = 0; j < kGridSize; j++) {
        // Initial position (relative to screen)
        final double startX = position.dx + (j * fragmentWidth);
        final double startY = position.dy + (i * fragmentHeight);

        // Target position (spread outwards covering screen)
        // We calculate a vector from center of button to the fragment
        final double centerX = position.dx + size.width / 2;
        final double centerY = position.dy + size.height / 2;
        
        final double fragCenterX = startX + fragmentWidth / 2;
        final double fragCenterY = startY + fragmentHeight / 2;

        // Direction vector
        double dirX = fragCenterX - centerX;
        double dirY = fragCenterY - centerY;

        // Add some randomness to direction
        dirX += (random.nextDouble() - 0.5) * 20;
        dirY += (random.nextDouble() - 0.5) * 20;

        // Normalize and scale to cover screen
        // We want them to fly far off screen or to the edges
        final double distance = sqrt(dirX * dirX + dirY * dirY);
        final double scale = (max(screenSize.width, screenSize.height) / (distance == 0 ? 1 : distance)) * kExplosionForce;
        
        // Add randomness to speed/distance
        final double randomScale = scale * (0.8 + random.nextDouble() * 0.5);

        final double endX = startX + (dirX * randomScale);
        final double endY = startY + (dirY * randomScale);

        newFragments.add(Fragment(
          startX: startX,
          startY: startY,
          endX: endX,
          endY: endY,
          width: fragmentWidth,
          height: fragmentHeight,
          rotation: (random.nextDouble() - 0.5) * 4 * pi, // Random rotation
          delay: random.nextDouble() * 0.3, // Staggered start (0 to 30% of duration)
          scale: 0.5 + random.nextDouble(), // Random final scale
          color: kPrimaryColor,
        ));
      }
    }

    setState(() {
      _fragments = newFragments;
      _isShattered = true;
    });

    _controller.forward();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Stack(
        children: [
          // 1. The Fragments (Visible only when shattered)
          if (_isShattered)
            ..._fragments.map((fragment) {
              return AnimatedBuilder(
                animation: _controller,
                builder: (context, child) {
                  // Calculate progress based on delay
                  final double t = _controller.value;
                  // Normalize t based on delay: start later, finish at 1.0
                  // Effective time = (t - delay) / (1 - delay)
                  double effectiveT = (t - fragment.delay) / (1.0 - fragment.delay);
                  effectiveT = effectiveT.clamp(0.0, 1.0);
                  
                  // Curved animation for smooth physics
                  final double curveVal = Curves.easeOutExpo.transform(effectiveT);

                  // Interpolate position
                  final double currentX = fragment.startX + (fragment.endX - fragment.startX) * curveVal;
                  final double currentY = fragment.startY + (fragment.endY - fragment.startY) * curveVal;

                  // Fade out near the end
                  final double opacity = (1.0 - effectiveT * 1.2).clamp(0.0, 1.0);

                  return Positioned(
                    left: currentX,
                    top: currentY,
                    child: Transform.rotate(
                      angle: fragment.rotation * effectiveT,
                      child: Transform.scale(
                        scale: 1.0 - (0.5 * effectiveT), // Shrink slightly as they fly
                        child: Opacity(
                          opacity: opacity,
                          child: Container(
                            width: fragment.width,
                            height: fragment.height,
                            decoration: BoxDecoration(
                              color: fragment.color,
                              // Add slight border radius for "debris" look
                              borderRadius: BorderRadius.circular(1), 
                            ),
                          ),
                        ),
                      ),
                    ),
                  );
                },
              );
            }),

          // 2. The Main Button (Visible until shattered)
          if (!_isShattered)
            Center(
              child: MouseRegion(
                cursor: SystemMouseCursors.click,
                child: GestureDetector(
                  onTap: _shatterButton,
                  child: Container(
                    key: _buttonKey,
                    padding: const EdgeInsets.symmetric(horizontal: 48, vertical: 24),
                    decoration: BoxDecoration(
                      color: kPrimaryColor,
                      borderRadius: BorderRadius.circular(12),
                      boxShadow: [
                        BoxShadow(
                          color: kPrimaryColor.withOpacity(0.4),
                          blurRadius: 20,
                          offset: const Offset(0, 8),
                        ),
                      ],
                    ),
                    child: const Text(
                      'GET STARTED',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                        letterSpacing: 1.5,
                      ),
                    ),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

// Data model for a single shard/fragment
class Fragment {
  final double startX;
  final double startY;
  final double endX;
  final double endY;
  final double width;
  final double height;
  final double rotation;
  final double delay;
  final double scale;
  final Color color;

  Fragment({
    required this.startX,
    required this.startY,
    required this.endX,
    required this.endY,
    required this.width,
    required this.height,
    required this.rotation,
    required this.delay,
    required this.scale,
    required this.color,
  });
}

// Simple Success Page to demonstrate redirect
class SuccessPage extends StatelessWidget {
  const SuccessPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.check_circle_outline, size: 100, color: Colors.green),
            const SizedBox(height: 20),
            const Text(
              'Redirected Successfully!',
              style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 10),
            Text(
              'Welcome to $kRedirectUrl',
              style: const TextStyle(color: Colors.grey),
            ),
            const SizedBox(height: 40),
            OutlinedButton(
              onPressed: () {
                 Navigator.of(context).pushReplacementNamed('/');
              },
              child: const Text('RESET DEMO'),
            )
          ],
        ),
      ),
    );
  }
}

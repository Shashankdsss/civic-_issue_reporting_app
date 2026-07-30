import 'dart:async';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'main_screen.dart';
import 'login_screen.dart';

class SplashScreen extends StatefulWidget {
  final bool isLoggedIn;
  const SplashScreen({super.key, required this.isLoggedIn});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen> with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _logoScaleIn;
  late Animation<double> _logoFadeIn;
  late Animation<double> _logoScaleOut;
  late Animation<Offset> _logoSlideUp;
  late Animation<double> _textFadeIn;
  late Animation<double> _loaderFadeIn;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 4000));

    // Phase 1: 0 - 800ms (0.0 to 0.2)
    _logoScaleIn = Tween<double>(begin: 0.5, end: 1.0).animate(CurvedAnimation(
      parent: _controller,
      curve: const Interval(0.0, 0.2, curve: Curves.easeOutBack),
    ));
    // Zoom in with fade in
    _logoFadeIn = Tween<double>(begin: 0.0, end: 1.0).animate(CurvedAnimation(
      parent: _controller,
      curve: const Interval(0.0, 0.2, curve: Curves.easeIn),
    ));

    // Phase 3: 1200ms - 2000ms (0.3 to 0.5)
    _logoScaleOut = Tween<double>(begin: 1.0, end: 0.8).animate(CurvedAnimation(
      parent: _controller,
      curve: const Interval(0.3, 0.5, curve: Curves.easeInOut),
    ));
    _logoSlideUp = Tween<Offset>(begin: Offset.zero, end: const Offset(0, -1.0)).animate(CurvedAnimation(
      parent: _controller,
      curve: const Interval(0.3, 0.5, curve: Curves.easeInOut),
    ));

    // Phase 4: 2000ms - 2500ms (0.5 to 0.625)
    _textFadeIn = Tween<double>(begin: 0.0, end: 1.0).animate(CurvedAnimation(
      parent: _controller,
      curve: const Interval(0.5, 0.625, curve: Curves.easeIn),
    ));

    // Phase 5: 2800ms - 3200ms (0.7 to 0.8)
    _loaderFadeIn = Tween<double>(begin: 0.0, end: 1.0).animate(CurvedAnimation(
      parent: _controller,
      curve: const Interval(0.7, 0.8, curve: Curves.easeIn),
    ));

    _controller.forward();

    _controller.addStatusListener((status) {
      if (status == AnimationStatus.completed) {
        Timer(const Duration(milliseconds: 500), _navigateToNext);
      }
    });
  }

  void _navigateToNext() {
    if (!mounted) return;
    
    // Creating fade-and-slide transition
    Navigator.of(context).pushReplacement(
      PageRouteBuilder(
        transitionDuration: const Duration(milliseconds: 800),
        pageBuilder: (context, animation, secondaryAnimation) {
          return widget.isLoggedIn ? const MainScreen() : const LoginScreen();
        },
        transitionsBuilder: (context, animation, secondaryAnimation, child) {
          final fadeAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
            CurvedAnimation(parent: animation, curve: Curves.easeOutCubic),
          );
          final slideAnimation = Tween<Offset>(begin: const Offset(0, 0.1), end: Offset.zero).animate(
            CurvedAnimation(parent: animation, curve: Curves.easeOutCubic),
          );
          
          return FadeTransition(
            opacity: fadeAnimation,
            child: SlideTransition(
              position: slideAnimation,
              child: child,
            ),
          );
        },
      ),
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        width: double.infinity,
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            colors: [Color(0xFF0F172A), Color(0xFF1E293B)],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
        ),
        child: AnimatedBuilder(
          animation: _controller,
          builder: (context, child) {
            return Stack(
              alignment: Alignment.center,
              children: [
                // Logo Animation
                SlideTransition(
                  position: _logoSlideUp,
                  child: Transform.scale(
                    scale: _logoScaleIn.value * _logoScaleOut.value,
                    child: FadeTransition(
                      opacity: _logoFadeIn,
                      child: Container(
                        padding: const EdgeInsets.all(20),
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: const Color(0xFF3B82F6).withOpacity(0.15),
                          boxShadow: [
                            BoxShadow(
                              color: const Color(0xFF3B82F6).withOpacity(0.2),
                              blurRadius: 30,
                            ),
                          ],
                        ),
                        child: const Icon(
                          Icons.other_houses_rounded, // Better Civic/Farm logo icon representation, adjust as needed
                          size: 80,
                          color: Color(0xFF3B82F6),
                        ),
                      ),
                    ),
                  ),
                ),

                // App Name fades in
                if (_textFadeIn.value > 0)
                  Positioned(
                    top: MediaQuery.of(context).size.height * 0.5 + 40,
                    child: FadeTransition(
                      opacity: _textFadeIn,
                      child: Text(
                        "Civic Connect",
                        style: GoogleFonts.poppins(
                          fontSize: 28,
                          fontWeight: FontWeight.w800,
                          color: Colors.white,
                          letterSpacing: 1.5,
                        ),
                      ),
                    ),
                  ),

                // Circular Loading Indicator
                if (_loaderFadeIn.value > 0)
                  Positioned(
                    bottom: MediaQuery.of(context).size.height * 0.15,
                    child: FadeTransition(
                      opacity: _loaderFadeIn,
                      child: const Opacity(
                        opacity: 0.8,
                        child: CircularProgressIndicator(
                          color: Color(0xFF3B82F6),
                          strokeWidth: 3,
                        ),
                      ),
                    ),
                  ),
              ],
            );
          },
        ),
      ),
    );
  }
}

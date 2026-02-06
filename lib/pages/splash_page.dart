import 'dart:async';
import 'package:flutter/material.dart';
import 'package:lottie/lottie.dart';
import 'login_page.dart';

class SplashPage extends StatefulWidget {
  const SplashPage({super.key});

  @override
  State<SplashPage> createState() => _SplashPageState();
}

class _SplashPageState extends State<SplashPage> {
  bool _showText = false;

  @override
  void initState() {
    super.initState();
    // Появление текста через 2 секунды
    Timer(const Duration(seconds: 2), () {
      if (mounted) {
        setState(() {
          _showText = true;
        });
      }
    });
  }

  void _onTap() {
    if (_showText) {
      Navigator.of(context).pushReplacement(
        MaterialPageRoute(builder: (context) => const LoginPage()),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: _onTap,
      child: Scaffold(
        backgroundColor: Colors.black,
        body: Stack(
          children: [
            Center(
              child: Lottie.asset(
                'assets/animations/splash.json',
                width: 380,
                height: 380,
                fit: BoxFit.contain,
              ),
            ),
            if (_showText)
              Positioned(
                bottom: 60,
                left: 20,
                right: 20,
                child: const FadeInText(
                  text: 'НЕОБХОДИМО КОСНУТЬСЯ ЭКРАНА ЧТОБЫ ПРОДОЛЖИТЬ',
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class FadeInText extends StatefulWidget {
  final String text;
  const FadeInText({super.key, required this.text});

  @override
  State<FadeInText> createState() => _FadeInTextState();
}

class _FadeInTextState extends State<FadeInText> with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _opacity;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1000),
    );
    _opacity = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeIn),
    );
    _controller.forward();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return FadeTransition(
      opacity: _opacity,
      child: Text(
        widget.text,
        textAlign: TextAlign.center,
        style: const TextStyle(
          fontSize: 16,
          color: Colors.white,
          fontWeight: FontWeight.w200, // Очень тонкий (Light)
          letterSpacing: 1.2,
        ),
      ),
    );
  }
}

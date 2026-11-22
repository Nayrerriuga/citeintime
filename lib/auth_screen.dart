import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'services/auth_service.dart';
import 'theme/grand_line_theme.dart';
import 'widgets/cite_in_time_logo.dart';

class AuthScreen extends StatefulWidget {
  const AuthScreen({super.key});

  @override
  State<AuthScreen> createState() => _AuthScreenState();
}

class _AuthScreenState extends State<AuthScreen> with TickerProviderStateMixin {
  final _formKey = GlobalKey<FormState>();
  final _idController = TextEditingController();
  final _authService = AuthService();

  bool _isLoading = false;

  late final AnimationController _floatController;
  late final AnimationController _compassController;
  late final AnimationController _waveController;
  late final AnimationController _entranceController;

  late final Animation<double> _floatAnimation;
  late final Animation<double> _fadeAnimation;
  late final Animation<Offset> _slideAnimation;

  @override
  void initState() {
    super.initState();

    _floatController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 3),
    )..repeat(reverse: true);

    _floatAnimation = Tween<double>(begin: -8.0, end: 8.0).animate(
      CurvedAnimation(parent: _floatController, curve: Curves.easeInOutSine),
    );

    _compassController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 12),
    )..repeat();

    _waveController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 5),
    )..repeat();

    _entranceController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 850),
    )..forward();

    _fadeAnimation = CurvedAnimation(
      parent: _entranceController,
      curve: Curves.easeOut,
    );

    _slideAnimation =
        Tween<Offset>(begin: const Offset(0, 0.12), end: Offset.zero).animate(
          CurvedAnimation(
            parent: _entranceController,
            curve: Curves.easeOutCubic,
          ),
        );
  }

  @override
  void dispose() {
    _idController.dispose();
    _floatController.dispose();
    _compassController.dispose();
    _waveController.dispose();
    _entranceController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isLoading = true);
    try {
      await _authService.signInWithId(_idController.text);
    } on AuthException catch (e) {
      if (!mounted) return;
      _showError(e.message);
    } catch (e) {
      if (!mounted) return;
      _showError('Unexpected error: $e');
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  void _showError(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: GrandLinePalette.strawHatRed,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: GrandLinePalette.oceanDeep,
      body: Stack(
        children: [
          Positioned.fill(
            child: AnimatedBuilder(
              animation: _waveController,
              builder: (context, _) => CustomPaint(
                painter: GrandLineBackgroundPainter(
                  waveProgress: _waveController.value,
                  compassAngle: _compassController.value * 2 * math.pi,
                ),
              ),
            ),
          ),
          SafeArea(
            child: Center(
              child: SingleChildScrollView(
                padding: const EdgeInsets.symmetric(
                  horizontal: 24,
                  vertical: 20,
                ),
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 420),
                  child: FadeTransition(
                    opacity: _fadeAnimation,
                    child: SlideTransition(
                      position: _slideAnimation,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          CiteInTimeLogoHeader(
                            floatAnimation: _floatAnimation,
                            compassAnimation: _compassController,
                          ),
                          const SizedBox(height: 28),
                          _buildLoginCard(),
                        ],
                      ),
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

  Widget _buildLoginCard() {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: GrandLinePalette.oceanMid.withValues(alpha: 0.88),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(
          color: GrandLinePalette.treasureGold.withValues(alpha: 0.45),
          width: 1.5,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.45),
            blurRadius: 24,
            offset: const Offset(0, 12),
          ),
        ],
      ),
      child: Form(
        key: _formKey,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Text(
              'Enter Your ID Number',
              textAlign: TextAlign.center,
              style: TextStyle(
                color: Colors.white,
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              'Students log in using their assigned ID',
              textAlign: TextAlign.center,
              style: TextStyle(
                color: Colors.white.withValues(alpha: 0.65),
                fontSize: 12,
              ),
            ),
            const SizedBox(height: 20),
            TextFormField(
              controller: _idController,
              textCapitalization: TextCapitalization.characters,
              style: const TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.w600,
                letterSpacing: 1.1,
              ),
              decoration: InputDecoration(
                labelText: 'ID Number',
                hintText: 'e.g. 1009247',
                labelStyle: const TextStyle(color: Colors.white70),
                hintStyle: TextStyle(
                  color: Colors.white.withValues(alpha: 0.3),
                ),
                prefixIcon: const Icon(
                  Icons.badge_outlined,
                  color: GrandLinePalette.treasureGold,
                ),
                filled: true,
                fillColor: GrandLinePalette.oceanDeep.withValues(alpha: 0.7),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(14),
                  borderSide: BorderSide(
                    color: GrandLinePalette.treasureGold.withValues(alpha: 0.3),
                  ),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(14),
                  borderSide: const BorderSide(
                    color: GrandLinePalette.treasureGold,
                    width: 2,
                  ),
                ),
                errorBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(14),
                  borderSide: const BorderSide(
                    color: GrandLinePalette.strawHatRed,
                  ),
                ),
                focusedErrorBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(14),
                  borderSide: const BorderSide(
                    color: GrandLinePalette.strawHatRed,
                    width: 2,
                  ),
                ),
              ),
              validator: (val) => (val == null || val.trim().length < 3)
                  ? 'Enter a valid ID Number'
                  : null,
            ),
            const SizedBox(height: 24),
            FilledButton(
              onPressed: _isLoading ? null : _submit,
              style: FilledButton.styleFrom(
                backgroundColor: GrandLinePalette.strawHatRed,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 16),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14),
                  side: BorderSide(
                    color: GrandLinePalette.treasureGold.withValues(alpha: 0.7),
                  ),
                ),
                elevation: 6,
              ),
              child: _isLoading
                  ? const SizedBox(
                      height: 22,
                      width: 22,
                      child: CircularProgressIndicator(
                        strokeWidth: 2.5,
                        color: GrandLinePalette.treasureGold,
                      ),
                    )
                  : const Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          Icons.sailing_rounded,
                          color: GrandLinePalette.treasureGold,
                        ),
                        SizedBox(width: 10),
                        Text(
                          'Log In',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                            letterSpacing: 0.5,
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
}

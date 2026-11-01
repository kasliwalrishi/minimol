// ignore_for_file: deprecated_member_use
import 'dart:math' as math;
import 'dart:ui';

import 'package:flutter/material.dart';

// ─────────────────────────────────────────────────────────────────────────────
// Palette: quiet graphite surfaces with one confident network accent.  The
// existing names are kept so the app can use a single, deliberately restrained
// design system without changing every call site.
// ─────────────────────────────────────────────────────────────────────────────
const kPurple = Color(0xff6E8190); // slate
const kCyan = Color(0xff58A6A6); // primary network accent
const kPink = Color(0xff8493A0); // cool grey, retained for compatibility
const kAmber = Color(0xffB89A62); // reserved for attention
const kGreen = Color(0xff79A98A); // healthy state
const kRed = Color(0xffC87070); // error state
const kDarkBg = Color(0xff0A1218);
const kDarkSurface = Color(0xff121E26);
const kGlass = Color(0x1FFFFFFF); // 12% white

// ─────────────────────────────────────────────────────────────────────────────
// GlassCard  (replaces HnCard)
// ─────────────────────────────────────────────────────────────────────────────
class GlassCard extends StatelessWidget {
  const GlassCard({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.all(18),
    this.glowColor,
    this.borderRadius = 24,
  });
  final Widget child;
  final EdgeInsets padding;
  final Color? glowColor;
  final double borderRadius;

  @override
  Widget build(BuildContext context) {
    final dark = Theme.of(context).brightness == Brightness.dark;
    final accent = glowColor ?? kCyan;
    return ClipRRect(
      borderRadius: BorderRadius.circular(borderRadius),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 12, sigmaY: 12),
        child: Container(
          decoration: BoxDecoration(
            color: dark
                ? const Color(0xff14222B).withOpacity(0.90)
                : Colors.white.withOpacity(0.82),
            borderRadius: BorderRadius.circular(borderRadius),
            border: Border.all(
              color: dark
                  ? Colors.white.withOpacity(0.10)
                  : const Color(0xff20343B).withOpacity(0.10),
              width: 1,
            ),
            boxShadow: [
              BoxShadow(
                color: accent.withOpacity(0.08),
                blurRadius: 18,
                spreadRadius: -8,
              ),
            ],
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [
                Colors.white.withOpacity(dark ? 0.035 : 0.55),
                Colors.transparent,
              ],
            ),
          ),
          child: Padding(padding: padding, child: child),
        ),
      ),
    );
  }
}

/// Backward-compatible alias so call-sites using HnCard still compile.
typedef HnCard = GlassCard;

// ─────────────────────────────────────────────────────────────────────────────
// NeonSectionTitle  (replaces SectionTitle)
// ─────────────────────────────────────────────────────────────────────────────
class NeonSectionTitle extends StatelessWidget {
  const NeonSectionTitle(this.title, {super.key, this.action, this.color});
  final String title;
  final Widget? action;
  final Color? color;

  @override
  Widget build(BuildContext context) {
    final tint = color ?? kPurple;
    return Padding(
      padding: const EdgeInsets.only(top: 24, bottom: 12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: Theme.of(context).textTheme.titleLarge?.copyWith(
                    fontWeight: FontWeight.w800,
                    color: Theme.of(context).colorScheme.onSurface,
                    letterSpacing: -0.2,
                  ),
                ),
                const SizedBox(height: 4),
                Container(
                  height: 2.5,
                  width: 40,
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(4),
                    color: tint,
                  ),
                ),
              ],
            ),
          ),
          action ?? const SizedBox.shrink(),
        ],
      ),
    );
  }
}

/// Backward-compatible alias.
typedef SectionTitle = NeonSectionTitle;

// ─────────────────────────────────────────────────────────────────────────────
// PulsingDot
// ─────────────────────────────────────────────────────────────────────────────
class PulsingDot extends StatefulWidget {
  const PulsingDot({super.key, required this.color, this.size = 8});
  final Color color;
  final double size;

  @override
  State<PulsingDot> createState() => _PulsingDotState();
}

class _PulsingDotState extends State<PulsingDot>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl;
  late final Animation<double> _scale;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 900),
    )..repeat(reverse: true);
    _scale = Tween<double>(
      begin: 0.7,
      end: 1.3,
    ).animate(CurvedAnimation(parent: _ctrl, curve: Curves.easeInOut));
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => ScaleTransition(
    scale: _scale,
    child: Container(
      width: widget.size,
      height: widget.size,
      decoration: BoxDecoration(
        color: widget.color,
        shape: BoxShape.circle,
        boxShadow: [
          BoxShadow(
            color: widget.color.withOpacity(0.22),
            blurRadius: 5,
            spreadRadius: 0,
          ),
        ],
      ),
    ),
  );
}

// ─────────────────────────────────────────────────────────────────────────────
// AnimatedStatusPill  (replaces StatusPill)
// ─────────────────────────────────────────────────────────────────────────────
class AnimatedStatusPill extends StatelessWidget {
  const AnimatedStatusPill({
    super.key,
    required this.online,
    required this.label,
  });
  final bool online;
  final String label;

  @override
  Widget build(BuildContext context) {
    final color = online ? kGreen : kRed;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: color.withOpacity(0.14),
        borderRadius: BorderRadius.circular(99),
        border: Border.all(color: color.withOpacity(0.35), width: 1),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (online)
            PulsingDot(color: color, size: 7)
          else
            Container(
              width: 7,
              height: 7,
              decoration: BoxDecoration(color: color, shape: BoxShape.circle),
            ),
          const SizedBox(width: 6),
          Text(
            label,
            style: TextStyle(
              color: color,
              fontWeight: FontWeight.w700,
              fontSize: 12,
            ),
          ),
        ],
      ),
    );
  }
}

/// Backward-compatible alias.
typedef StatusPill = AnimatedStatusPill;

// ─────────────────────────────────────────────────────────────────────────────
// GradientMetricCard  (replaces MetricTile)
// ─────────────────────────────────────────────────────────────────────────────
class GradientMetricCard extends StatefulWidget {
  const GradientMetricCard({
    super.key,
    required this.label,
    required this.value,
    required this.icon,
    this.colors = const [kPurple, kCyan],
  });
  final String label;
  final String value;
  final IconData icon;
  final List<Color> colors;

  @override
  State<GradientMetricCard> createState() => _GradientMetricCardState();
}

class _GradientMetricCardState extends State<GradientMetricCard>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl;
  late final Animation<double> _anim;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 3),
    )..repeat(reverse: true);
    _anim = CurvedAnimation(parent: _ctrl, curve: Curves.easeInOut);
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final dark = Theme.of(context).brightness == Brightness.dark;
    return AnimatedBuilder(
      animation: _anim,
      builder: (context, child) {
        final t = _anim.value;
        final accent = Color.lerp(widget.colors[0], widget.colors.last, t)!;
        return ClipRRect(
          borderRadius: BorderRadius.circular(20),
          child: Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(20),
              color: dark ? const Color(0xff14222B) : Colors.white,
              border: Border.all(color: accent.withOpacity(0.38)),
              boxShadow: [
                BoxShadow(
                  color: accent.withOpacity(0.08),
                  blurRadius: 14,
                  spreadRadius: -8,
                ),
              ],
            ),
            child: Stack(
              children: [
                Positioned(
                  top: 0,
                  left: 0,
                  right: 0,
                  child: Container(
                    height: 3,
                    decoration: BoxDecoration(
                      color: accent,
                      borderRadius: BorderRadius.circular(99),
                    ),
                  ),
                ),
                child!,
              ],
            ),
          ),
        );
      },
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(widget.icon, color: widget.colors.first, size: 22),
          const Spacer(),
          Text(
            widget.value,
            style: Theme.of(context).textTheme.titleLarge
                ?.copyWith(fontWeight: FontWeight.w800, letterSpacing: -0.6),
          ),
          const SizedBox(height: 3),
          Text(
            widget.label,
            style: TextStyle(
              color: dark ? Colors.white60 : Colors.black54,
              fontSize: 11,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}

/// Backward-compatible alias.
typedef MetricTile = GradientMetricCard;

// ─────────────────────────────────────────────────────────────────────────────
// ShimmerBox
// ─────────────────────────────────────────────────────────────────────────────
class ShimmerBox extends StatefulWidget {
  const ShimmerBox({
    super.key,
    this.width = double.infinity,
    this.height = 80,
    this.borderRadius = 16,
  });
  final double width;
  final double height;
  final double borderRadius;

  @override
  State<ShimmerBox> createState() => _ShimmerBoxState();
}

class _ShimmerBoxState extends State<ShimmerBox>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1400),
    )..repeat();
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _ctrl,
      builder: (context, _) {
        final slide = _ctrl.value * 2 - 0.5;
        return ClipRRect(
          borderRadius: BorderRadius.circular(widget.borderRadius),
          child: Container(
            width: widget.width,
            height: widget.height,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(widget.borderRadius),
              gradient: LinearGradient(
                begin: Alignment(slide - 0.5, 0),
                end: Alignment(slide + 0.5, 0),
                colors: const [
                  Color(0xff15242C),
                  Color(0xff1C3138),
                  Color(0xff37696B),
                  Color(0xff1C3138),
                  Color(0xff15242C),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// NeonButton
// ─────────────────────────────────────────────────────────────────────────────
class NeonButton extends StatefulWidget {
  const NeonButton({
    super.key,
    required this.label,
    required this.onPressed,
    this.icon,
    this.colors = const [kPurple, kCyan],
    this.width,
  });
  final String label;
  final VoidCallback? onPressed;
  final IconData? icon;
  final List<Color> colors;
  final double? width;

  @override
  State<NeonButton> createState() => _NeonButtonState();
}

class _NeonButtonState extends State<NeonButton>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl;
  late final Animation<double> _scale;
  bool _pressed = false;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 120),
    );
    _scale = Tween<double>(
      begin: 1.0,
      end: 0.93,
    ).animate(CurvedAnimation(parent: _ctrl, curve: Curves.easeIn));
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTapDown: (_) {
        if (widget.onPressed == null) return;
        setState(() => _pressed = true);
        _ctrl.forward();
      },
      onTapUp: (_) {
        setState(() => _pressed = false);
        _ctrl.reverse();
        widget.onPressed?.call();
      },
      onTapCancel: () {
        setState(() => _pressed = false);
        _ctrl.reverse();
      },
      child: ScaleTransition(
        scale: _scale,
        child: Container(
          width: widget.width,
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(50),
            color: widget.onPressed == null
                ? const Color(0xff64747B)
                : widget.colors.first,
            boxShadow: [
              BoxShadow(
                color: widget.colors.first.withOpacity(_pressed ? 0.24 : 0.16),
                blurRadius: _pressed ? 18 : 12,
                spreadRadius: -5,
              ),
            ],
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              if (widget.icon != null) ...[
                Icon(widget.icon, color: Colors.white, size: 18),
                const SizedBox(width: 8),
              ],
              Text(
                widget.label,
                style: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.w700,
                  fontSize: 15,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// HiveUploadAnimation  –  orbit particles around a center hub icon
// ─────────────────────────────────────────────────────────────────────────────
class HiveUploadAnimation extends StatefulWidget {
  const HiveUploadAnimation({super.key, this.statusText = ''});
  final String statusText;

  @override
  State<HiveUploadAnimation> createState() => _HiveUploadAnimationState();
}

class _HiveUploadAnimationState extends State<HiveUploadAnimation>
    with TickerProviderStateMixin {
  late final AnimationController _orbit;
  late final AnimationController _pulse;
  late final Animation<double> _pulseAnim;

  @override
  void initState() {
    super.initState();
    _orbit = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 3),
    )..repeat();
    _pulse = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 800),
    )..repeat(reverse: true);
    _pulseAnim = Tween<double>(
      begin: 0.85,
      end: 1.15,
    ).animate(CurvedAnimation(parent: _pulse, curve: Curves.easeInOut));
  }

  @override
  void dispose() {
    _orbit.dispose();
    _pulse.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        SizedBox(
          width: 180,
          height: 180,
          child: AnimatedBuilder(
            animation: _orbit,
            builder: (context, child) {
              return CustomPaint(
                painter: _OrbitPainter(_orbit.value),
                child: child,
              );
            },
            child: Center(
              child: ScaleTransition(
                scale: _pulseAnim,
                child: Container(
                  width: 64,
                  height: 64,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: kCyan,
                    boxShadow: [
                      BoxShadow(
                        color: kCyan.withOpacity(0.22),
                        blurRadius: 18,
                        spreadRadius: 0,
                      ),
                    ],
                  ),
                  child: const Icon(
                    Icons.hub_outlined,
                    color: Colors.white,
                    size: 30,
                  ),
                ),
              ),
            ),
          ),
        ),
        const SizedBox(height: 20),
        ShaderMask(
          shaderCallback: (bounds) =>
              const LinearGradient(colors: [kPurple, kCyan])
                  .createShader(bounds),
          child: Text(
            widget.statusText.isEmpty
                ? 'Uploading to HiveNet…'
                : widget.statusText,
            style: const TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.w700,
              fontSize: 16,
            ),
          ),
        ),
      ],
    );
  }
}

class _OrbitPainter extends CustomPainter {
  _OrbitPainter(this.t);
  final double t;

  @override
  void paint(Canvas canvas, Size size) {
    final cx = size.width / 2;
    final cy = size.height / 2;
    final r1 = cx * 0.62;
    final r2 = cx * 0.88;

    final orbitPaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1
      ..color = kPurple.withOpacity(0.25);
    canvas.drawCircle(Offset(cx, cy), r1, orbitPaint);
    canvas.drawCircle(Offset(cx, cy), r2, orbitPaint);

    final particles = [
      _OParticle(r1, 0.0, kCyan, 8),
      _OParticle(r1, 0.5, kGreen, 6),
      _OParticle(r2, 0.25, kPurple, 9),
      _OParticle(r2, 0.75, kCyan, 6),
    ];

    for (final p in particles) {
      final angle = (t + p.offset) * 2 * math.pi * (p.radius == r1 ? 1 : -0.7);
      final x = cx + p.radius * math.cos(angle);
      final y = cy + p.radius * math.sin(angle);
      final paint = Paint()
        ..color = p.color
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 4);
      canvas.drawCircle(Offset(x, y), p.size, paint);
      final corePaint = Paint()..color = Colors.white;
      canvas.drawCircle(Offset(x, y), p.size * 0.4, corePaint);
    }
  }

  @override
  bool shouldRepaint(_OrbitPainter old) => old.t != t;
}

class _OParticle {
  const _OParticle(this.radius, this.offset, this.color, this.size);
  final double radius;
  final double offset;
  final Color color;
  final double size;
}

// ─────────────────────────────────────────────────────────────────────────────
// TabTransitionWrapper  –  slide + fade animated tab switch
// ─────────────────────────────────────────────────────────────────────────────
class TabTransitionWrapper extends StatelessWidget {
  const TabTransitionWrapper({
    super.key,
    required this.child,
    required this.tabIndex,
  });
  final Widget child;
  final int tabIndex;

  @override
  Widget build(BuildContext context) {
    return AnimatedSwitcher(
      duration: const Duration(milliseconds: 320),
      transitionBuilder: (child, anim) {
        final slide = Tween<Offset>(
          begin: const Offset(0.04, 0),
          end: Offset.zero,
        ).animate(CurvedAnimation(parent: anim, curve: Curves.easeOutCubic));
        return FadeTransition(
          opacity: anim,
          child: SlideTransition(position: slide, child: child),
        );
      },
      child: KeyedSubtree(key: ValueKey(tabIndex), child: child),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// StorageRingPainter  –  arc showing used vs. free (used in _storage page)
// ─────────────────────────────────────────────────────────────────────────────
class StorageRingPainter extends CustomPainter {
  const StorageRingPainter({required this.fraction, required this.progress});
  final double fraction; // 0.0–1.0 used portion
  final double progress; // animation progress

  @override
  void paint(Canvas canvas, Size size) {
    final cx = size.width / 2;
    final cy = size.height / 2;
    final radius = math.min(cx, cy) - 18;
    const startAngle = -math.pi / 2;
    const sweep = 2 * math.pi;

    // Background track
    canvas.drawCircle(
      Offset(cx, cy),
      radius,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 18
        ..color = kGlass,
    );

    // Used arc (purple → pink)
    final usedSweep = sweep * fraction * progress;
    final rect = Rect.fromCircle(center: Offset(cx, cy), radius: radius);
    final usedPaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 18
      ..strokeCap = StrokeCap.round
      ..shader = const LinearGradient(colors: [kPurple, kPink])
          .createShader(rect);
    canvas.drawArc(rect, startAngle, usedSweep, false, usedPaint);

    // Free arc (cyan → green)
    final freePaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 18
      ..strokeCap = StrokeCap.round
      ..shader = const LinearGradient(colors: [kCyan, kCyan])
          .createShader(rect);
    final freeStart = startAngle + usedSweep;
    final freeSweep = sweep * (1 - fraction) * progress;
    canvas.drawArc(rect, freeStart, freeSweep, false, freePaint);
  }

  @override
  bool shouldRepaint(StorageRingPainter old) =>
      old.fraction != fraction || old.progress != progress;
}

// ─────────────────────────────────────────────────────────────────────────────
// RouterTopologyPainter  –  3 nodes connected with animated dashed lines
// ─────────────────────────────────────────────────────────────────────────────
/// A live traffic view: a local coordinator continuously exchanges small
/// packets with every responsive peer. It intentionally uses one accent so the
/// motion reads as useful telemetry, rather than decorative neon.
class RouterTopologyPainter extends CustomPainter {
  const RouterTopologyPainter(
    this.phase, {
    required this.onlinePeers,
    required this.totalPeers,
  });

  final double phase;
  final int onlinePeers;
  final int totalPeers;

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width * 0.5, size.height * 0.5);
    final peerSlots = math.max(
      3,
      math.min(5, totalPeers == 0 ? 3 : totalPeers),
    );
    final radiusX = size.width * 0.39;
    final radiusY = size.height * 0.32;
    final peers = List<Offset>.generate(peerSlots, (index) {
      final angle = -math.pi / 2 + (2 * math.pi * index / peerSlots);
      return Offset(
        center.dx + math.cos(angle) * radiusX,
        center.dy + math.sin(angle) * radiusY,
      );
    });

    _drawField(canvas, size, center);
    for (var index = 0; index < peers.length; index++) {
      final isLive = index < onlinePeers;
      _drawLink(canvas, center, peers[index], isLive, index);
    }
    _drawNode(canvas, center, kCyan, isHub: true);
    for (var index = 0; index < peers.length; index++) {
      _drawNode(canvas, peers[index], index < onlinePeers ? kGreen : kPurple);
    }
  }

  void _drawField(Canvas canvas, Size size, Offset center) {
    final fill = Paint()
      ..shader = RadialGradient(
        colors: [kCyan.withOpacity(0.08), Colors.transparent],
      ).createShader(Rect.fromCircle(center: center, radius: size.width * .6));
    canvas.drawRect(Offset.zero & size, fill);

    final grid = Paint()
      ..color = Colors.white.withOpacity(0.035)
      ..strokeWidth = 1;
    for (var x = 0.0; x < size.width; x += 28) {
      canvas.drawLine(Offset(x, 0), Offset(x, size.height), grid);
    }
    for (var y = 0.0; y < size.height; y += 28) {
      canvas.drawLine(Offset(0, y), Offset(size.width, y), grid);
    }
  }

  void _drawLink(
    Canvas canvas,
    Offset from,
    Offset to,
    bool isLive,
    int index,
  ) {
    final base = Paint()
      ..color = (isLive ? kCyan : kPurple).withOpacity(isLive ? 0.32 : 0.18)
      ..strokeWidth = 1.2;
    canvas.drawLine(from, to, base);
    if (!isLive) return;

    // A pair of differently phased packets makes the route direction legible.
    for (final packetOffset in [0.0, 0.5]) {
      final progress = (phase + packetOffset + index * 0.17) % 1.0;
      final position = Offset.lerp(from, to, progress)!;
      final glow = Paint()
        ..color = kCyan.withOpacity(0.28)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 7);
      canvas.drawCircle(position, 7, glow);
      canvas.drawCircle(position, 2.8, Paint()..color = kCyan);
    }
  }

  void _drawNode(
    Canvas canvas,
    Offset point,
    Color color, {
    bool isHub = false,
  }) {
    final radius = isHub ? 18.0 : 12.0;
    final halo = Paint()
      ..color = color.withOpacity(isHub ? 0.18 : 0.10)
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 12);
    canvas.drawCircle(point, radius + 7, halo);
    canvas.drawCircle(point, radius, Paint()..color = const Color(0xff14222B));
    canvas.drawCircle(
      point,
      radius,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = isHub ? 2 : 1.5
        ..color = color.withOpacity(0.9),
    );
    canvas.drawCircle(point, isHub ? 4 : 3, Paint()..color = color);
  }

  @override
  bool shouldRepaint(RouterTopologyPainter old) =>
      old.phase != phase ||
      old.onlinePeers != onlinePeers ||
      old.totalPeers != totalPeers;
}

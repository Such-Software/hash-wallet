import 'package:flutter/material.dart';

/// "Transaction sent" celebration: the Hash Bags money sack sits at the bottom
/// and money glyphs erupt from its mouth, rising and fading on a loop.
///
/// The glyphs are image assets (not text) because the app doesn't bundle a font
/// containing a bitcoin glyph — rendering them as PNGs keeps them consistent
/// across platforms.
///
/// The chain glyphs are Monero and Wownero as well as Bitcoin. A Wownero-first
/// wallet that celebrates every send by throwing only bitcoin out of the bag is
/// advertising somebody else's coin on the one screen a user reaches after
/// parting with their own. The XMR and WOW sprites are rendered at 128px from
/// res/pictures/crypto_full_icons/{monero,wownero}.svg, which is the same
/// artwork the chain icons elsewhere in the app use, so they match rather than
/// being a second opinion about what those coins look like.
class HashBagSuccessAnimation extends StatefulWidget {
  const HashBagSuccessAnimation({super.key});

  @override
  State<HashBagSuccessAnimation> createState() => _HashBagSuccessAnimationState();
}

class _Particle {
  final String asset;
  final double dx; // horizontal fan, fraction of width
  final double phase; // stagger, 0..1
  final double size; // fraction of width
  const _Particle(this.asset, this.dx, this.phase, this.size);
}

class _HashBagSuccessAnimationState extends State<HashBagSuccessAnimation>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;

  static const String _hash = 'assets/images/hashbag_sym_hash.png';
  static const String _dollar = 'assets/images/hashbag_sym_dollar.png';
  static const String _btc = 'assets/images/hashbag_sym_btc.png';
  static const String _xmr = 'assets/images/hashbag_sym_xmr.png';
  static const String _wow = 'assets/images/hashbag_sym_wow.png';

  // Ordered by phase, so the stagger stays even as glyphs are added. WOW leads
  // and is the largest: this wallet is Wownero-first and the animation should
  // say so before it says anything else.
  static const List<_Particle> _particles = <_Particle>[
    _Particle(_wow, 0.00, 0.00, 0.20),
    _Particle(_hash, -0.18, 0.10, 0.16),
    _Particle(_xmr, 0.19, 0.20, 0.18),
    _Particle(_dollar, -0.09, 0.30, 0.14),
    _Particle(_btc, 0.13, 0.40, 0.16),
    _Particle(_hash, 0.11, 0.50, 0.12),
    _Particle(_wow, -0.16, 0.60, 0.13),
    _Particle(_dollar, 0.06, 0.70, 0.11),
    _Particle(_xmr, -0.05, 0.80, 0.12),
    _Particle(_btc, 0.16, 0.90, 0.11),
  ];

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2800),
    )..repeat();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (BuildContext context, BoxConstraints constraints) {
        final double w = constraints.maxWidth;
        final double h = constraints.maxHeight;
        // Sack anchored at the bottom (~62% of the height); mouth ≈ its top.
        final double bagH = h * 0.62;
        final double bagW = bagH * 0.825; // hash_bag_base.png aspect (w/h)
        final double bagLeft = (w - bagW) / 2;
        final double bagTop = h - bagH;
        final double mouthX = w / 2;
        final double mouthY = bagTop + bagH * 0.06;

        return AnimatedBuilder(
          animation: _controller,
          builder: (BuildContext context, Widget? _) {
            final List<Widget> children = <Widget>[
              Positioned(
                left: bagLeft,
                top: bagTop,
                width: bagW,
                height: bagH,
                child: Image.asset(
                  'assets/images/hash_bag_base.png',
                  fit: BoxFit.contain,
                ),
              ),
            ];

            for (final _Particle p in _particles) {
              final double t = (_controller.value + p.phase) % 1.0;
              final double sz = w * p.size;
              final double rise = h * 0.52 * t;
              final double spread = w * p.dx * (0.35 + t);
              final double x = mouthX + spread - sz / 2;
              final double y = mouthY - rise - sz / 2;
              final double opacity = (t < 0.15
                      ? t / 0.15
                      : (t > 0.78 ? (1.0 - t) / 0.22 : 1.0))
                  .clamp(0.0, 1.0)
                  .toDouble();
              final double scale = 0.55 + 0.45 * (t < 0.3 ? t / 0.3 : 1.0);

              children.add(
                Positioned(
                  left: x,
                  top: y,
                  width: sz,
                  height: sz,
                  child: Opacity(
                    opacity: opacity,
                    child: Transform.scale(
                      scale: scale,
                      child: Image.asset(p.asset, fit: BoxFit.contain),
                    ),
                  ),
                ),
              );
            }

            return Stack(clipBehavior: Clip.none, children: children);
          },
        );
      },
    );
  }
}

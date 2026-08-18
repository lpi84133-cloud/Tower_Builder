import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import '../../app/asset_paths.dart';
import '../../app/brand.dart';
import '../../app/format.dart';
import '../../app/palette.dart';
import '../../app/type_scale.dart';
import '../../build_site/district.dart';
import '../../build_site/risk_tier.dart';
import '../../build_site/run_director.dart';
import '../../build_site/site_canvas.dart';
import '../../build_site/site_entities.dart';
import '../../build_site/site_metrics.dart';
import '../../build_site/sprite_bank.dart';
import '../../state/architect.dart';
import '../../state/audio_desk.dart';
import '../../state/contract_board.dart';
import '../../state/rival_firms.dart';
import '../widgets/budget_dial.dart';
import '../widgets/gloss_button.dart';
import '../widgets/hazard_trim.dart';
import '../widgets/payout_sheet.dart';
import '../widgets/plate_button.dart';
import '../widgets/promotion_banner.dart';
import '../widgets/risk_selector.dart';
import '../widgets/run_bar.dart';
import '../widgets/site_chrome.dart';

/// The playable site: a painted crane and frame under a HUD that plans the build
/// while idle and drives it once ground is broken.
class RunScreen extends StatefulWidget {
  const RunScreen({super.key});

  @override
  State<RunScreen> createState() => _RunScreenState();
}

class _RunScreenState extends State<RunScreen>
    with SingleTickerProviderStateMixin {
  RunDirector? _director;
  late final Ticker _ticker;
  Duration _lastFrame = Duration.zero;

  final math.Random _rng = math.Random();
  int _budget = 100;
  String? _notice;
  Timer? _noticeTimer;
  Promotion? _promotion;

  @override
  void initState() {
    super.initState();
    SystemChrome.setPreferredOrientations(const [
      DeviceOrientation.portraitUp,
      DeviceOrientation.portraitDown,
    ]);

    final architect = context.read<Architect>();
    _budget = architect.lastBudget
        .clamp(SiteMetrics.minBudget, SiteMetrics.maxBudget);
    // Never carry a budget larger than the balance into the dial.
    if (architect.brix >= SiteMetrics.minBudget && _budget > architect.brix) {
      _budget = architect.brix;
    }

    _ticker = createTicker(_onFrame);
    _spinUp();
  }

  Future<void> _spinUp() async {
    await SpriteBank.shared.warmUp();
    if (!mounted) return;

    final architect = context.read<Architect>();
    final director = RunDirector(
      sprites: SpriteBank.shared,
      pickFacade: _nextFacade,
      plan: architect.riskPlan,
    )
      ..onCue = _playCue
      ..onStoreySeated = _storeySeated
      ..onCollapse = _collapsed
      ..onSignOff = _signedOff;

    setState(() => _director = director);
    _ticker.start();
    await context.read<AudioDesk>().playBed(Bed.site);
  }

  void _onFrame(Duration elapsed) {
    final dt = _lastFrame == Duration.zero
        ? 0.0
        : (elapsed - _lastFrame).inMicroseconds / 1e6;
    _lastFrame = elapsed;
    _director?.advance(dt);
  }

  /// Which facade the crane hoists next. Mixed delivery — the default — pulls
  /// whatever the yard sends, so a tower is a jumble of every facade in the
  /// pack. Buying a kit is what buys a uniform tower.
  int _nextFacade() {
    final architect = context.read<Architect>();
    final chosen = architect.activeKit;
    if (chosen != 0 && architect.ownsKit(chosen)) return chosen;
    return 1 + _rng.nextInt(Art.moduleCount);
  }

  // --- director callbacks ---------------------------------------------------
  void _playCue(SiteCue cue) {
    final desk = context.read<AudioDesk>();
    switch (cue) {
      case SiteCue.release:
        desk.shot(Cue.release);
      case SiteCue.seat:
        desk.shot(Cue.seat);
        desk.buzz();
      case SiteCue.storey:
        desk.shot(Cue.storey);
      case SiteCue.payout:
        desk.shot(Cue.payout);
        desk.buzz();
      case SiteCue.collapse:
        desk.shot(Cue.collapse);
        desk.buzz(heavy: true);
    }
  }

  Future<void> _storeySeated(int storeys) async {
    final board = context.read<ContractBoard>();
    board.onStoreySeated(storeys);
    final bonus = _director?.bonus;
    if (bonus != null) board.onBonusReached(bonus);
    final promotion = await context.read<Architect>().awardXp(
          SiteMetrics.xpPerStorey,
        );
    if (promotion.happened) _celebrate(promotion);
  }

  Future<void> _collapsed(int storeys) async {
    await context.read<Architect>().logJob(
          payout: 0,
          storeys: storeys,
          signedOff: false,
        );
    if (!mounted) return;
    await context
        .read<RivalFirms>()
        .recordJob(height: storeys, earnings: 0);
  }

  Future<void> _signedOff(int storeys, int payout) async {
    final architect = context.read<Architect>();
    context.read<ContractBoard>().onSignOff(
          payout: payout,
          tier: architect.riskTier,
        );
    await architect.credit(payout);
    await architect.logJob(payout: payout, storeys: storeys, signedOff: true);
    final promotion = await architect.awardXp(SiteMetrics.xpPerSignOff);
    if (!mounted) return;
    await context
        .read<RivalFirms>()
        .recordJob(height: storeys, earnings: payout);
    if (promotion.happened) _celebrate(promotion);
  }

  void _celebrate(Promotion promotion) {
    if (!mounted) return;
    context.read<AudioDesk>().shot(Cue.rankUp);
    setState(() => _promotion = promotion);
  }

  void _flash(String message) {
    _noticeTimer?.cancel();
    setState(() => _notice = message);
    _noticeTimer = Timer(const Duration(seconds: 3), () {
      if (mounted) setState(() => _notice = null);
    });
  }

  // --- player actions -------------------------------------------------------
  Future<void> _primaryAction() async {
    final director = _director;
    if (director == null) return;
    final phase = director.board.value.phase;

    if (phase == RunPhase.swinging) {
      director.place();
      return;
    }
    if (phase != RunPhase.planning) return;

    final architect = context.read<Architect>();
    final desk = context.read<AudioDesk>();
    if (architect.brix < _budget) {
      desk.shot(Cue.collapse);
      _flash('Budget is above your balance. Lower it or take the daily '
          'check-in in the yard.');
      return;
    }
    desk.shot(Cue.tap);
    await architect.debit(_budget);
    await architect.rememberBudget(_budget);
    if (!mounted) return;
    context.read<ContractBoard>().onGroundBroken();
    director.breakGround(_budget);
  }

  void _signOff() => _director?.signOff();

  void _nextBuild() {
    context.read<AudioDesk>().shot(Cue.tap);
    _director?.clearSite();
  }

  Future<void> _leaveSite() async {
    context.read<AudioDesk>().shot(Cue.tap);
    await context.read<AudioDesk>().playBed(Bed.shell);
    if (mounted) Navigator.of(context).maybePop();
  }

  /// The site briefing: what the current plan promises, and where the frame
  /// stands. Kept behind a tap so the deck can stay as clear as the reference,
  /// without hiding the odds from the player.
  Future<void> _openBriefing() async {
    final director = _director;
    if (director == null) return;
    final architect = context.read<Architect>();
    final desk = context.read<AudioDesk>();
    desk.shot(Cue.tap);
    final board = director.board.value;
    final plan = architect.riskPlan;

    await showModalBottomSheet<void>(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (context) => Container(
        padding: const EdgeInsets.fromLTRB(18, 16, 18, 22),
        decoration: Frames.panel(radius: 22),
        child: SafeArea(
          top: false,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('${plan.name} plan', style: Type.slab(size: 22)),
              const SizedBox(height: 4),
              Text(plan.blurb, style: Type.body(size: 12)),
              const SizedBox(height: 14),
              _BriefRow(
                label: 'Chance each storey holds',
                value: Fmt.percent(plan.holdChance),
              ),
              _BriefRow(
                label: 'Bonus rolled per storey',
                value: '${Fmt.mult(plan.bonusMin)} \u2013 '
                    '${Fmt.mult(plan.bonusMax)}',
              ),
              _BriefRow(
                label: '${Brand.storey}s standing',
                value: '${board.storeys}',
              ),
              _BriefRow(
                label: '${Brand.bonus} so far',
                value: Fmt.mult(board.bonus),
              ),
              _BriefRow(
                label: '${Brand.budget} committed',
                value: '${Fmt.amount(board.budget)} ${Brand.currency}',
              ),
              const SizedBox(height: 12),
              const SimulationNote(dense: true),
            ],
          ),
        ),
      ),
    );
  }

  void _switchPlan(RiskTier tier) {
    context.read<AudioDesk>().shot(Cue.tap);
    context.read<Architect>().setRiskTier(tier);
    _director?.adoptPlan(RiskPlan.of(tier));
  }

  @override
  void dispose() {
    _noticeTimer?.cancel();
    _ticker.dispose();
    _director?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final architect = context.watch<Architect>();
    final district = architect.district;
    final director = _director;

    return Scaffold(
      backgroundColor: district.horizon,
      body: DecoratedBox(
        // Guarantees a sky behind everything, even before the first paint.
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [district.zenith, district.horizon],
          ),
        ),
        child: director == null
            ? const Center(child: CircularProgressIndicator(color: Hue.chalk))
            : Stack(
                fit: StackFit.expand,
                children: [
                  Positioned.fill(
                    child: GestureDetector(
                      behavior: HitTestBehavior.opaque,
                      onTap: () {
                        if (director.board.value.phase == RunPhase.swinging) {
                          _primaryAction();
                        }
                      },
                      child: CustomPaint(
                        painter: SiteCanvas(
                          director: director,
                          zenith: district.zenith,
                          horizon: district.horizon,
                        ),
                      ),
                    ),
                  ),
                  Align(
                    alignment: Alignment.topCenter,
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        RunBar(
                          brix: architect.brix,
                          rank: architect.rank,
                          rankTitle: architect.rankTitle,
                          rankProgress: architect.rankProgress,
                          plan: architect.riskPlan,
                          onLeave: _leaveSite,
                        ),
                        Padding(
                          padding: const EdgeInsets.fromLTRB(0, 10, 14, 0),
                          child: Align(
                            alignment: Alignment.centerRight,
                            child: _BriefingTap(onTap: _openBriefing),
                          ),
                        ),
                      ],
                    ),
                  ),
                  Align(
                    alignment: const Alignment(0, -0.42),
                    child: _RollHeadline(board: director.board),
                  ),
                  ValueListenableBuilder<RunBoard>(
                    valueListenable: director.board,
                    builder: (context, board, _) {
                      if (board.rolls.isEmpty) return const SizedBox.shrink();
                      return Align(
                        alignment: const Alignment(0.95, -0.04),
                        child: _RollLog(rolls: board.rolls),
                      );
                    },
                  ),
                  ValueListenableBuilder<RunBoard>(
                    valueListenable: director.board,
                    builder: (context, board, _) => Align(
                      alignment: Alignment.bottomCenter,
                      child: _Controls(
                        board: board,
                        budget: _budget,
                        balance: architect.brix,
                        tier: architect.riskTier,
                        district: district,
                        onBudget: (value) => setState(() => _budget = value),
                        onPrimary: _primaryAction,
                        onSignOff: _signOff,
                        onTier: _switchPlan,
                      ),
                    ),
                  ),
                  ValueListenableBuilder<RunBoard>(
                    valueListenable: director.board,
                    builder: (context, board, _) {
                      if (!board.verdictReady ||
                          board.phase != RunPhase.signedOff) {
                        return const SizedBox.shrink();
                      }
                      return PayoutSheet(
                        storeys: board.storeys,
                        bonus: board.bonus,
                        payout: board.projected,
                        onNextBuild: _nextBuild,
                        onLeaveSite: _leaveSite,
                      );
                    },
                  ),
                  if (_notice != null)
                    Align(
                      alignment: const Alignment(0, 0.32),
                      child: _Notice(text: _notice!),
                    ),
                  if (_promotion != null)
                    PromotionBanner(
                      key: ValueKey(_promotion!.rank),
                      promotion: _promotion!,
                      onFinished: () {
                        if (mounted) setState(() => _promotion = null);
                      },
                    ),
                ],
              ),
      ),
    );
  }
}

/// Round affordance under the top bar that opens the site briefing.
class _BriefingTap extends StatelessWidget {
  const _BriefingTap({required this.onTap});

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 38,
        height: 38,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          gradient: const LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [Hue.glaze, Hue.glazeDeep],
          ),
          border: Border.all(color: Hue.glazeEdge, width: 2),
          boxShadow: const [
            BoxShadow(color: Color(0x59000000), blurRadius: 7, offset: Offset(0, 3)),
          ],
        ),
        child: const Icon(Icons.more_horiz_rounded, size: 21, color: Colors.white),
      ),
    );
  }
}

/// Bottom control deck. Planning shows the plan tabs, the budget row and the
/// plated BUILD action; a live build swaps the budget row for the frame readout
/// and pairs BUILD with SIGN OFF.
class _Controls extends StatelessWidget {
  const _Controls({
    required this.board,
    required this.budget,
    required this.balance,
    required this.tier,
    required this.district,
    required this.onBudget,
    required this.onPrimary,
    required this.onSignOff,
    required this.onTier,
  });

  final RunBoard board;
  final int budget;
  final int balance;
  final RiskTier tier;
  final District district;
  final ValueChanged<int> onBudget;
  final VoidCallback onPrimary;
  final VoidCallback onSignOff;
  final ValueChanged<RiskTier> onTier;

  @override
  Widget build(BuildContext context) {
    if (board.phase == RunPhase.signedOff ||
        board.phase == RunPhase.collapsed) {
      return const SizedBox.shrink();
    }

    final planning = board.phase == RunPhase.planning;
    final airborne = board.phase == RunPhase.falling;

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        const HazardTrim(),
        Container(
          width: double.infinity,
          padding: const EdgeInsets.fromLTRB(12, 12, 12, 0),
          decoration: const BoxDecoration(
            gradient: Hue.rigWash,
            boxShadow: [BoxShadow(color: Colors.black45, blurRadius: 10)],
          ),
          child: SafeArea(
            top: false,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: planning
                  ? [
                      RiskSelector(selected: tier, onSelect: onTier, dense: true),
                      const SizedBox(height: 9),
                      BudgetDial(
                        budget: budget,
                        balance: balance,
                        onChanged: onBudget,
                        onNudge: () => context.read<AudioDesk>().shot(Cue.tap),
                      ),
                      const SizedBox(height: 10),
                      PlateButton(
                        label: Brand.actionBuild,
                        height: 70,
                        onPressed: onPrimary,
                      ),
                      const SizedBox(height: 7),
                      Text(
                        '${district.name} \u00B7 ${Fmt.amount(budget)} '
                        '${Brand.currency} \u00B7 simulation only, no cash value',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: Type.body(size: 10, color: Hue.chalkDim),
                      ),
                      const SizedBox(height: 4),
                    ]
                  : [
                      // A live build shows nothing but the two calls to make:
                      // bank what is on the frame, or hoist one more module.
                      Row(
                        children: [
                          Expanded(
                            child: GlossButton(
                              label: Brand.actionSignOff,
                              sublabel: '${Fmt.amount(board.projected)} '
                                  '${Brand.currency}',
                              height: 62,
                              fontSize: 19,
                              onPressed: board.canSignOff ? onSignOff : null,
                            ),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: PlateButton(
                              label: Brand.actionBuild,
                              height: 62,
                              onPressed: airborne ? null : onPrimary,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 6),
                    ],
            ),
          ),
        ),
      ],
    );
  }
}

/// Newest-first list of the per-storey rolls for the current frame. Sits loose
/// against the right edge over the sky, with no panel behind it, so it never
/// covers the frame the player is watching.
class _RollLog extends StatelessWidget {
  const _RollLog({required this.rolls});

  final List<double> rolls;

  static const _card = Color(0xFFEDE9C6);
  static const _cardEdge = Color(0xFF8B8D4E);
  static const _cardInk = Color(0xFF3B3B22);

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.end,
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          'Results',
          style: Type.label(size: 12, tracking: 0.4).copyWith(
            shadows: const [
              Shadow(color: Color(0x99000000), blurRadius: 4, offset: Offset(0, 1)),
            ],
          ),
        ),
        const SizedBox(height: 5),
        for (final roll in rolls.take(6))
          Padding(
            padding: const EdgeInsets.only(bottom: 5),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
              decoration: BoxDecoration(
                color: _card,
                borderRadius: BorderRadius.circular(9),
                border: Border.all(color: _cardEdge, width: 1.4),
                boxShadow: const [
                  BoxShadow(color: Color(0x40000000), blurRadius: 4, offset: Offset(0, 2)),
                ],
              ),
              child: Text(Fmt.roll(roll),
                  style: Type.figure(size: 13, color: _cardInk)),
            ),
          ),
      ],
    );
  }
}

/// The transient headline: the storey's own roll on a seat, or a struck-through
/// zero when the frame fails.
class _RollHeadline extends StatefulWidget {
  const _RollHeadline({required this.board});

  final ValueListenable<RunBoard> board;

  @override
  State<_RollHeadline> createState() => _RollHeadlineState();
}

class _RollHeadlineState extends State<_RollHeadline>
    with SingleTickerProviderStateMixin {
  late final AnimationController _pop = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1250),
  );

  int _seenStoreys = 0;
  RunPhase _seenPhase = RunPhase.planning;
  String _text = '';
  Color _tint = Hue.amber;

  @override
  void initState() {
    super.initState();
    widget.board.addListener(_onBoard);
  }

  void _onBoard() {
    final board = widget.board.value;
    if (board.phase == RunPhase.planning) {
      _seenStoreys = 0;
    } else if (board.phase == RunPhase.collapsed &&
        _seenPhase != RunPhase.collapsed) {
      _fire('x0', Hue.rust);
    } else if ((board.phase == RunPhase.swinging ||
            board.phase == RunPhase.falling) &&
        board.storeys != _seenStoreys &&
        board.storeys >= 1) {
      _seenStoreys = board.storeys;
      _fire(Fmt.mult(board.lastRoll), Hue.amber);
    }
    _seenPhase = board.phase;
  }

  void _fire(String text, Color tint) {
    _text = text;
    _tint = tint;
    _pop.forward(from: 0);
  }

  @override
  void dispose() {
    widget.board.removeListener(_onBoard);
    _pop.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _pop,
      builder: (context, _) {
        final t = _pop.value;
        if (t == 0 || t >= 1) return const SizedBox.shrink();
        // Overshoot in, hold, drift up and fade out.
        final entry = Curves.elasticOut.transform((t / 0.34).clamp(0.0, 1.0));
        final fade = t < 0.7 ? 1.0 : (1 - (t - 0.7) / 0.3).clamp(0.0, 1.0);
        return Transform.translate(
          offset: Offset(0, -26 * (1 - fade)),
          child: Opacity(
            opacity: fade,
            child: Transform.scale(
              scale: 0.55 + entry * 0.45,
              child: Text(_text, style: Type.slab(size: 76, color: _tint)),
            ),
          ),
        );
      },
    );
  }
}

class _BriefRow extends StatelessWidget {
  const _BriefRow({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        children: [
          Expanded(child: Text(label, style: Type.body(size: 12))),
          const SizedBox(width: 10),
          Text(value, style: Type.figure(size: 14, color: Hue.amber)),
        ],
      ),
    );
  }
}

class _Notice extends StatelessWidget {
  const _Notice({required this.text});

  final String text;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 28),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: Frames.panel(radius: 16, edge: Hue.amber),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.report_gmailerrorred_rounded,
              size: 18, color: Hue.amber),
          const SizedBox(width: 9),
          Flexible(
            child: Text(text,
                style: Type.body(size: 12, color: Hue.chalk, height: 1.3)),
          ),
        ],
      ),
    );
  }
}

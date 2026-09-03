import 'dart:async';
import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:palette_generator/palette_generator.dart';

import '../l10n/app_localizations.dart';
import '../providers/library_provider.dart';
import '../services/audio_player_service.dart';
import '../services/download_service.dart';
import '../services/chromecast_service.dart';
import '../widgets/book_detail_sheet.dart';
import '../widgets/notes_sheet.dart';
import '../widgets/overlay_toast.dart';
import '../widgets/sleep_timer_sheet.dart';

// ─── Route ───────────────────────────────────────────────────

class PlayerScreenRoute extends PageRoute<void> {
  final Widget child;
  PlayerScreenRoute({required this.child});

  @override
  Color? get barrierColor => null;
  @override
  String? get barrierLabel => null;
  @override
  bool get maintainState => true;
  @override
  bool get opaque => true;

  @override
  Duration get transitionDuration => const Duration(milliseconds: 350);
  @override
  Duration get reverseTransitionDuration => const Duration(milliseconds: 300);

  @override
  Widget buildPage(BuildContext context, Animation<double> animation,
          Animation<double> secondaryAnimation) =>
      child;

  @override
  Widget buildTransitions(
      BuildContext context,
      Animation<double> animation,
      Animation<double> secondaryAnimation,
      Widget child) {
    final curved = CurvedAnimation(
        parent: animation,
        curve: Curves.easeOutCubic,
        reverseCurve: Curves.easeInCubic);
    return SlideTransition(
      position: Tween<Offset>(
              begin: const Offset(0, 0.15), end: Offset.zero)
          .animate(curved),
      child: FadeTransition(opacity: curved, child: child),
    );
  }
}

// ─── Player Screen ───────────────────────────────────────────

class PlayerScreen extends StatefulWidget {
  final Map<String, dynamic> item;
  final AudioPlayerService player;

  const PlayerScreen({
    super.key,
    required this.item,
    required this.player,
  });

  @override
  State<PlayerScreen> createState() => _PlayerScreenState();
}

class _PlayerScreenState extends State<PlayerScreen> {
  Color _dominantColor = const Color(0xFF1A1A2E);
  Color _accentColor = const Color(0xFFE94560);

  late String _currentItemId;
  late String? _currentEpisodeId;
  Route<dynamic>? _ownRoute;

  double _speed = 1.0;
  final List<double> _speedPresets = PlayerSettings.defaultSpeedPresets;

  // Skip intro/outro settings (seconds)
  int _skipIntroTime = 0;
  int _skipOutroTime = 0;

  // Position tracking
  Duration _position = Duration.zero;
  StreamSubscription<Duration>? _positionSub;

  bool get _isActive =>
      widget.player.currentItemId == _currentItemId &&
      (_currentEpisodeId == null ||
          widget.player.currentEpisodeId == _currentEpisodeId);

  @override
  void initState() {
    super.initState();
    _item = widget.item;
    _currentItemId = widget.player.currentItemId ?? '';
    _currentEpisodeId = widget.player.currentEpisodeId;
    _speed = widget.player.speed;

    widget.player.addListener(_onPlayerChanged);
    ChromecastService().addListener(_onPlayerChanged);
    _extractDominantColor();
    _startPositionTracking();
  }

  late Map<String, dynamic> _item;

  String get _itemId => _item['id'] as String? ?? '';
  Map<String, dynamic> get _media =>
      _item['media'] as Map<String, dynamic>? ?? {};
  Map<String, dynamic> get _metadata =>
      _media['metadata'] as Map<String, dynamic>? ?? {};
  String get _title => _metadata['title'] as String? ?? 'Unknown';
  String get _author => _metadata['authorName'] as String? ?? '';
  double get _duration =>
      (_media['duration'] as num?)?.toDouble() ?? 0;
  List<dynamic> get _chapters {
    final inline = _media['chapters'] as List<dynamic>? ?? [];
    if (inline.isNotEmpty) return inline;
    if (_isActive && widget.player.chapters.isNotEmpty) {
      return widget.player.chapters;
    }
    return [];
  }

  Map<String, dynamic>? get _recentEpisode =>
      _item['recentEpisode'] as Map<String, dynamic>?;
  String? get _episodeId {
    final re = _recentEpisode;
    if (re != null) return re['id'] as String?;
    return null;
  }

  String? get _coverUrl {
    final lib = context.read<LibraryProvider>();
    final localCover =
        DownloadService().getInfo(_itemId).localCoverPath;
    if (localCover != null && File(localCover).existsSync()) {
      return localCover;
    }
    if (_isActive) {
      final playingCover = widget.player.currentCoverUrl;
      if (playingCover != null && playingCover.isNotEmpty) {
        return playingCover;
      }
    }
    return lib.getCoverUrl(_itemId, width: 1200);
  }

  bool get _isLocalCover =>
      _coverUrl != null && _coverUrl!.startsWith('/');

  @override
  void dispose() {
    widget.player.removeListener(_onPlayerChanged);
    ChromecastService().removeListener(_onPlayerChanged);
    _positionSub?.cancel();
    super.dispose();
  }

  void _onPlayerChanged() {
    if (!mounted) return;

    final newItemId = widget.player.currentItemId;
    final newEpisodeId = widget.player.currentEpisodeId;

    if (newItemId != _currentItemId ||
        newEpisodeId != _currentEpisodeId) {
      setState(() {
        _currentItemId = newItemId ?? '';
        _currentEpisodeId = newEpisodeId;
        _extractDominantColor();
      });
    }

    setState(() {
      _speed = widget.player.speed;
    });
  }

  void _startPositionTracking() {
    _positionSub?.cancel();
    _positionSub = widget.player.absolutePositionStream.listen((pos) {
      if (mounted && _isActive) {
        setState(() {
          _position = pos;
        });
      }
    });
  }

  Future<void> _extractDominantColor() async {
    final url = _coverUrl;
    if (url == null) return;

    try {
      final ImageProvider provider;
      if (url.startsWith('/')) {
        provider = FileImage(File(url));
      } else {
        final lib = context.read<LibraryProvider>();
        provider = CachedNetworkImageProvider(
            url, headers: lib.mediaHeaders);
      }

      final palette = await PaletteGenerator.fromImageProvider(
        provider,
        maximumColorCount: 16,
      );

      if (!mounted) return;

      final vibrant = palette.vibrantColor ??
          palette.lightVibrantColor ??
          palette.darkVibrantColor;
      final dominant = palette.dominantColor;

      // Pick the most prominent colorful swatch
      PaletteColor? best;
      for (final pc in palette.paletteColors) {
        final hsv = HSVColor.fromColor(pc.color);
        if (hsv.saturation < 0.15) continue;
        if (hsv.value < 0.12) continue;
        if (best == null || pc.population > best.population) best = pc;
      }

      final seedColor =
          vibrant?.color ?? best?.color ?? dominant?.color;

      if (seedColor != null && mounted) {
        final brightness = Theme.of(context).brightness;
        final scheme =
            ColorScheme.fromSeed(seedColor: seedColor, brightness: brightness);
        setState(() {
          _accentColor = scheme.primary;
          _dominantColor = _darkenColor(scheme.primaryContainer, 0.3);
        });
      }
    } catch (_) {}
  }

  Color _darkenColor(Color color, [double amount = 0.3]) {
    final hsl = HSLColor.fromColor(color);
    return hsl
        .withLightness((hsl.lightness - amount).clamp(0.0, 1.0))
        .toColor();
  }

  void _dismiss() {
    if (!mounted) return;
    final nav = Navigator.of(context, rootNavigator: true);
    if (_ownRoute != null) {
      nav.popUntil((route) => route == _ownRoute);
    } else {
      nav.maybePop();
    }
  }

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context)!;

    _ownRoute ??= ModalRoute.of(context);

    final playerPosSec = _isActive
        ? widget.player.position.inMilliseconds / 1000.0
        : _position.inMilliseconds / 1000.0;
    final totalDurSec = _isActive
        ? widget.player.totalDuration
        : _duration;

    final currentChapter = _currentChapterName();

    return PopScope(
      canPop: true,
      onPopInvokedWithResult: (didPop, _) {
        if (didPop) _dismiss();
      },
      child: Scaffold(
        backgroundColor: _dominantColor,
        body: Container(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [_dominantColor, _dominantColor.withValues(alpha: 0.8)],
            ),
          ),
          child: GestureDetector(
          onVerticalDragEnd: (details) {
            final vy = details.primaryVelocity ?? 0;
            if (vy > 300) _dismiss();
          },
          child: SafeArea(
            child: Column(
              children: [
                _buildTopBar(l),
                Expanded(
                  child: Column(
                    children: [
                      const SizedBox(height: 16),
                      _buildAlbumArt(l),
                      const SizedBox(height: 12),
                      if (currentChapter != null)
                        Padding(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 24),
                          child: Text(
                            currentChapter,
                            style: TextStyle(
                              color: Colors.white
                                  .withValues(alpha: 0.7),
                              fontSize: 13,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      const SizedBox(height: 4),
                      _buildTitleSection(l),
                      const SizedBox(height: 16),
                      _buildFunctionButtons(l),
                      const SizedBox(height: 20),
                      _buildProgressBar(
                          playerPosSec, totalDurSec, l),
                      const SizedBox(height: 16),
                      _buildBottomControls(l),
                      const SizedBox(height: 24),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    ),
  );
  }

  // ── Top bar ──
  Widget _buildTopBar(AppLocalizations l) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      child: Row(
        children: [
          IconButton(
            icon: Icon(Icons.keyboard_arrow_down_rounded,
                color: Colors.white.withValues(alpha: 0.8), size: 32),
            onPressed: _dismiss,
          ),
          Expanded(
            child: Text(
              widget.player.currentTitle ?? _title,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 16,
                fontWeight: FontWeight.w600,
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              textAlign: TextAlign.center,
            ),
          ),
          IconButton(
            icon: Icon(Icons.share_rounded,
                color: Colors.white.withValues(alpha: 0.7), size: 22),
            onPressed: () {
              showOverlayToast(
                  context, '分享',
                  icon: Icons.share_rounded);
            },
          ),
        ],
      ),
    );
  }

  // ── Album art ──
  Widget _buildAlbumArt(AppLocalizations l) {
    final albumSize = MediaQuery.of(context).size.height * 0.45;
    return Center(
      child: Container(
        width: albumSize,
        height: albumSize,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(24),
          boxShadow: [
            BoxShadow(
              color: _accentColor.withValues(alpha: 0.3),
              blurRadius: 40,
              spreadRadius: -5,
            ),
          ],
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(24),
          child: _coverUrl != null
              ? _isLocalCover
                  ? Image.file(
                      File(_coverUrl!),
                      fit: BoxFit.cover,
                      errorBuilder: (_, __, ___) =>
                          _coverPlaceholder(l),
                    )
                  : CachedNetworkImage(
                      imageUrl: _coverUrl!,
                      fit: BoxFit.cover,
                      httpHeaders:
                          context.read<LibraryProvider>().mediaHeaders,
                      placeholder: (_, __) =>
                          _coverPlaceholder(l),
                      errorWidget: (_, __, ___) =>
                          _coverPlaceholder(l),
                    )
              : _coverPlaceholder(l),
        ),
      ),
    );
  }

  Widget _coverPlaceholder(AppLocalizations l) {
    return Container(
      color: _dominantColor.withValues(alpha: 0.8),
      child: Center(
        child: Icon(
          Icons.headphones_rounded,
          size: 80,
          color: Colors.white.withValues(alpha: 0.2),
        ),
      ),
    );
  }

  // ── Title section ──
  Widget _buildTitleSection(AppLocalizations l) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 32),
      child: Column(
        children: [
          Text(
            widget.player.currentTitle ?? _title,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 20,
              fontWeight: FontWeight.bold,
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 4),
          Text(
            widget.player.currentAuthor ?? _author,
            style: TextStyle(
              color: Colors.white.withValues(alpha: 0.6),
              fontSize: 14,
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  // ── Function buttons row: Download, Speed, Bookmark, Skip Intro/Outro, More ──
  Widget _buildFunctionButtons(AppLocalizations l) {
    final isDownloaded = DownloadService().isDownloaded(
        _episodeId != null ? '$_itemId-$_episodeId' : _itemId);

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 32),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
        children: [
          _funcButton(
            icon: isDownloaded
                ? Icons.download_done_rounded
                : Icons.download_rounded,
            label: isDownloaded ? l.saved : l.downloads,
            color: isDownloaded ? Colors.greenAccent : null,
            onTap: () {},
          ),
          _speedButton(l),
          _funcButton(
            icon: Icons.bookmark_border_rounded,
            label: l.bookmark,
            onTap: () {
              _showBookmarkDialog(l);
            },
          ),
          _funcButton(
            icon: Icons.skip_next_rounded,
            label: l.skipIntroSettings,
            onTap: () {
              _showSkipIntroOutroSettings(l);
            },
          ),
          _funcButton(
            icon: Icons.more_horiz_rounded,
            label: l.more,
            onTap: () => _showMoreOptions(l),
          ),
        ],
      ),
    );
  }

  Widget _funcButton({
    required IconData icon,
    required String label,
    Color? color,
    VoidCallback? onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon,
              color: color ??
                  Colors.white.withValues(alpha: 0.7),
              size: 24),
          const SizedBox(height: 4),
          Text(
            label,
            style: TextStyle(
              color: Colors.white.withValues(alpha: 0.5),
              fontSize: 11,
            ),
          ),
        ],
      ),
    );
  }

  Widget _speedButton(AppLocalizations l) {
    return GestureDetector(
      onTap: () => _showSpeedPicker(l),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            padding:
                const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Text(
              '${_speed.toStringAsFixed(1)}x',
              style: const TextStyle(
                color: Colors.white,
                fontSize: 13,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
          const SizedBox(height: 4),
          Text(
            l.speed,
            style: TextStyle(
              color: Colors.white.withValues(alpha: 0.5),
              fontSize: 11,
            ),
          ),
        ],
      ),
    );
  }

  void _showSpeedPicker(AppLocalizations l) {
    showModalBottomSheet(
      context: context,
      backgroundColor: const Color(0xFF1E1E2E),
      shape: const RoundedRectangleBorder(
        borderRadius:
            BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (ctx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Padding(
              padding: const EdgeInsets.all(16),
              child: Text(
                l.speed,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
            ..._speedPresets.map((preset) => ListTile(
                  title: Text(
                    '${preset.toStringAsFixed(2)}x',
                    style: TextStyle(
                      color: (_speed - preset).abs() < 0.01
                          ? _accentColor
                          : Colors.white,
                      fontWeight: (_speed - preset).abs() < 0.01
                          ? FontWeight.bold
                          : FontWeight.normal,
                    ),
                  ),
                  trailing: (_speed - preset).abs() < 0.01
                      ? Icon(Icons.check, color: _accentColor)
                      : null,
                  onTap: () async {
                    await widget.player.setSpeed(preset);
                    setState(() => _speed = preset);
                    Navigator.pop(ctx);
                  },
                )),
            const SizedBox(height: 16),
          ],
        ),
      ),
    );
  }

  void _showBookmarkDialog(AppLocalizations l) {
    showOverlayToast(
      context,
      l.bookmark,
      icon: Icons.bookmark_added_rounded,
    );
  }

  void _showMoreOptions(AppLocalizations l) {
    showModalBottomSheet(
      context: context,
      backgroundColor: const Color(0xFF1E1E2E),
      shape: const RoundedRectangleBorder(
        borderRadius:
            BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (ctx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.book_rounded,
                  color: Colors.white70),
              title: Text(l.bookDetailsLabel,
                  style: const TextStyle(color: Colors.white)),
              onTap: () {
                Navigator.pop(ctx);
                showBookDetailSheet(context, _itemId);
              },
            ),
            ListTile(
              leading: const Icon(Icons.share_rounded,
                  color: Colors.white70),
              title: const Text('分享',
                  style: TextStyle(color: Colors.white)),
              onTap: () {
                Navigator.pop(ctx);
                showOverlayToast(context, '分享',
                    icon: Icons.share_rounded);
              },
            ),
            ListTile(
              leading: const Icon(Icons.speed_rounded,
                  color: Colors.white70),
              title: Text(l.skipIntroSettings,
                  style: const TextStyle(color: Colors.white)),
              onTap: () {
                Navigator.pop(ctx);
                _showSkipIntroOutroSettings(l);
              },
            ),
          ],
        ),
      ),
    );
  }

  void _showSkipIntroOutroSettings(AppLocalizations l) {
    int introVal = _skipIntroTime;
    int outroVal = _skipOutroTime;

    showModalBottomSheet(
      context: context,
      backgroundColor: const Color(0xFF1E1E2E),
      shape: const RoundedRectangleBorder(
        borderRadius:
            BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setSheetState) => SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  l.skipIntroSettings,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 16),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(l.skipIntro,
                        style: const TextStyle(
                            color: Colors.white70, fontSize: 15)),
                    Text('$introVal${l.seconds}',
                        style: TextStyle(
                            color: _accentColor,
                            fontSize: 15,
                            fontWeight: FontWeight.bold)),
                  ],
                ),
                Slider(
                  value: introVal.toDouble(),
                  min: 0,
                  max: 120,
                  divisions: 24,
                  activeColor: _accentColor,
                  onChanged: (v) {
                    setSheetState(() => introVal = v.round());
                  },
                ),
                const SizedBox(height: 8),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(l.skipOutro,
                        style: const TextStyle(
                            color: Colors.white70, fontSize: 15)),
                    Text('$outroVal${l.seconds}',
                        style: TextStyle(
                            color: _accentColor,
                            fontSize: 15,
                            fontWeight: FontWeight.bold)),
                  ],
                ),
                Slider(
                  value: outroVal.toDouble(),
                  min: 0,
                  max: 120,
                  divisions: 24,
                  activeColor: _accentColor,
                  onChanged: (v) {
                    setSheetState(() => outroVal = v.round());
                  },
                ),
                const SizedBox(height: 12),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: _accentColor,
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    onPressed: () {
                      setState(() {
                        _skipIntroTime = introVal;
                        _skipOutroTime = outroVal;
                      });
                      Navigator.pop(ctx);
                    },
                    child: Text(l.save),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  // ── Progress bar ──
  Widget _buildProgressBar(
      double posSec, double durSec, AppLocalizations l) {
    final progress =
        durSec > 0 ? (posSec / durSec).clamp(0.0, 1.0) : 0.0;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Column(
        children: [
          SliderTheme(
            data: SliderThemeData(
              activeTrackColor: _accentColor,
              inactiveTrackColor:
                  Colors.white.withValues(alpha: 0.25),
              thumbColor: _accentColor,
              thumbShape:
                  const RoundSliderThumbShape(enabledThumbRadius: 6),
              trackHeight: 3,
              overlayShape:
                  const RoundSliderOverlayShape(overlayRadius: 14),
            ),
            child: Slider(
              value: progress,
              onChanged: (v) {
                final seekPos = Duration(
                    milliseconds: (v * durSec * 1000).round());
                widget.player.seekTo(seekPos);
              },
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 8),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                // Skip back 15s
                GestureDetector(
                  onTap: () =>
                      widget.player.skipBackward(15),
                  child: _skipButton(Icons.replay_10_rounded, '15'),
                ),
                // Current time | quality | total time
                Row(
                  children: [
                    Text(
                      _formatDuration(Duration(
                          milliseconds: (posSec * 1000).round())),
                      style: TextStyle(
                        color: Colors.white.withValues(alpha: 0.7),
                        fontSize: 12,
                        fontFeatures: const [
                          ui.FontFeature.tabularFigures()
                        ],
                      ),
                    ),
                    Padding(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 12),
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 6, vertical: 1),
                        decoration: BoxDecoration(
                          color:
                              Colors.white.withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: Text(
                          '超高',
                          style: TextStyle(
                            color: Colors.white
                                .withValues(alpha: 0.4),
                            fontSize: 9,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ),
                    Text(
                      _formatDuration(Duration(
                          milliseconds: (durSec * 1000).round())),
                      style: TextStyle(
                        color: Colors.white.withValues(alpha: 0.7),
                        fontSize: 12,
                        fontFeatures: const [
                          ui.FontFeature.tabularFigures()
                        ],
                      ),
                    ),
                  ],
                ),
                // Skip forward 15s
                GestureDetector(
                  onTap: () =>
                      widget.player.skipForward(15),
                  child: _skipButton(Icons.forward_10_rounded, '15'),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _skipButton(IconData icon, String label) {
    return Stack(
      alignment: Alignment.center,
      children: [
        Icon(icon,
            size: 36,
            color: Colors.white.withValues(alpha: 0.5)),
        Padding(
          padding: const EdgeInsets.only(top: 2),
          child: Text(
            label,
            style: TextStyle(
              fontSize: 9,
              fontWeight: FontWeight.w900,
              color: Colors.white.withValues(alpha: 0.5),
            ),
          ),
        ),
      ],
    );
  }

  // ── Bottom controls: playlist, prev, play/pause, next, sleep ──
  Widget _buildBottomControls(AppLocalizations l) {
    final isPlaying = _isActive && widget.player.isPlaying;
    final isLoading = _isActive &&
        widget.player.isLoadingOrBuffering &&
        !widget.player.isPlaying;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 32),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
        children: [
          // Playlist
          GestureDetector(
            onTap: () {},
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.queue_music_rounded,
                    color: Colors.white.withValues(alpha: 0.6),
                    size: 24),
                const SizedBox(height: 4),
                Text(
                  '播放列表',
                  style: TextStyle(
                    color: Colors.white.withValues(alpha: 0.5),
                    fontSize: 11,
                  ),
                ),
              ],
            ),
          ),
          // Previous chapter
          GestureDetector(
            onTap: _isActive
                ? widget.player.skipToPreviousChapter
                : null,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.skip_previous_rounded,
                    color: Colors.white.withValues(alpha: 0.8),
                    size: 32),
                const SizedBox(height: 4),
                Text(
                  '上一曲',
                  style: TextStyle(
                    color: Colors.white.withValues(alpha: 0.5),
                    fontSize: 11,
                  ),
                ),
              ],
            ),
          ),
          // Play/Pause (large - 2x size)
          GestureDetector(
            onTap: _isActive
                ? () => widget.player
                    .togglePlayPause(fromUi: true)
                : null,
            child: Container(
              width: 72,
              height: 72,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: _accentColor,
                boxShadow: [
                  BoxShadow(
                    color: _accentColor.withValues(alpha: 0.4),
                    blurRadius: 20,
                    spreadRadius: -3,
                  ),
                ],
              ),
              child: isLoading
                  ? Center(
                      child: SizedBox(
                        width: 30,
                        height: 30,
                        child: CircularProgressIndicator(
                          strokeWidth: 2.5,
                          color: Colors.white,
                        ),
                      ),
                    )
                  : Icon(
                      isPlaying
                          ? Icons.pause_rounded
                          : Icons.play_arrow_rounded,
                      size: 38,
                      color: Colors.white,
                    ),
            ),
          ),
          // Next chapter
          GestureDetector(
            onTap: _isActive
                ? widget.player.skipToNextChapter
                : null,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.skip_next_rounded,
                    color: Colors.white.withValues(alpha: 0.8),
                    size: 32),
                const SizedBox(height: 4),
                Text(
                  '下一曲',
                  style: TextStyle(
                    color: Colors.white.withValues(alpha: 0.5),
                    fontSize: 11,
                  ),
                ),
              ],
            ),
          ),
          // Sleep timer
          GestureDetector(
            onTap: () {
              showSleepTimerSheet(
                  context, _accentColor);
            },
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.bedtime_outlined,
                    color: Colors.white.withValues(alpha: 0.6),
                    size: 24),
                const SizedBox(height: 4),
                Text(
                  '睡眠定时',
                  style: TextStyle(
                    color: Colors.white.withValues(alpha: 0.5),
                    fontSize: 11,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  String? _currentChapterName() {
    if (_chapters.isEmpty) return null;
    final posSec = _isActive
        ? widget.player.position.inMilliseconds / 1000.0
        : _position.inMilliseconds / 1000.0;

    for (int i = 0; i < _chapters.length; i++) {
      final ch = _chapters[i] as Map<String, dynamic>;
      final start = (ch['start'] as num?)?.toDouble() ?? 0;
      final end = (ch['end'] as num?)?.toDouble() ?? 0;
      if (posSec >= start && posSec < end) {
        return ch['title'] as String?;
      }
    }
    if (posSec > 0 && _chapters.isNotEmpty) {
      return (_chapters.last as Map<String, dynamic>)['title']
          as String?;
    }
    return null;
  }

  String _formatDuration(Duration d) {
    final h = d.inHours;
    final m = d.inMinutes.remainder(60);
    final s = d.inSeconds.remainder(60);
    if (h > 0) {
      return '$h:${m.toString().padLeft(2, '0')}:${s.toString().padLeft(2, '0')}';
    }
    return '$m:${s.toString().padLeft(2, '0')}';
  }
}

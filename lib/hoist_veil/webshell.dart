import 'dart:async';
import 'dart:io';

import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:webview_flutter/webview_flutter.dart';
import 'package:webview_flutter_android/webview_flutter_android.dart';

import '../scaffold_link/beacon_link.dart';
import '../scaffold_link/nettap.dart';
import '../scaffold_link/secret_box.dart';
import '../scaffold_link/ua_pack.dart';
import 'outage_gate.dart';

// Full-screen immersive WebView.
//
// One WebViewController must never be attached to more than one
// WebViewWidget at a time — doing so causes a black screen crash on
// Android. The RepaintBoundary keeps the platform-view texture from
// being invalidated on unrelated ancestor repaints, and
// didChangeAppLifecycleState only re-enters immersive after a genuine
// background→foreground bounce, not on every rotation event.

class WebShell extends StatefulWidget {
  const WebShell({
    super.key,
    required this.link,
    required this.box,
    required this.beacon,
    required this.tap,
  });

  final String link;
  final SecretBox box;
  final BeaconLink beacon;
  final NetTap tap;

  @override
  State<WebShell> createState() => _WebShellState();
}

class _WebShellState extends State<WebShell> with WidgetsBindingObserver {
  late final WebViewController _web;
  bool _spinner = true;
  bool _offlineShown = false;
  bool _wasBackgrounded = false;
  String? _lastMainFrame;
  int _redirectRetries = 0;
  int _dnsRetries = 0;
  Timer? _dnsRetryTimer;
  StreamSubscription<List<ConnectivityResult>>? _connSub;
  static const MethodChannel _uploadBridge =
      MethodChannel('bc.greenfg/hoister/v2');

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    SystemChrome.setPreferredOrientations(const <DeviceOrientation>[
      DeviceOrientation.portraitUp,
      DeviceOrientation.portraitDown,
      DeviceOrientation.landscapeLeft,
      DeviceOrientation.landscapeRight,
    ]);
    _enterImmersive();
    _buildController();

    widget.beacon.onLink = (String link) {
      if (mounted) _web.loadRequest(Uri.parse(link));
    };

    _connSub = widget.tap.pulses.listen((List<ConnectivityResult> r) {
      if (r.isNotEmpty &&
          r.every((ConnectivityResult e) => e == ConnectivityResult.none)) {
        _openOffline();
      }
    });
  }

  void _enterImmersive() {
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersiveSticky);
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    // Only re-enter immersive after a real background→foreground bounce.
    // Firing `setEnabledSystemUIMode` on every inactive/resumed pair
    // makes rotation jitter because the system bars flash during the
    // recomposition frame.
    if (state == AppLifecycleState.paused ||
        state == AppLifecycleState.hidden) {
      _wasBackgrounded = true;
      return;
    }
    if (state == AppLifecycleState.resumed && _wasBackgrounded) {
      _wasBackgrounded = false;
      _enterImmersive();
    }
  }

  void _buildController() {
    _web = WebViewController()
      ..setJavaScriptMode(JavaScriptMode.unrestricted)
      ..setUserAgent(brixHttp.brand)
      ..setBackgroundColor(Colors.black)
      ..enableZoom(false)
      ..setNavigationDelegate(NavigationDelegate(
        onPageStarted: (_) {
          if (mounted) setState(() => _spinner = true);
        },
        onPageFinished: (_) {
          if (mounted) setState(() => _spinner = false);
          _redirectRetries = 0;
          _dnsRetries = 0;
          _neutraliseSafeArea();
          _tuneKeyboardBring();
        },
        onWebResourceError: (WebResourceError err) {
          if (err.isForMainFrame != true) return;

          final String d = err.description.toLowerCase();
          final bool loop = d.contains('too_many_redirects') ||
              d.contains('too many redirects') ||
              err.errorCode == -1007 ||
              err.errorCode == -9;
          if (loop && _lastMainFrame != null && _redirectRetries < 3) {
            _redirectRetries++;
            _web.loadRequest(Uri.parse(_lastMainFrame!));
            return;
          }

          final bool dnsFault = d.contains('name_not_resolved') ||
              d.contains('err_name_not_resolved') ||
              d.contains('internet_disconnected') ||
              d.contains('network_changed') ||
              err.errorCode == -105 ||
              err.errorCode == -106 ||
              err.errorCode == -21;
          if (dnsFault && _dnsRetries < 3) {
            _scheduleDnsRetry();
            return;
          }

          _guardOffline();
        },
        onNavigationRequest: (NavigationRequest req) {
          final Uri? uri = Uri.tryParse(req.url);
          if (uri == null) return NavigationDecision.prevent;
          const Set<String> inApp = <String>{
            'http',
            'https',
            'about',
            'data',
            'blob',
          };
          if (inApp.contains(uri.scheme)) {
            if (req.isMainFrame) _lastMainFrame = req.url;
            return NavigationDecision.navigate;
          }
          _bounceExternal(uri);
          return NavigationDecision.prevent;
        },
      ));

    _tuneAndroid();
    _web.loadRequest(Uri.parse(widget.link));
  }

  void _scheduleDnsRetry() {
    _dnsRetries++;
    _dnsRetryTimer?.cancel();
    // Growing back-off: 1.2s / 2.4s / 3.6s. On a legitimate offline
    // the retries all fail and we escalate to `_guardOffline`; on a
    // captive / restarting connection the DNS becomes valid within
    // this window and the page loads.
    final Duration wait = Duration(milliseconds: 1200 * _dnsRetries);
    _dnsRetryTimer = Timer(wait, () async {
      if (!mounted || _offlineShown) return;
      final bool online = await widget.tap.alive();
      final String target = _lastMainFrame ?? widget.link;
      if (online) {
        _web.loadRequest(Uri.parse(target));
      } else if (_dnsRetries >= 3) {
        _openOffline();
      } else {
        _scheduleDnsRetry();
      }
    });
  }

  void _tuneAndroid() {
    if (!Platform.isAndroid) return;
    if (_web.platform is! AndroidWebViewController) return;
    final AndroidWebViewController a =
        _web.platform as AndroidWebViewController;

    a.setMediaPlaybackRequiresUserGesture(false);
    a.setOnPlatformPermissionRequest(
      (PlatformWebViewPermissionRequest req) => req.grant(),
    );
    a.setOnShowFileSelector(_openChooser);

    final AndroidWebViewCookieManager cookies = AndroidWebViewCookieManager(
      AndroidWebViewCookieManagerCreationParams
          .fromPlatformWebViewCookieManagerCreationParams(
        const PlatformWebViewCookieManagerCreationParams(),
      ),
    );
    cookies.setAcceptThirdPartyCookies(a, true);
  }

  Future<List<String>> _openChooser(FileSelectorParams params) async {
    try {
      final List<Object?>? picked =
          await _uploadBridge.invokeMethod<List<Object?>>(
        'pick',
        <String, Object>{
          'multiple': params.mode == FileSelectorMode.openMultiple,
          'mimeTypes': params.acceptTypes
              .where((String t) => t.trim().isNotEmpty)
              .toList(),
        },
      );
      if (picked == null) return const <String>[];
      return picked.whereType<String>().toList();
    } catch (_) {
      return const <String>[];
    }
  }

  Future<void> _bounceExternal(Uri uri) async {
    try {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    } catch (_) {}
  }

  Future<void> _guardOffline() async {
    if (_offlineShown) return;
    final bool online = await widget.tap.alive();
    if (online) return;
    _openOffline();
  }

  void _openOffline() {
    if (_offlineShown || !mounted) return;
    _offlineShown = true;
    _dnsRetryTimer?.cancel();
    final String current = _lastMainFrame ?? widget.link;
    Navigator.of(context).pushReplacement(
      MaterialPageRoute<void>(
        builder: (_) => OutageGate(
          onRetryBuild: (_) => WebShell(
            link: current,
            box: widget.box,
            beacon: widget.beacon,
            tap: widget.tap,
          ),
        ),
      ),
    );
  }

  void _tuneKeyboardBring() {
    _web.runJavaScript(r'''
(function(){
  if(window.__brixKb)return;window.__brixKb=true;
  function isField(el){return el&&(el.tagName==='INPUT'||el.tagName==='TEXTAREA'||el.isContentEditable);}
  function bring(){
    var el=document.activeElement;if(!isField(el))return;
    var vp=window.visualViewport;
    if(vp){
      var r=el.getBoundingClientRect();var bottom=vp.offsetTop+vp.height;
      if(r.bottom>bottom-20||r.top<vp.offsetTop){el.scrollIntoView({behavior:'auto',block:'nearest'});}
    } else { el.scrollIntoView({behavior:'auto',block:'nearest'}); }
  }
  document.addEventListener('focusin',function(e){ if(isField(e.target)) setTimeout(bring,340); });
  if(window.visualViewport){
    var prev=window.visualViewport.height;
    window.visualViewport.addEventListener('resize',function(){
      var h=window.visualViewport.height;if(h<prev)setTimeout(bring,120);prev=h;
    });
  }
})();
''');
  }

  void _neutraliseSafeArea() {
    _web.runJavaScript(r'''
(function(){
  if(window.__brixSa)return;window.__brixSa=true;
  var TAG='__brix_sa';
  var CSS=':root{--safe-area-inset-top:0px!important;--safe-area-inset-right:0px!important;'
    +'--safe-area-inset-bottom:0px!important;--safe-area-inset-left:0px!important;'
    +'--sat:0px!important;--sar:0px!important;--sab:0px!important;--sal:0px!important;'
    +'--safe-top:0px!important;--safe-bottom:0px!important;--safe-left:0px!important;--safe-right:0px!important;}'
    +'.gameview-mobile-header,.app-header,.js-safe-top{padding-top:0!important;margin-top:0!important;}';
  function kbOpen(){ if(!window.visualViewport)return false; return window.visualViewport.height<window.innerHeight*0.75; }
  function apply(){
    if(kbOpen())return;
    var head=document.head||document.documentElement;if(!head)return;
    var m=document.querySelector('meta[name="viewport"]');
    if(m && !/viewport-fit\s*=\s*contain/i.test(m.getAttribute('content')||'')){
      var c=(m.getAttribute('content')||'').replace(/,?\s*viewport-fit\s*=\s*\w+/ig,'').trim();
      m.setAttribute('content', c+(c?', ':'')+'viewport-fit=contain');
    }
    var s=document.getElementById(TAG);
    if(!s){s=document.createElement('style');s.id=TAG;head.appendChild(s);}
    if(s.textContent!==CSS) s.textContent=CSS;
  }
  apply();
  ['pushState','replaceState'].forEach(function(fn){
    var o=history[fn];history[fn]=function(){var r=o.apply(this,arguments);setTimeout(apply,80);setTimeout(apply,400);return r;};
  });
  window.addEventListener('popstate',function(){setTimeout(apply,80);});
  setInterval(apply,2600);
})();
''');
  }

  Future<void> _stepBack() async {
    if (await _web.canGoBack()) {
      await _web.goBack();
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _connSub?.cancel();
    _dnsRetryTimer?.cancel();
    widget.beacon.onLink = null;
    SystemChrome.setEnabledSystemUIMode(
      SystemUiMode.manual,
      overlays: SystemUiOverlay.values,
    );
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final MediaQueryData mq = MediaQuery.of(context);
    final bool landscape = mq.orientation == Orientation.landscape;

    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (bool didPop, _) async {
        if (!didPop) await _stepBack();
      },
      child: Scaffold(
        backgroundColor: Colors.black,
        resizeToAvoidBottomInset: false,
        body: Stack(
          fit: StackFit.expand,
          children: <Widget>[
            RepaintBoundary(
              child: SafeArea(
                bottom: false,
                child: WebViewWidget(controller: _web),
              ),
            ),
            if (_spinner)
              IgnorePointer(
                child: ColoredBox(
                  color: landscape
                      ? const Color(0x55000000)
                      : const Color(0x80000000),
                  child: const Center(
                    child: CircularProgressIndicator(
                      valueColor: AlwaysStoppedAnimation<Color>(
                        Color(0xFFFFD35A),
                      ),
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

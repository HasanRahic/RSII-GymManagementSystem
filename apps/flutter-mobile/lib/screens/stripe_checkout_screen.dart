import 'package:flutter/material.dart';
import 'package:webview_flutter/webview_flutter.dart';

import 'dart:async';

class StripeCheckoutScreen extends StatefulWidget {
  final String checkoutUrl;

  const StripeCheckoutScreen({super.key, required this.checkoutUrl});

  @override
  State<StripeCheckoutScreen> createState() => _StripeCheckoutScreenState();
}

class _StripeCheckoutScreenState extends State<StripeCheckoutScreen> {
  late final WebViewController _controller;
  bool _loading = true;
  String? _errorMessage;
  Timer? _loadingWatchdog;
  late final Uri _checkoutUri;
  int _loadingStage = 0;

  bool _isTerminalCheckoutUrl(String url) {
    return url.contains('/checkout/success') || url.contains('/checkout/cancel');
  }

  Future<void> _reloadCheckout() async {
    setState(() {
      _loading = true;
      _errorMessage = null;
      _loadingStage = 0;
    });
    _startLoadingWatchdog();
    await _controller.loadRequest(_checkoutUri);
  }

  void _startLoadingWatchdog() {
    _loadingWatchdog?.cancel();
    _loadingWatchdog = Timer(const Duration(seconds: 25), () {
      if (!mounted || !_loading) return;
      setState(() {
        _loading = false;
        _errorMessage = 'Checkout se predugo učitava. Pokušajte ponovo.';
      });
    });
  }

  void _stopLoadingWatchdog() {
    _loadingWatchdog?.cancel();
    _loadingWatchdog = null;
  }

  @override
  void initState() {
    super.initState();
    _checkoutUri = Uri.parse(widget.checkoutUrl);
    _controller = WebViewController()
      ..setJavaScriptMode(JavaScriptMode.unrestricted)
      ..setBackgroundColor(Colors.white)
      ..setNavigationDelegate(
        NavigationDelegate(
          onNavigationRequest: (request) {
            if (_isTerminalCheckoutUrl(request.url)) {
              if (mounted) {
                Navigator.pop(context, request.url.contains('/checkout/success'));
              }
              return NavigationDecision.prevent;
            }
            return NavigationDecision.navigate;
          },
          onPageStarted: (url) {
            if (!mounted) return;
            setState(() {
              _loading = true;
              _errorMessage = null;
              _loadingStage = url.contains('stripe') ? 1 : 2;
            });
            _startLoadingWatchdog();
          },
          onProgress: (progress) {
            if (!mounted) return;
            if (progress >= 20 && _loadingStage < 1) {
              setState(() => _loadingStage = 1);
            }
            if (progress >= 65 && _loadingStage < 2) {
              setState(() => _loadingStage = 2);
            }
          },
          onPageFinished: (_) {
            _stopLoadingWatchdog();
            if (mounted && _loading) {
              setState(() {
                _loading = false;
                _loadingStage = 3;
              });
            }
          },
          onWebResourceError: (error) {
            if (error.isForMainFrame != true) {
              return;
            }

            // Ignore benign cancellation errors that happen during redirects.
            if (error.errorCode == -999 || error.description.toLowerCase().contains('cancel')) {
              return;
            }
            if (!mounted) return;
            _stopLoadingWatchdog();
            setState(() {
              _loading = false;
              _loadingStage = 0;
              _errorMessage = 'Stripe checkout nije uspio da se učita (${error.errorCode}).';
            });
          },
        ),
      );
    _startLoadingWatchdog();
    unawaited(_controller.loadRequest(_checkoutUri));
  }

  @override
  void dispose() {
    _stopLoadingWatchdog();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Stripe checkout'),
        actions: [
          IconButton(
            onPressed: _reloadCheckout,
            icon: const Icon(Icons.refresh),
            tooltip: 'Ponovo učitaj checkout',
          ),
          IconButton(
            onPressed: () => Navigator.pop(context, false),
            icon: const Icon(Icons.close),
            tooltip: 'Zatvori checkout',
          ),
        ],
      ),
      body: Stack(
        children: [
          WebViewWidget(controller: _controller),
          if (_loading)
            Container(
              color: Colors.white,
              alignment: Alignment.center,
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 28),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const SizedBox(
                      width: 34,
                      height: 34,
                      child: CircularProgressIndicator(strokeWidth: 3),
                    ),
                    const SizedBox(height: 18),
                    Text(
                      switch (_loadingStage) {
                        0 => 'Pripremam Stripe checkout...',
                        1 => 'Povezujem se na Stripe...',
                        2 => 'Ucitavam sigurnu stranicu za placanje...',
                        _ => 'Otvaram checkout...',
                      },
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          if (_errorMessage != null)
            Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      _errorMessage!,
                      textAlign: TextAlign.center,
                      style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
                    ),
                    const SizedBox(height: 16),
                    FilledButton(
                      onPressed: _reloadCheckout,
                      child: const Text('Pokušaj ponovo'),
                    ),
                    const SizedBox(height: 8),
                    TextButton(
                      onPressed: () => Navigator.pop(context, false),
                      child: const Text('Zatvori'),
                    ),
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }
}

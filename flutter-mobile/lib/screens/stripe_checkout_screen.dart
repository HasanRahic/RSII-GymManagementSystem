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

  bool _isTerminalCheckoutUrl(String url) {
    return url.contains('/checkout/success') || url.contains('/checkout/cancel');
  }

  Future<void> _reloadCheckout() async {
    setState(() {
      _loading = true;
      _errorMessage = null;
    });
    _startLoadingWatchdog();
    await _controller.loadRequest(Uri.parse(widget.checkoutUrl));
  }

  void _startLoadingWatchdog() {
    _loadingWatchdog?.cancel();
    _loadingWatchdog = Timer(const Duration(seconds: 15), () {
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
    _startLoadingWatchdog();
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
          onPageStarted: (_) {
            if (mounted && !_loading) {
              setState(() => _loading = true);
            }
            _startLoadingWatchdog();
          },
          onPageFinished: (_) {
            _stopLoadingWatchdog();
            if (mounted && _loading) {
              setState(() => _loading = false);
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
              _errorMessage = 'Stripe checkout nije uspio da se učita (${error.errorCode}).';
            });
          },
        ),
      )
      ..loadRequest(Uri.parse(widget.checkoutUrl));
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
            const Center(
              child: CircularProgressIndicator(),
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
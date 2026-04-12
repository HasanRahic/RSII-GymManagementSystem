import 'package:flutter/material.dart';
import 'package:webview_flutter/webview_flutter.dart';

class StripeCheckoutScreen extends StatefulWidget {
  final String checkoutUrl;

  const StripeCheckoutScreen({super.key, required this.checkoutUrl});

  @override
  State<StripeCheckoutScreen> createState() => _StripeCheckoutScreenState();
}

class _StripeCheckoutScreenState extends State<StripeCheckoutScreen> {
  late final WebViewController _controller;
  bool _loading = true;

  bool _isTerminalCheckoutUrl(String url) {
    return url.contains('/checkout/success') || url.contains('/checkout/cancel');
  }

  @override
  void initState() {
    super.initState();
    _controller = WebViewController()
      ..setJavaScriptMode(JavaScriptMode.unrestricted)
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
            if (mounted) setState(() => _loading = true);
          },
          onPageFinished: (_) {
            if (mounted) setState(() => _loading = false);
          },
        ),
      )
      ..loadRequest(Uri.parse(widget.checkoutUrl));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Stripe checkout'),
        actions: [
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
        ],
      ),
    );
  }
}
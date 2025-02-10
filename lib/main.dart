import 'package:flutter/material.dart';
import 'package:qr_code_scanner/qr_code_scanner.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:url_launcher/url_launcher.dart';

void main() => runApp(const MyApp());

class MyApp extends StatelessWidget {
  const MyApp({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      theme: ThemeData(primarySwatch: Colors.blueGrey),
      home: const QRViewExample(),
      
    );
  }
}

class QRViewExample extends StatefulWidget {
  const QRViewExample({Key? key}) : super(key: key);

  @override
  State<StatefulWidget> createState() => _QRViewExampleState();
}

class _QRViewExampleState extends State<QRViewExample> {
  final GlobalKey qrKey = GlobalKey(debugLabel: 'QR');
  Barcode? result;
  QRViewController? controller;

  @override
  void reassemble() {
    super.reassemble();
    controller!.pauseCamera();
    controller!.resumeCamera();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('QR Safe Scanner')),
      body: Column(
        children: <Widget>[
          Expanded(flex: 4, child: _buildQrView(context)),
          Expanded(
            flex: 1,
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: <Widget>[
                if (result != null)
                  Text('Result: ${result!.code}')
                else
                  const Text('Scan a code'),
                ElevatedButton(
                  onPressed: result != null && result!.code != null
                      ? () => _checkWithVirusTotal(result!.code!)
                      : null,
                  child: const Text('Check with VirusTotal'),
                ),
              ],
            ),
          )
        ],
      ),
    );
  }

  Widget _buildQrView(BuildContext context) {
    return QRView(
      key: qrKey,
      onQRViewCreated: _onQRViewCreated,
      overlay: QrScannerOverlayShape(
        borderColor: Colors.white,
        borderRadius: 10,
        borderLength: 30,
        borderWidth: 10,
        cutOutSize: MediaQuery.of(context).size.width * 0.8,
      ),
    );
  }

  void _onQRViewCreated(QRViewController controller) {
    setState(() {
      this.controller = controller;
    });
    controller.scannedDataStream.listen((scanData) {
      setState(() {
        result = scanData;
      });
    });
  }

  Future<void> _checkWithVirusTotal(String url) async {
  const apiKey = 'YOUR_API_KEY';
  final encodedUrl = base64Url.encode(utf8.encode(url)).replaceAll('=', '');  // Encode and remove padding
  final apiUrl = 'https://www.virustotal.com/api/v3/urls/$encodedUrl';

  try {
    final response = await http.get(
      Uri.parse(apiUrl),
      headers: {
        'x-apikey': apiKey,
        'Content-Type': 'application/json',
      },
    );

      if (response.statusCode == 200) {
        final jsonResponse = json.decode(response.body);
        final scanResult =
            jsonResponse['data']['attributes']['last_analysis_stats'];
        final maliciousCount = scanResult['malicious'] ?? 0;
        final suspiciousCount = scanResult['suspicious'] ?? 0;

      //[UNSIA] response checking (if there's malicious or suspicious warning pop up will shown)
        if (maliciousCount > 0 || suspiciousCount > 0) {
          _showErrorDialog('Warning!',
              'This URL is not safe!\nThere are $maliciousCount malicious and $suspiciousCount suspicious detections.');
        } else {
          //[UNSIA] Showing pop up dialog for safe URL
          _showSafeUrlDialog(url);
        }
      } else {
        _showErrorDialog('Error: ${response.statusCode}', (response.body).toString());
      }
    } catch (e) {
      _showErrorDialog('Error', e.toString());
    }
  }

  //[UNSIA] function to launch URL and navigate to browser
  Future<void> _launchUrl(Uri url) async {
    if (!await launchUrl(url)) {
      throw Exception('Could not launch $url');
    }
  }

  //[UNSIA] parameterize title and message, so error and warning pop up will use same dialog
  void _showErrorDialog(String title, String message) {
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: Text(title),
        content: Text(message),
        actions: <Widget>[
          TextButton(
            child: const Text('OK'),
            onPressed: () {
              Navigator.of(context).pop();
            },
          ),
        ],
      ),
    );
  }

  //[UNSIA] function to show pop up dialog for safe URL
  void _showSafeUrlDialog(String url) {
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Safe URL'),
        content: Text('This URL is safe. Open in browser?'),
        actions: <Widget>[
          TextButton(
            child: const Text('Cancel'),
            onPressed: () {
              Navigator.of(context).pop();
            },
          ),
          TextButton(
            child: const Text('Open'),
            onPressed: () {
              _launchUrl(Uri.parse(url));
              Navigator.of(context).pop();
            },
          ),
        ],
      ),
    );
  }

  @override
  void dispose() {
    controller?.dispose();
    super.dispose();
  }
}

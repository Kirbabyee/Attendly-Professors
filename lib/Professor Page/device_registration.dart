import 'package:flutter/material.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class DeviceRegistration extends StatefulWidget {
  const DeviceRegistration({super.key});

  @override
  State<DeviceRegistration> createState() => _DeviceRegistrationState();
}

class _DeviceRegistrationState extends State<DeviceRegistration> {
  final _supabase = Supabase.instance.client;
  bool _isScanning = false;
  String _statusText = 'Align the QR code to the guide';

  final Color primaryBlue = const Color(0xFF043B6F); // Based on your Face Reg button
  final Color backgroundColor = const Color(0xFFf0f4f7);

  Future<void> _bindDevice(String scannedValue) async {
    // 1. Show loading indicator
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => const Center(child: CircularProgressIndicator()),
    );

    try {
      final user = _supabase.auth.currentUser;
      if (user == null) throw 'User session not found';

      String macAddress = scannedValue.trim().toUpperCase();

      // --- VALIDATION START ---
      // Check kung may ibang gumagamit na ng MAC address na ito sa 'devices' table
      final existingDevice = await _supabase
          .from('devices')
          .select('id')
          .eq('mac_address', macAddress)
          .maybeSingle();

      if (existingDevice != null) {
        if (!mounted) return;
        Navigator.pop(context); // Close loading
        _showErrorDialog(
          title: 'Device Already Linked',
          message: 'This ESP32 device is already registered to another account.',
        );
        return;
      }
      // --- VALIDATION END ---

      // 2. TRANSACTION-LIKE UPDATES

      // A. Update professors Table (Para sa identification)
      await _supabase
          .from('professors')
          .update({'mac_address': macAddress})
          .eq('id', user.id);

      // B. Insert/Update Devices Table (Para sa status monitoring)
      // Gagamit tayo ng 'upsert' para kung sakaling re-registration ito, ma-overwrite ang user_id
      await _supabase
          .from('devices')
          .upsert({
        'user_id': user.id,
        'mac_address': macAddress,
        'battery_level': 0,      // Initial value
        'is_online': false,      // Initial value
        'last_seen': DateTime.now().toUtc().toIso8601String(),
      }, onConflict: 'mac_address');

      if (!mounted) return;

      // Close loading dialog
      Navigator.pop(context);

      // 3. TAWAGIN ANG SUCCESS MODAL
      await _showSuccessDialog();

      if (!mounted) return;

      // 4. REKTA SA MAINSHELL
      Navigator.of(context).pushNamedAndRemoveUntil('/mainshell', (route) => false);

    } catch (e) {
      if (!mounted) return;
      Navigator.pop(context); // Close loading

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error: $e'),
          backgroundColor: Colors.red,
        ),
      );
      setState(() => _isScanning = false);
    }
  }

  // UPDATED SUCCESS DIALOG LOGIC
  Future<void> _showSuccessDialog() async {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) {
        return Dialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
          child: Container(
            width: MediaQuery.of(context).size.width * 0.7, // Mas maliit na width
            color: Colors.white,
            padding: const EdgeInsets.all(20),
            child: Column(
              mainAxisSize: MainAxisSize.min, // Hugs the content
              children: [
                const Icon(Icons.check_circle_rounded, color: Colors.green, size: 50), // Binabaan mula 80
                const SizedBox(height: 15),
                const Text(
                  'Success!',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 8),
                const Text(
                  'Device linked successfully.',
                  style: TextStyle(fontSize: 13, color: Colors.grey),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 20),
                const SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(strokeWidth: 2, color: Colors.green),
                ),
              ],
            ),
          ),
        );
      },
    );

    await Future.delayed(const Duration(milliseconds: 2000));
    if (mounted) Navigator.pop(context);
  }

  void _showErrorDialog({required String title, required String message}) {
    showDialog(
      context: context,
      builder: (context) => Dialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
        child: Container(
          width: MediaQuery.of(context).size.width * 0.7,
          color: Colors.white,
          padding: const EdgeInsets.all(20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.error_outline, color: Colors.red, size: 40),
              const SizedBox(height: 12),
              Text(
                title,
                style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: Colors.red),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 8),
              Text(
                message,
                style: const TextStyle(fontSize: 13),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 20),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.red,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                  ),
                  onPressed: () {
                    Navigator.pop(context);
                    setState(() => _isScanning = true);
                  },
                  child: const Text('Try Again', style: TextStyle(color: Colors.white)),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final screenHeight = MediaQuery.of(context).size.height;
    final screenWidth = MediaQuery.of(context).size.width;

    return Scaffold(
      backgroundColor: backgroundColor,
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              const SizedBox(height: 20),
              Image.asset('assets/logo.png', width: screenWidth * .7),
              SizedBox(height: screenHeight * .023),

              // Title Section
              Align(
                alignment: Alignment.centerLeft,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Device Registration',
                      style: TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: screenHeight * .028,
                          color: primaryBlue
                      ),
                    ),
                    SizedBox(height: screenHeight * .007),
                    Text(
                      'Scan the QR code on your ESP32 to link it',
                      style: TextStyle(fontSize: screenHeight * .015),
                    ),
                  ],
                ),
              ),

              SizedBox(height: screenHeight * .023),

              // White Card (Body)
              Container(
                width: double.infinity,
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(10),
                ),
                padding: EdgeInsets.symmetric(vertical: screenHeight * .021),
                child: Column(
                  children: [
                    // Grey Scanner Area
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 20),
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(20),
                        child: Container(
                          color: const Color(0xFFD9D9D9),
                          height: screenHeight * .35, // Medyo mas mataas para sa QR
                          width: double.infinity,
                          child: _buildScannerArea(),
                        ),
                      ),
                    ),

                    SizedBox(height: screenHeight * .013),

                    // Status Text
                    Padding(
                      padding: EdgeInsets.symmetric(horizontal: screenWidth * .06),
                      child: Align(
                        alignment: Alignment.centerLeft,
                        child: Text(
                          _isScanning ? _statusText : 'Tap Start to scan QR',
                          style: TextStyle(
                            fontSize: screenHeight * .015,
                            fontWeight: FontWeight.w500,
                            color: _isScanning ? Colors.green : Colors.black54,
                          ),
                        ),
                      ),
                    ),

                    SizedBox(height: screenHeight * .019),

                    // Instructions Section
                    Padding(
                      padding: EdgeInsets.symmetric(horizontal: screenWidth * .06),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'Registration Instructions:',
                            style: TextStyle(fontWeight: FontWeight.w500),
                          ),
                          SizedBox(height: screenHeight * .009),
                          Text(
                            '• Ensure the QR code is well-lit.\n'
                                '• Hold the device steady within the guide.\n'
                                '• The MAC address will be automatically detected.',
                            style: TextStyle(fontSize: screenHeight * .015),
                          ),
                        ],
                      ),
                    ),

                    SizedBox(height: screenHeight * .021),

                    // Action Button
                    OutlinedButton(
                      style: OutlinedButton.styleFrom(
                        backgroundColor: primaryBlue,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10),
                        ),
                      ),
                      onPressed: () => setState(() => _isScanning = true),
                      child: Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 12),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Icon(Icons.qr_code_scanner, color: Colors.white),
                            const SizedBox(width: 15),
                            Text(
                              'Start Scanning',
                              style: TextStyle(color: Colors.white, fontSize: screenHeight * .019),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildScannerArea() {
    if (!_isScanning) {
      return const Center(
        child: Icon(Icons.qr_code_2, size: 80, color: Colors.grey),
      );
    }

    return Stack(
      fit: StackFit.expand,
      children: [
        MobileScanner(
          onDetect: (capture) {
            final List<Barcode> barcodes = capture.barcodes;
            if (barcodes.isNotEmpty && _isScanning) { // Check kung scanning pa
              final String? code = barcodes.first.rawValue;
              if (code != null) {
                setState(() => _isScanning = false); // Stop scanner UI
                _bindDevice(code); // Call binding logic
              }
            }
          },
        ),
        // Overlay Guide (Custom Paint)
        CustomPaint(
          painter: QRGuidePainter(),
        ),
      ],
    );
  }
}

// Custom Painter para sa Square QR Guide
class QRGuidePainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = Colors.greenAccent.withOpacity(0.8)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 3;

    // Mas square na guide para sa QR code
    final rect = Rect.fromCenter(
      center: Offset(size.width / 2, size.height / 2),
      width: size.width * 0.6,
      height: size.width * 0.6,
    );

    canvas.drawRRect(
      RRect.fromRectAndRadius(rect, const Radius.circular(12)),
      paint,
    );
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
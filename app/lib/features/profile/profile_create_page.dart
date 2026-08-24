import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:mobile_scanner/mobile_scanner.dart';

import '../../services/profile_import_service.dart';
import '../../services/proxy_app_controller.dart';
import '../../widgets/clash_widgets.dart';
import 'profile_edit_page.dart';

class ProfileCreatePage extends StatelessWidget {
  final ProxyAppController controller;
  const ProfileCreatePage({super.key, required this.controller});

  Future<void> _file(BuildContext context) async {
    final result = await FilePicker.pickFiles(
      type: FileType.custom,
      allowedExtensions: const ['yaml', 'yml', 'txt'],
    );
    final path = result.isEmpty ? null : result.single.path;
    if (path != null && context.mounted) {
      await Navigator.push<bool>(
        context,
        MaterialPageRoute(
          builder: (_) =>
              ProfileEditPage(controller: controller, filePath: path),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: const ScreenshotAppBar(title: '创建配置'),
    body: ListView(
      padding: const EdgeInsets.only(top: 10),
      children: [
        _CreateItem(
          icon: Icons.attach_file,
          title: '文件',
          subtitle: '从文件导入',
          onTap: () => _file(context),
        ),
        _CreateItem(
          icon: Icons.cloud_download,
          title: 'URL',
          subtitle: '从 URL 导入',
          onTap: () => Navigator.push<bool>(
            context,
            MaterialPageRoute(
              builder: (_) =>
                  ProfileEditPage(controller: controller, initialUrl: ''),
            ),
          ),
        ),
        _CreateItem(
          icon: Icons.qr_code,
          title: 'QR Code',
          subtitle: '从二维码导入',
          onTap: () => Navigator.push<bool>(
            context,
            MaterialPageRoute(
              builder: (_) => _QrScannerPage(controller: controller),
            ),
          ),
        ),
      ],
    ),
  );
}

class _CreateItem extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback onTap;
  const _CreateItem({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) => InkWell(
    onTap: onTap,
    child: SizedBox(
      height: 78,
      child: Row(
        children: [
          const SizedBox(width: 19),
          SizedBox(width: 45, child: Icon(icon, size: 28)),
          const SizedBox(width: 20),
          Column(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: const TextStyle(fontSize: 16, letterSpacing: 1.2),
              ),
              const SizedBox(height: 6),
              Text(
                subtitle,
                style: const TextStyle(fontSize: 14, letterSpacing: 1.1),
              ),
            ],
          ),
        ],
      ),
    ),
  );
}

class _QrScannerPage extends StatefulWidget {
  final ProxyAppController controller;
  const _QrScannerPage({required this.controller});

  @override
  State<_QrScannerPage> createState() => _QrScannerPageState();
}

class _QrScannerPageState extends State<_QrScannerPage> {
  final MobileScannerController _scanner = MobileScannerController();
  bool _handled = false;

  Future<void> _detected(BarcodeCapture capture) async {
    if (_handled) return;
    final value = capture.barcodes.firstOrNull?.rawValue;
    if (value == null || value.trim().isEmpty) return;
    _handled = true;
    await _scanner.stop();
    if (!mounted) return;
    if (value.startsWith('http://') || value.startsWith('https://')) {
      await Navigator.pushReplacement(
        context,
        MaterialPageRoute(
          builder: (_) =>
              ProfileEditPage(controller: widget.controller, initialUrl: value),
        ),
      );
      return;
    }
    try {
      widget.controller.importer.fromQr(value);
      await Navigator.pushReplacement(
        context,
        MaterialPageRoute(
          builder: (_) =>
              ProfileEditPage(controller: widget.controller, qrValue: value),
        ),
      );
    } on ProfileImportException catch (error) {
      _handled = false;
      await _scanner.start();
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('$error')));
      }
    }
  }

  @override
  void dispose() {
    _scanner.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: const ScreenshotAppBar(title: '扫描二维码'),
    body: Stack(
      fit: StackFit.expand,
      children: [
        MobileScanner(controller: _scanner, onDetect: _detected),
        Center(
          child: Container(
            width: 250,
            height: 250,
            decoration: BoxDecoration(
              border: Border.all(color: Colors.white, width: 3),
              borderRadius: BorderRadius.circular(18),
            ),
          ),
        ),
      ],
    ),
  );
}

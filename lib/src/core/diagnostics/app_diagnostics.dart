import 'dart:developer' as developer;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

/// Temporary runtime diagnostics for investigating blank screens.
final class AppDiagnostics {
  AppDiagnostics._();

  static final List<String> _entries = <String>[];
  static const int _maxEntries = 30;

  static void initialize() {
    FlutterError.onError = (details) {
      report('FLUTTER ERROR', details.exception, details.stack);
      FlutterError.presentError(details);
    };

    ErrorWidget.builder = (details) => AppDiagnosticScreen(
          title: 'Halaman gagal ditampilkan',
          error: details.exception,
          stackTrace: details.stack,
        );

    PlatformDispatcher.instance.onError = (error, stack) {
      report('UNCAUGHT ASYNC ERROR', error, stack);
      return true;
    };
  }

  static void report(String source, Object error, StackTrace? stack) {
    final timestamp = DateTime.now().toIso8601String();
    final entry = '[$timestamp] $source\n$error'
        '${stack == null ? '' : '\n$stack'}';
    _entries.insert(0, entry);
    if (_entries.length > _maxEntries) {
      _entries.removeRange(_maxEntries, _entries.length);
    }
    developer.log(entry, name: 'OpenLock.Diagnostics', error: error, stackTrace: stack);
  }

  static String reportText(Object error, StackTrace? stack) {
    final latest = _entries.isEmpty ? 'Belum ada log tambahan.' : _entries.join('\n\n');
    return 'OPENLOCK DIAGNOSTIC REPORT\n'
        'Waktu: ${DateTime.now().toIso8601String()}\n'
        'Error halaman: $error\n'
        '${stack == null ? '' : 'Stack trace:\n$stack\n'}'
        '\nLOG TERKUMPUL:\n$latest';
  }
}

class AppDiagnosticScreen extends StatelessWidget {
  const AppDiagnosticScreen({
    super.key,
    required this.error,
    this.stackTrace,
    this.title = 'OpenLock menemukan error',
  });

  final Object error;
  final StackTrace? stackTrace;
  final String title;

  @override
  Widget build(BuildContext context) {
    final report = AppDiagnostics.reportText(error, stackTrace);
    return Scaffold(
      backgroundColor: const Color(0xFF101116),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(22),
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 560),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Icon(Icons.bug_report_rounded,
                      color: Color(0xFFFFA34D), size: 42),
                  const SizedBox(height: 18),
                  Text(title,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 21,
                        fontWeight: FontWeight.w800,
                      )),
                  const SizedBox(height: 12),
                  const Text(
                    'Layar ini muncul agar penyebab masalah bisa diperiksa. '
                    'Salin laporan di bawah dan kirimkan kembali.',
                    style: TextStyle(color: Color(0xFFB8BAC5), height: 1.5),
                  ),
                  const SizedBox(height: 16),
                  Container(
                    width: double.infinity,
                    constraints: const BoxConstraints(maxHeight: 230),
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: const Color(0xFF20222C),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: const Color(0xFF484B59)),
                    ),
                    child: SingleChildScrollView(
                      child: SelectableText(
                        report,
                        style: const TextStyle(
                          color: Color(0xFFFFD2A6),
                          fontSize: 11,
                          fontFamily: 'monospace',
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  SizedBox(
                    width: double.infinity,
                    child: FilledButton.icon(
                      onPressed: () async {
                        await Clipboard.setData(ClipboardData(text: report));
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(content: Text('Laporan disalin')),
                        );
                      },
                      icon: const Icon(Icons.copy_rounded),
                      label: const Text('SALIN LAPORAN ERROR'),
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
}

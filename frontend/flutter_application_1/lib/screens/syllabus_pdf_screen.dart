import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:syncfusion_flutter_pdfviewer/pdfviewer.dart';

import 'package:flutter_application_1/services/backend_document_service.dart';

class SyllabusPdfScreen extends StatefulWidget {
  const SyllabusPdfScreen({super.key});

  @override
  State<SyllabusPdfScreen> createState() => _SyllabusPdfScreenState();
}

class _SyllabusPdfScreenState extends State<SyllabusPdfScreen> {
  late final Future<Uint8List> _pdfBytesFuture;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    _pdfBytesFuture = BackendDocumentService.fetchSyllabusPdfBytes();
  }

  Future<void> _downloadPdf(Uint8List bytes) async {
    if (_saving) {
      return;
    }
    setState(() => _saving = true);
    try {
      final savedPath = await BackendDocumentService.saveSyllabusPdf(bytes);
      if (!mounted) {
        return;
      }
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('PDF saved to $savedPath')),
      );
    } catch (error) {
      if (!mounted) {
        return;
      }
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to download PDF: $error')),
      );
    } finally {
      if (mounted) {
        setState(() => _saving = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        title: Text(
          'NEET Syllabus PDF',
          style: GoogleFonts.poppins(fontWeight: FontWeight.w800),
        ),
        actions: [
          FutureBuilder<Uint8List>(
            future: _pdfBytesFuture,
            builder: (context, snapshot) {
              final canDownload = snapshot.hasData && !_saving;
              return IconButton(
                onPressed: canDownload ? () => _downloadPdf(snapshot.data!) : null,
                icon: _saving
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(strokeWidth: 2.4),
                      )
                    : const Icon(Icons.download_rounded),
                tooltip: 'Download PDF',
              );
            },
          ),
        ],
      ),
      body: SafeArea(
        child: FutureBuilder<Uint8List>(
          future: _pdfBytesFuture,
          builder: (context, snapshot) {
            if (snapshot.connectionState != ConnectionState.done) {
              return Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const CircularProgressIndicator(),
                    const SizedBox(height: 12),
                    Text(
                      'Loading syllabus PDF...',
                      style: GoogleFonts.poppins(
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
              );
            }

            if (snapshot.hasError || !snapshot.hasData) {
              return Center(
                child: Padding(
                  padding: const EdgeInsets.all(24),
                  child: Text(
                    'Unable to load the syllabus PDF.\n${snapshot.error ?? ''}',
                    textAlign: TextAlign.center,
                    style: GoogleFonts.poppins(
                      color: theme.colorScheme.error,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              );
            }

            return SfPdfViewer.memory(snapshot.data!);
          },
        ),
      ),
    );
  }
}
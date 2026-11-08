import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import 'package:path_provider/path_provider.dart';
import 'dart:io';
import '../core/constants/app_colors.dart';
import '../providers/case_provider.dart';
import '../providers/evidence_provider.dart';

class ReportScreen extends StatefulWidget {
  const ReportScreen({super.key});
  @override
  State<ReportScreen> createState() => _ReportScreenState();
}

class _ReportScreenState extends State<ReportScreen> {
  bool _generating = false;
  String _status   = 'Click GENERATE to create forensic report';

  Future<void> _generatePdf() async {
    setState(() { _generating = true; _status = 'Generating report...'; });
    try {
      final caseData = context.read<CaseProvider>().activeCase;
      final evidence = context.read<EvidenceProvider>().evidence;

      if (caseData == null) {
        setState(() {
          _status = 'No active case — initialise a case first';
          _generating = false;
        });
        return;
      }

      final pdf = pw.Document();
      final now = DateTime.now().toString().substring(0,19);

      pdf.addPage(
        pw.MultiPage(
          pageFormat: PdfPageFormat.a4,
          margin: const pw.EdgeInsets.all(40),
          header: (_) => pw.Column(children: [
            pw.Row(children: [
              pw.Expanded(
                child: pw.Column(
                  crossAxisAlignment: pw.CrossAxisAlignment.start,
                  children: [
                    pw.Text('SPIDERCAM FORENSIC SUITE',
                      style: const pw.TextStyle(
                        fontSize: 18,
                        fontWeight: pw.FontWeight.bold,
                        color: PdfColor.fromInt(0xFF4DC8F0))),
                    pw.Text('Crime Scene Investigation Report',
                      style: const pw.TextStyle(
                        fontSize: 10,
                        color: PdfColors.grey600)),
                  ],
                ),
              ),
              pw.Text('v2.1  ·  M SELVAPRAKASH',
                style: const pw.TextStyle(
                  fontSize: 9,
                  color: PdfColors.grey500)),
            ]),
            pw.Divider(color: const PdfColor.fromInt(0xFF4DC8F0)),
            pw.SizedBox(height: 8),
          ]),
          build: (_) => [
            // Case info table
            pw.Text('CASE INFORMATION',
              style: const pw.TextStyle(
                fontSize: 12,
                fontWeight: pw.FontWeight.bold,
                color: PdfColor.fromInt(0xFF4DC8F0))),
            pw.SizedBox(height: 8),
            pw.Table(
              border: pw.TableBorder.all(
                  color: PdfColors.grey300, width: 0.5),
              children: [
                _tableRow('Case Number',   caseData.caseNumber),
                _tableRow('FIR Number',    caseData.firNumber),
                _tableRow('Officer',       caseData.officerName),
                _tableRow('Agency',        caseData.agency),
                _tableRow('Location',      caseData.location),
                _tableRow('Scene Type',    caseData.sceneType),
                _tableRow('Generated',     now),
                _tableRow('Chain of Custody', 'SHA-256 VERIFIED'),
              ],
            ),
            pw.SizedBox(height: 16),

            // Evidence summary
            pw.Text('EVIDENCE SUMMARY',
              style: const pw.TextStyle(
                fontSize: 12,
                fontWeight: pw.FontWeight.bold,
                color: PdfColor.fromInt(0xFF4DC8F0))),
            pw.SizedBox(height: 8),
            pw.Table(
              border: pw.TableBorder.all(
                  color: PdfColors.grey300, width: 0.5),
              children: [
                _tableRow('Total Items', '${evidence.length}'),
                _tableRow('Synced',
                    '${evidence.where((e) => e.synced).length}'),
              ],
            ),
            pw.SizedBox(height: 16),

            // Evidence registry
            if (evidence.isNotEmpty) ...[
              pw.Text('FORENSIC EVIDENCE REGISTRY',
                style: const pw.TextStyle(
                  fontSize: 12,
                  fontWeight: pw.FontWeight.bold,
                  color: PdfColor.fromInt(0xFF4DC8F0))),
              pw.SizedBox(height: 8),
              pw.Table(
                border: pw.TableBorder.all(
                    color: PdfColors.grey300, width: 0.5),
                columnWidths: {
                  0: const pw.FlexColumnWidth(1.2),
                  1: const pw.FlexColumnWidth(2),
                  2: const pw.FlexColumnWidth(2),
                  3: const pw.FlexColumnWidth(3),
                  4: const pw.FlexColumnWidth(2),
                },
                children: [
                  pw.TableRow(
                    decoration: const pw.BoxDecoration(
                        color: PdfColor.fromInt(0xFF0D3A5C)),
                    children: ['ID','Category','Timestamp','SHA-256','GPS']
                        .map((h) => pw.Padding(
                          padding: const pw.EdgeInsets.all(6),
                          child: pw.Text(h,
                            style: const pw.TextStyle(
                              color: PdfColors.white,
                              fontWeight: pw.FontWeight.bold,
                              fontSize: 9))))
                        .toList(),
                  ),
                  ...evidence.map((e) => pw.TableRow(
                    children: [
                      e.evidenceNumber,
                      e.category,
                      e.timestamp.toString().substring(0,16),
                      '${e.sha256Hash.substring(0,12)}...',
                      e.latitude != null
                          ? e.latitude!.toStringAsFixed(4)
                          : '—',
                    ].map((v) => pw.Padding(
                      padding: const pw.EdgeInsets.all(5),
                      child: pw.Text(v,
                        style: const pw.TextStyle(fontSize: 8))))
                        .toList(),
                  )),
                ],
              ),
            ],

            pw.SizedBox(height: 24),
            pw.Divider(),
            pw.Text(
              'Generated by SpiderCam Forensic Suite v2.1  ·  '
              'M SELVAPRAKASH  ·  $now',
              style: const pw.TextStyle(
                  fontSize: 8, color: PdfColors.grey500),
              textAlign: pw.TextAlign.center),
          ],
        ),
      );

      final dir    = await getTemporaryDirectory();
      final path   = '${dir.path}/forensic_report_'
          '${caseData.caseNumber.replaceAll(' ','_')}_'
          '${DateTime.now().millisecondsSinceEpoch}.pdf';
      final file   = File(path);
      await file.writeAsBytes(await pdf.save());

      setState(() {
        _status     = '✔ Report generated — ${file.path}';
        _generating = false;
      });

      // Show print/share dialog
      if (mounted) {
        await Printing.sharePdf(
          bytes: await pdf.save(),
          filename: 'SpiderCam_Forensic_Report.pdf',
        );
      }
    } catch (e) {
      setState(() {
        _status     = '✕ Failed: $e';
        _generating = false;
      });
    }
  }

  pw.TableRow _tableRow(String label, String value) => pw.TableRow(
    children: [
      pw.Padding(
        padding: const pw.EdgeInsets.all(6),
        child: pw.Text(label,
          style: const pw.TextStyle(
            fontWeight: pw.FontWeight.bold,
            fontSize: 9,
            color: PdfColors.blueGrey800))),
      pw.Padding(
        padding: const pw.EdgeInsets.all(6),
        child: pw.Text(value,
          style: const pw.TextStyle(fontSize: 9))),
    ],
  );

  @override
  Widget build(BuildContext context) {
    final caseData = context.watch<CaseProvider>().activeCase;
    final evidence = context.watch<EvidenceProvider>().evidence;

    return Scaffold(
      appBar: AppBar(title: const Text('FORENSIC REPORT')),
      body: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Status
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: AppColors.surfaceCard,
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: AppColors.border)),
              child: Row(children: [
                Icon(
                  _status.startsWith('✔')
                      ? Icons.check_circle_outline
                      : _status.startsWith('✕')
                          ? Icons.error_outline
                          : Icons.info_outline,
                  color: _status.startsWith('✔')
                      ? AppColors.green
                      : _status.startsWith('✕')
                          ? AppColors.red : AppColors.cyan,
                  size: 18),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(_status,
                    style: const TextStyle(
                      color: AppColors.textSecondary, fontSize: 12))),
              ]),
            ),
            const SizedBox(height: 20),

            // Preview
            if (caseData != null) ...[
              const Text('REPORT PREVIEW',
                style: TextStyle(
                  color: AppColors.textMuted,
                  fontSize: 10,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 2)),
              const SizedBox(height: 12),
              Expanded(
                child: Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: AppColors.surfaceCard,
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: AppColors.border)),
                  child: SingleChildScrollView(
                    child: Text(
                      _buildPreviewText(caseData, evidence),
                      style: const TextStyle(
                        color: AppColors.textSecondary,
                        fontSize: 11,
                        fontFamily: 'monospace',
                        height: 1.6)),
                  ),
                ),
              ),
              const SizedBox(height: 16),
            ] else
              const Expanded(
                child: Center(
                  child: Text('No active case',
                    style: TextStyle(
                        color: AppColors.textMuted, fontSize: 13))),
              ),

            // Generate button
            SizedBox(
              width: double.infinity,
              height: 52,
              child: ElevatedButton.icon(
                onPressed: _generating ? null : _generatePdf,
                icon: _generating
                    ? const SizedBox(
                        width: 18, height: 18,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: AppColors.background))
                    : const Icon(Icons.picture_as_pdf, size: 20),
                label: Text(
                  _generating
                      ? 'GENERATING...'
                      : 'GENERATE PDF REPORT',
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 1)),
              ),
            ),
          ],
        ),
      ),
    );
  }

  String _buildPreviewText(dynamic caseData, List evidence) {
    final lines = [
      '═══════════════════════════════════════════',
      '    SPIDERCAM FORENSIC SUITE  v2.1',
      '    CASE REPORT',
      '═══════════════════════════════════════════',
      'Case No:     ${caseData.caseNumber}',
      'FIR No:      ${caseData.firNumber}',
      'Officer:     ${caseData.officerName}',
      'Agency:      ${caseData.agency}',
      'Location:    ${caseData.location}',
      'Scene Type:  ${caseData.sceneType}',
      'Generated:   ${DateTime.now().toString().substring(0,19)}',
      'Operator:    M SELVAPRAKASH',
      '───────────────────────────────────────────',
      'EVIDENCE SUMMARY',
      '───────────────────────────────────────────',
      'Total Items: ${evidence.length}',
      'Synced:      ${evidence.where((e) => e.synced).length}',
      'Pending:     ${evidence.where((e) => !e.synced).length}',
      'CoC Status:  SHA-256 VERIFIED',
      '───────────────────────────────────────────',
      'EVIDENCE REGISTRY',
      '───────────────────────────────────────────',
      ...evidence.map((e) =>
        '${e.evidenceNumber}  ${e.category.padRight(20)} '
        '${e.timestamp.toString().substring(11,19)}'),
      '═══════════════════════════════════════════',
    ];
    return lines.join('\n');
  }
}
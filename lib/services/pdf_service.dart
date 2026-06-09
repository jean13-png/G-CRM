import 'dart:io';
import 'package:flutter/services.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import '../models/prospect.dart';
import 'package:intl/intl.dart';

class PdfService {
  static Future<void> exportFicheCRM(List<Prospect> prospects) async {
    final pdf = pw.Document();
    final DateFormat formatter = DateFormat('dd/MM/yyyy');

    pdf.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4.landscape,
        margin: const pw.EdgeInsets.all(20),
        build: (pw.Context context) {
          return [
            // Header
            pw.Container(
              width: double.infinity,
              padding: const pw.EdgeInsets.symmetric(vertical: 10),
              decoration: const pw.BoxDecoration(
                border: pw.Border(bottom: pw.BorderSide(width: 2)),
              ),
              child: pw.Center(
                child: pw.Text(
                  'FICHE CRM',
                  style: pw.TextStyle(
                    fontSize: 24,
                    fontWeight: pw.FontWeight.bold,
                  ),
                ),
              ),
            ),
            pw.SizedBox(height: 20),

            // Table
            pw.Table(
              border: pw.TableBorder.all(width: 0.5, color: PdfColors.black),
              columnWidths: {
                0: const pw.FixedColumnWidth(30), // N°
                1: const pw.FixedColumnWidth(120), // Infos Contact
                2: const pw.FlexColumnWidth(1), // S1
                3: const pw.FlexColumnWidth(1), // S2
                4: const pw.FlexColumnWidth(1), // S3
                5: const pw.FlexColumnWidth(1), // S4
                6: const pw.FlexColumnWidth(1), // S5
                7: const pw.FlexColumnWidth(1), // S6
                8: const pw.FlexColumnWidth(1), // S7
                9: const pw.FlexColumnWidth(1), // S8
                10: const pw.FixedColumnWidth(100), // Observation
                11: const pw.FixedColumnWidth(80), // Décision
              },
              children: [
                // Table Header Row
                pw.TableRow(
                  decoration: const pw.BoxDecoration(color: PdfColors.grey300),
                  children: [
                    _buildHeaderCell('N°'),
                    _buildHeaderCell('Date, Nom, Prénom & Contacts'),
                    _buildHeaderCell('SUIVI 1'),
                    _buildHeaderCell('SUIVI 2'),
                    _buildHeaderCell('SUIVI 3'),
                    _buildHeaderCell('SUIVI 4'),
                    _buildHeaderCell('SUIVI 5'),
                    _buildHeaderCell('SUIVI 6'),
                    _buildHeaderCell('SUIVI 7'),
                    _buildHeaderCell('SUIVI 8'),
                    _buildHeaderCell('OBSERVATION'),
                    _buildHeaderCell('DÉCISION'),
                  ],
                ),
                // Data Rows
                ...prospects.asMap().entries.map((entry) {
                  final index = entry.key + 1;
                  final p = entry.value;
                  return pw.TableRow(
                    children: [
                      _buildCell(index.toString()),
                      _buildContactCell(p, formatter),
                      ...List.generate(8, (i) => _buildSuiviCell(p.suivis[i], formatter)),
                      _buildCell(p.observation),
                      _buildCell(p.decision),
                    ],
                  );
                }),
              ],
            ),
          ];
        },
      ),
    );

    await Printing.layoutPdf(
      onLayout: (PdfPageFormat format) async => pdf.save(),
      name: 'Fiche_CRM_${DateTime.now().millisecondsSinceEpoch}.pdf',
    );
  }

  static pw.Widget _buildHeaderCell(String text) {
    return pw.Padding(
      padding: const pw.EdgeInsets.all(5),
      child: pw.Center(
        child: pw.Text(
          text,
          style: pw.TextStyle(fontSize: 8, fontWeight: pw.FontWeight.bold),
          textAlign: pw.TextAlign.center,
        ),
      ),
    );
  }

  static pw.Widget _buildCell(String text) {
    return pw.Padding(
      padding: const pw.EdgeInsets.all(4),
      child: pw.Text(
        text,
        style: const pw.TextStyle(fontSize: 7),
      ),
    );
  }

  static pw.Widget _buildContactCell(Prospect p, DateFormat formatter) {
    return pw.Padding(
      padding: const pw.EdgeInsets.all(4),
      child: pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          pw.Text(formatter.format(p.createdAt), style: pw.TextStyle(fontSize: 7, fontWeight: pw.FontWeight.bold)),
          pw.Text(p.name, style: const pw.TextStyle(fontSize: 7)),
          pw.Text(p.phone, style: const pw.TextStyle(fontSize: 7, color: PdfColors.blue)),
        ],
      ),
    );
  }

  static pw.Widget _buildSuiviCell(Suivi s, DateFormat formatter) {
    final hasData = s.date != null;
    return pw.Padding(
      padding: const pw.EdgeInsets.all(3),
      child: pw.Column(
        mainAxisAlignment: pw.MainAxisAlignment.center,
        children: [
          pw.Text(
            hasData ? formatter.format(s.date!) : '.../.../...',
            style: pw.TextStyle(fontSize: 6, color: hasData ? PdfColors.black : PdfColors.grey),
          ),
          pw.SizedBox(height: 2),
          pw.Text(
            s.resume.isNotEmpty ? s.resume : '...',
            style: pw.TextStyle(fontSize: 6, fontStyle: pw.FontStyle.italic),
            textAlign: pw.TextAlign.center,
            maxLines: 2,
          ),
        ],
      ),
    );
  }
}

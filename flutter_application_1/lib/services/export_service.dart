// lib/services/export_service.dart
import 'dart:io';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import 'package:path_provider/path_provider.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:intl/intl.dart';

class ExportService {
  // Export Dashboard Statistics to PDF
  static Future<bool> exportDashboardStats({
    required Map<String, dynamic> stats,
    String? fileName,
  }) async {
    try {
      final pdf = pw.Document();
      final dateFormat = DateFormat('yyyy-MM-dd HH:mm');

      pdf.addPage(
        pw.MultiPage(
          pageFormat: PdfPageFormat.a4,
          build: (pw.Context context) {
            return [
              // Header
              pw.Header(
                level: 0,
                child: pw.Text(
                  'SHAQATI - Dashboard Statistics Report',
                  style: pw.TextStyle(
                    fontSize: 24,
                    fontWeight: pw.FontWeight.bold,
                  ),
                ),
              ),
              pw.SizedBox(height: 20),
              pw.Text(
                'Generated: ${dateFormat.format(DateTime.now())}',
                style: pw.TextStyle(fontSize: 10, color: PdfColors.grey700),
              ),
              pw.SizedBox(height: 30),

              // Summary Statistics
              pw.Header(level: 1, text: 'Summary Statistics'),
              pw.SizedBox(height: 10),
              _buildStatsTable([
                ['Total Users', '${stats['totalUsers'] ?? 0}'],
                ['Total Properties', '${stats['totalProperties'] ?? 0}'],
                ['Total Contracts', '${stats['totalContracts'] ?? 0}'],
                ['Total Payments', '${stats['totalPayments'] ?? 0}'],
                ['Total Revenue', '\$${stats['totalRevenue'] ?? 0}'],
              ]),
              pw.SizedBox(height: 30),

              // User Statistics
              if (stats['userStats'] != null)
                ..._buildStatsSection('User Statistics', stats['userStats']),
              
              // Property Statistics
              if (stats['propertyStats'] != null)
                ..._buildStatsSection('Property Statistics', stats['propertyStats']),
              
              // Contract Statistics
              if (stats['contractStats'] != null)
                ..._buildStatsSection('Contract Statistics', stats['contractStats']),
              
              // Payment Statistics
              if (stats['paymentStats'] != null)
                ..._buildStatsSection('Payment Statistics', stats['paymentStats']),
            ];
          },
        ),
      );

      final bytes = await pdf.save();
      final finalFileName = fileName ?? 'dashboard_report_${DateTime.now().millisecondsSinceEpoch}.pdf';

      if (kIsWeb) {
        await Printing.layoutPdf(
          onLayout: (PdfPageFormat format) async => bytes,
        );
        return true;
      } else {
        // Mobile/Desktop
        if (Platform.isAndroid) {
          var status = await Permission.storage.status;
          if (!status.isGranted) {
            status = await Permission.storage.request();
          }
          if (!status.isGranted) return false;

          Directory? directory = Directory('/storage/emulated/0/Download');
          if (!await directory.exists()) {
            directory = await getExternalStorageDirectory();
          }

          final file = File('${directory!.path}/$finalFileName');
          await file.writeAsBytes(bytes);
          return true;
        } else if (Platform.isIOS) {
          final dir = await getApplicationDocumentsDirectory();
          final file = File('${dir.path}/$finalFileName');
          await file.writeAsBytes(bytes);
          await Printing.sharePdf(bytes: bytes, filename: finalFileName);
          return true;
        } else {
          // Desktop
          final dir = await getApplicationDocumentsDirectory();
          final file = File('${dir.path}/$finalFileName');
          await file.writeAsBytes(bytes);
          return true;
        }
      }
    } catch (e) {
      print('Export error: $e');
      return false;
    }
  }

  // Export Contracts List to PDF
  static Future<bool> exportContracts({
    required List<dynamic> contracts,
    String? fileName,
  }) async {
    try {
      final pdf = pw.Document();
      final dateFormat = DateFormat('yyyy-MM-dd');

      pdf.addPage(
        pw.MultiPage(
          pageFormat: PdfPageFormat.a4,
          build: (pw.Context context) {
            return [
              pw.Header(
                level: 0,
                child: pw.Text(
                  'SHAQATI - Contracts Report',
                  style: pw.TextStyle(
                    fontSize: 24,
                    fontWeight: pw.FontWeight.bold,
                  ),
                ),
              ),
              pw.SizedBox(height: 20),
              pw.Text(
                'Generated: ${dateFormat.format(DateTime.now())} | Total: ${contracts.length}',
                style: pw.TextStyle(fontSize: 10, color: PdfColors.grey700),
              ),
              pw.SizedBox(height: 30),

              // Contracts Table
              pw.TableHelper.fromTextArray(
                headers: ['ID', 'Property', 'Tenant', 'Landlord', 'Amount', 'Status', 'Start Date', 'End Date'],
                data: contracts.map((contract) {
                  final property = contract['propertyId'] ?? {};
                  final tenant = contract['tenantId'] ?? {};
                  final landlord = contract['landlordId'] ?? {};
                  final startDate = contract['startDate'] != null
                      ? dateFormat.format(DateTime.parse(contract['startDate']))
                      : 'N/A';
                  final endDate = contract['endDate'] != null
                      ? dateFormat.format(DateTime.parse(contract['endDate']))
                      : 'N/A';
                  
                  return [
                    contract['_id']?.toString().substring(0, 8) ?? 'N/A',
                    property['title']?.toString() ?? 'N/A',
                    tenant['name']?.toString() ?? 'N/A',
                    landlord['name']?.toString() ?? 'N/A',
                    '\$${contract['rentAmount'] ?? 0}',
                    contract['status']?.toString().toUpperCase() ?? 'N/A',
                    startDate,
                    endDate,
                  ];
                }).toList(),
                headerStyle: pw.TextStyle(
                  fontWeight: pw.FontWeight.bold,
                  color: PdfColors.white,
                ),
                headerDecoration: const pw.BoxDecoration(
                  color: PdfColors.grey700,
                ),
                cellAlignment: pw.Alignment.centerLeft,
                cellPadding: const pw.EdgeInsets.all(4),
              ),
            ];
          },
        ),
      );

      final bytes = await pdf.save();
      final finalFileName = fileName ?? 'contracts_report_${DateTime.now().millisecondsSinceEpoch}.pdf';

      if (kIsWeb) {
        await Printing.layoutPdf(
          onLayout: (PdfPageFormat format) async => bytes,
        );
        return true;
      } else {
        if (Platform.isAndroid) {
          var status = await Permission.storage.status;
          if (!status.isGranted) {
            status = await Permission.storage.request();
          }
          if (!status.isGranted) return false;

          Directory? directory = Directory('/storage/emulated/0/Download');
          if (!await directory.exists()) {
            directory = await getExternalStorageDirectory();
          }

          final file = File('${directory!.path}/$finalFileName');
          await file.writeAsBytes(bytes);
          return true;
        } else if (Platform.isIOS) {
          final dir = await getApplicationDocumentsDirectory();
          final file = File('${dir.path}/$finalFileName');
          await file.writeAsBytes(bytes);
          await Printing.sharePdf(bytes: bytes, filename: finalFileName);
          return true;
        } else {
          final dir = await getApplicationDocumentsDirectory();
          final file = File('${dir.path}/$finalFileName');
          await file.writeAsBytes(bytes);
          return true;
        }
      }
    } catch (e) {
      print('Export error: $e');
      return false;
    }
  }

  static pw.Widget _buildStatsTable(List<List<String>> rows) {
    return pw.Table(
      border: pw.TableBorder.all(color: PdfColors.grey300),
      children: rows.map((row) {
        return pw.TableRow(
          children: [
            pw.Padding(
              padding: const pw.EdgeInsets.all(8),
              child: pw.Text(
                row[0],
                style: pw.TextStyle(fontWeight: pw.FontWeight.bold),
              ),
            ),
            pw.Padding(
              padding: const pw.EdgeInsets.all(8),
              child: pw.Text(row[1]),
            ),
          ],
        );
      }).toList(),
    );
  }

  static List<pw.Widget> _buildStatsSection(String title, List<dynamic> stats) {
    return [
      pw.SizedBox(height: 20),
      pw.Header(level: 1, text: title),
      pw.SizedBox(height: 10),
      pw.Table(
        border: pw.TableBorder.all(color: PdfColors.grey300),
        children: [
          pw.TableRow(
            decoration: const pw.BoxDecoration(color: PdfColors.grey200),
            children: [
              pw.Padding(
                padding: const pw.EdgeInsets.all(8),
                child: pw.Text('Category', style: pw.TextStyle(fontWeight: pw.FontWeight.bold)),
              ),
              pw.Padding(
                padding: const pw.EdgeInsets.all(8),
                child: pw.Text('Count', style: pw.TextStyle(fontWeight: pw.FontWeight.bold)),
              ),
            ],
          ),
          ...stats.map((stat) {
            return pw.TableRow(
              children: [
                pw.Padding(
                  padding: const pw.EdgeInsets.all(8),
                  child: pw.Text(stat['_id']?.toString() ?? 'N/A'),
                ),
                pw.Padding(
                  padding: const pw.EdgeInsets.all(8),
                  child: pw.Text('${stat['count'] ?? 0}'),
                ),
              ],
            );
          }).toList(),
        ],
      ),
    ];
  }
}


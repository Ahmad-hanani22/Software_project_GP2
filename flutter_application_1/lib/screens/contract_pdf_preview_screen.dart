import 'dart:io'; // للموبايل فقط
import 'dart:typed_data';
import 'package:flutter/foundation.dart' show kIsWeb; // للتحقق من الويب
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

// المكتبات المطلوبة للـ PDF والتخزين
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import 'package:path_provider/path_provider.dart';
import 'package:permission_handler/permission_handler.dart';

class ContractPdfPreviewScreen extends StatelessWidget {
  final Map<String, dynamic> contract;

  const ContractPdfPreviewScreen({super.key, required this.contract});

  // 🎨 1. تصميم العقد الجديد (احترافي وقانوني)
  Future<Uint8List> _generatePdf(PdfPageFormat format) async {
    final pdf = pw.Document();

    // استخراج البيانات مع التأكد من عدم وجود قيم فارغة
    final property = contract['propertyId'] ?? {};
    final tenant = contract['tenantId'] ?? {};
    final landlord = contract['landlordId'] ?? {};

    // تنسيق التواريخ
    final startDateStr = contract['startDate'] != null
        ? DateFormat('yyyy-MM-dd').format(DateTime.parse(contract['startDate']))
        : 'Unknown';
    final endDateStr = contract['endDate'] != null
        ? DateFormat('yyyy-MM-dd').format(DateTime.parse(contract['endDate']))
        : 'Unknown';

    // تحميل خط (اختياري، هنا نستخدم الافتراضي)
    // final font = await PdfGoogleFonts.cairoRegular();

    pdf.addPage(
      pw.MultiPage(
        pageFormat: format,
        theme: pw.ThemeData.withFont(
          base: pw.Font.courier(), // خط رسمي للعقود
          bold: pw.Font.courierBold(),
        ),
        build: (pw.Context context) {
          return [
            // --- Header: Title ---
            pw.Center(
              child: pw.Column(
                children: [
                  pw.Text("RESIDENTIAL LEASE AGREEMENT",
                      style: pw.TextStyle(
                          fontSize: 20,
                          fontWeight: pw.FontWeight.bold,
                          decoration: pw.TextDecoration.underline)),
                  pw.SizedBox(height: 5),
                  pw.Text("CONTRACT ID: ${contract['_id']}",
                      style: const pw.TextStyle(
                          fontSize: 10, color: PdfColors.grey700)),
                ],
              ),
            ),
            pw.SizedBox(height: 30),

            // --- Section 1: Parties ---
            _buildHeader("1. THE PARTIES"),
            pw.Paragraph(
              text:
                  "This Lease Agreement is made on ${DateFormat('yyyy-MM-dd').format(DateTime.now())}, between:",
              style: const pw.TextStyle(fontSize: 12),
            ),
            pw.SizedBox(height: 10),
            pw.Table(
                border:
                    pw.TableBorder.all(color: PdfColors.grey400, width: 0.5),
                children: [
                  pw.TableRow(
                      decoration:
                          const pw.BoxDecoration(color: PdfColors.grey200),
                      children: [
                        pw.Padding(
                            padding: const pw.EdgeInsets.all(5),
                            child: pw.Text("LANDLORD (Lessor)",
                                style: pw.TextStyle(
                                    fontWeight: pw.FontWeight.bold))),
                        pw.Padding(
                            padding: const pw.EdgeInsets.all(5),
                            child: pw.Text("TENANT (Lessee)",
                                style: pw.TextStyle(
                                    fontWeight: pw.FontWeight.bold))),
                      ]),
                  pw.TableRow(children: [
                    pw.Padding(
                        padding: const pw.EdgeInsets.all(8),
                        child: pw.Column(
                            crossAxisAlignment: pw.CrossAxisAlignment.start,
                            children: [
                              pw.Text("Name: ${landlord['name'] ?? 'N/A'}"),
                              pw.Text("Email: ${landlord['email'] ?? 'N/A'}"),
                            ])),
                    pw.Padding(
                        padding: const pw.EdgeInsets.all(8),
                        child: pw.Column(
                            crossAxisAlignment: pw.CrossAxisAlignment.start,
                            children: [
                              pw.Text("Name: ${tenant['name'] ?? 'N/A'}"),
                              pw.Text("Email: ${tenant['email'] ?? 'N/A'}"),
                            ])),
                  ])
                ]),
            pw.SizedBox(height: 20),

            // --- Section 2: Property ---
            _buildHeader("2. PROPERTY DETAILS"),
            pw.Text(
                "The Landlord agrees to rent to the Tenant the property described as follows:",
                style: const pw.TextStyle(fontSize: 12)),
            pw.SizedBox(height: 10),
            pw.Container(
                padding: const pw.EdgeInsets.all(10),
                decoration: pw.BoxDecoration(
                    border: pw.Border.all(color: PdfColors.black)),
                child: pw.Column(
                    crossAxisAlignment: pw.CrossAxisAlignment.start,
                    children: [
                      _buildRow("Property Title", property['title'] ?? 'N/A'),
                      _buildRow("Type", property['type'] ?? 'Apartment'),
                      _buildRow("City / Location", property['city'] ?? 'N/A'),
                      _buildRow(
                          "Street / Address",
                          property['address'] ??
                              'N/A'), // تأكد من وجود هذا الحقل أو حذفه
                    ])),
            pw.SizedBox(height: 20),

            // --- Section 3: Term & Rent ---
            _buildHeader("3. TERM AND RENT"),
            pw.Bullet(text: "Lease Start Date: $startDateStr"),
            pw.Bullet(text: "Lease End Date: $endDateStr"),
            pw.Bullet(
                text: "Monthly Rent Amount: \$${contract['rentAmount'] ?? 0}"),
            pw.SizedBox(height: 20),

            // --- Section 4: Terms & Conditions (Legal Text) ---
            _buildHeader("4. TERMS AND CONDITIONS"),
            pw.Paragraph(
                text:
                    "A. PAYMENT: The Tenant agrees to pay the Rent to the Landlord on the agreed date of each month.",
                style: const pw.TextStyle(fontSize: 10)),
            pw.Paragraph(
                text:
                    "B. USE OF PROPERTY: The Tenant agrees to use the Property for residential purposes only and not for any illegal or commercial activities.",
                style: const pw.TextStyle(fontSize: 10)),
            pw.Paragraph(
                text:
                    "C. MAINTENANCE: The Tenant shall keep the Property in a clean and good condition. Major repairs shall be the responsibility of the Landlord.",
                style: const pw.TextStyle(fontSize: 10)),
            pw.SizedBox(height: 40),

            // --- Signatures ---
            pw.Divider(),
            pw.SizedBox(height: 20),
            pw.Row(
              mainAxisAlignment: pw.MainAxisAlignment.spaceAround,
              children: [
                _buildSignatureArea("Landlord Signature"),
                _buildSignatureArea("Tenant Signature"),
              ],
            ),

            pw.SizedBox(height: 30),
            pw.Center(
                child: pw.Text(
                    "This contract is officially generated by Shaqati App.",
                    style: const pw.TextStyle(
                        fontSize: 8, color: PdfColors.grey))),
          ];
        },
      ),
    );

    return pdf.save();
  }

  // دوال مساعدة للتصميم
  pw.Widget _buildHeader(String text) {
    return pw.Container(
      width: double.infinity,
      color: PdfColors.grey300,
      padding: const pw.EdgeInsets.all(5),
      margin: const pw.EdgeInsets.only(bottom: 10),
      child: pw.Text(text,
          style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 12)),
    );
  }

  pw.Widget _buildRow(String label, String value) {
    return pw.Padding(
      padding: const pw.EdgeInsets.only(bottom: 4),
      child: pw.Row(
        children: [
          pw.SizedBox(
              width: 120,
              child: pw.Text("$label:",
                  style: pw.TextStyle(fontWeight: pw.FontWeight.bold))),
          pw.Expanded(child: pw.Text(value)),
        ],
      ),
    );
  }

  pw.Widget _buildSignatureArea(String title) {
    return pw.Column(
      children: [
        pw.Container(
          width: 180,
          height: 40,
          decoration: const pw.BoxDecoration(
            border: pw.Border(bottom: pw.BorderSide(width: 1)),
          ),
        ),
        pw.SizedBox(height: 5),
        pw.Text(title, style: pw.TextStyle(fontWeight: pw.FontWeight.bold)),
      ],
    );
  }

  // 💾 2. دالة التحميل (معدلة لتعمل على الويب والموبايل)
  Future<void> _savePdfFile(BuildContext context) async {
    try {
      final Uint8List bytes = await _generatePdf(PdfPageFormat.a4);
      final String fileName = "contract_${contract['_id']}.pdf";

      // ✅ 1. إذا كان التطبيق يعمل على الويب (Web)
      if (kIsWeb) {
        // نستخدم Printing للمشاركة أو التنزيل، هذا يدعم الويب تلقائياً
        await Printing.sharePdf(bytes: bytes, filename: fileName);
        return;
      }

      // ✅ 2. إذا كان موبايل (Android/iOS)
      // هذا الكود لن يتم تنفيذه على الويب لتجنب الخطأ
      if (Platform.isAndroid) {
        var status = await Permission.storage.status;
        if (!status.isGranted) {
          status = await Permission.storage.request();
        }

        Directory? directory = Directory('/storage/emulated/0/Download');
        if (!await directory.exists()) {
          directory = await getExternalStorageDirectory();
        }

        final File file = File('${directory!.path}/$fileName');
        await file.writeAsBytes(bytes);

        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text("PDF Downloaded to Downloads folder! ✅"),
            backgroundColor: Colors.green,
          ),
        );
      } else if (Platform.isIOS) {
        final dir = await getApplicationDocumentsDirectory();
        final file = File('${dir.path}/$fileName');
        await file.writeAsBytes(bytes);
        // في iOS نستخدم المشاركة لأن الوصول للملفات مقيد
        await Printing.sharePdf(bytes: bytes, filename: fileName);
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text("Error: ${e.toString()}"),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("Official Contract"),
        backgroundColor: const Color(0xFF2E7D32),
        actions: [
          IconButton(
            icon: const Icon(Icons.download),
            onPressed: () => _savePdfFile(context),
            tooltip: "Download PDF",
          )
        ],
      ),
      body: PdfPreview(
        build: (format) => _generatePdf(format),
        allowSharing: kIsWeb
            ? false
            : true, // إخفاء زر المشاركة الافتراضي في الويب لتجنب التكرار
        allowPrinting: true,
        canChangePageFormat: false,
        pdfFileName: "contract_${contract['_id']}.pdf",
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _savePdfFile(context),
        backgroundColor: const Color(0xFF2E7D32),
        icon: const Icon(Icons.save_alt),
        label: const Text("Download PDF"),
      ),
    );
  }
}

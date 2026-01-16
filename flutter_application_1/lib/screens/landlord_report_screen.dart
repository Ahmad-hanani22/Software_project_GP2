import 'dart:io';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import 'package:path_provider/path_provider.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:intl/intl.dart';
import 'package:flutter_application_1/services/api_service.dart';
import 'package:shared_preferences/shared_preferences.dart';

const Color _primaryBeige = Color(0xFFD4B996);
const Color _accentGreen = Color(0xFF2E7D32);
const Color _textPrimary = Color(0xFF4E342E);
const Color _textSecondary = Color(0xFF8D8D8D);

class LandlordReportScreen extends StatefulWidget {
  const LandlordReportScreen({super.key});

  @override
  State<LandlordReportScreen> createState() => _LandlordReportScreenState();
}

class _LandlordReportScreenState extends State<LandlordReportScreen> {
  bool _isLoading = true;
  bool _isExporting = false;
  String? _landlordName;
  String? _landlordId;
  
  // Report Data
  List<dynamic> _properties = [];
  List<dynamic> _contracts = [];
  List<dynamic> _payments = [];
  List<dynamic> _maintenance = [];
  Map<String, dynamic> _summary = {};

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    setState(() => _isLoading = true);
    
    final prefs = await SharedPreferences.getInstance();
    _landlordId = prefs.getString('userId');
    _landlordName = prefs.getString('userName') ?? 'Landlord';
    
    if (_landlordId != null) {
      await _fetchAllData();
    }
    
    if (mounted) {
      setState(() => _isLoading = false);
    }
  }

  Future<void> _fetchAllData() async {
    // Fetch properties
    final (okProps, propsData) = await ApiService.getPropertiesByOwner(_landlordId!);
    if (okProps && propsData is List) {
      _properties = propsData;
    }

    // Fetch contracts
    final (okContracts, contractsData) = await ApiService.getAllContracts();
    if (okContracts && contractsData is List) {
      final propertyIds = _properties.map((p) => p['_id']).toSet();
      _contracts = contractsData.where((contract) {
        final propertyId = contract['propertyId'];
        if (propertyId is Map) {
          return propertyIds.contains(propertyId['_id']);
        } else if (propertyId is String) {
          return propertyIds.contains(propertyId);
        }
        return false;
      }).toList();
    }

    // Fetch payments
    final (okPayments, paymentsData) = await ApiService.getAllPayments();
    if (okPayments && paymentsData is List) {
      final contractIds = _contracts.map((c) => c['_id']).toSet();
      _payments = paymentsData.where((payment) {
        final contractId = payment['contractId'];
        if (contractId is Map) {
          return contractIds.contains(contractId['_id']);
        } else if (contractId is String) {
          return contractIds.contains(contractId);
        }
        return false;
      }).toList();
    }

    // Fetch maintenance
    final (okMaintenance, maintenanceData) = await ApiService.getAllMaintenance();
    if (okMaintenance && maintenanceData is List) {
      final propertyIds = _properties.map((p) => p['_id']).toSet();
      _maintenance = maintenanceData.where((request) {
        final propertyId = request['propertyId'];
        if (propertyId is Map) {
          return propertyIds.contains(propertyId['_id']);
        } else if (propertyId is String) {
          return propertyIds.contains(propertyId);
        }
        return false;
      }).toList();
    }

    // Calculate summary
    _calculateSummary();
  }

  void _calculateSummary() {
    final totalProperties = _properties.length;
    final availableProperties = _properties.where((p) => p['status'] == 'available').length;
    final rentedProperties = _properties.where((p) => p['status'] == 'rented').length;
    final activeContracts = _contracts.where((c) => c['status'] == 'active').length;
    final totalRevenue = _payments
        .where((p) => p['status'] == 'paid')
        .fold<double>(0, (sum, p) => sum + ((p['amount'] ?? 0) as num).toDouble());
    final pendingMaintenance = _maintenance.where((m) => m['status'] == 'pending').length;
    final totalTenants = _contracts.map((c) => c['tenantId']).whereType<dynamic>().toSet().length;

    _summary = {
      'totalProperties': totalProperties,
      'availableProperties': availableProperties,
      'rentedProperties': rentedProperties,
      'activeContracts': activeContracts,
      'totalRevenue': totalRevenue,
      'pendingMaintenance': pendingMaintenance,
      'totalTenants': totalTenants,
    };
  }

  Future<void> _exportToPDF() async {
    setState(() => _isExporting = true);

    try {
      final pdf = pw.Document();
      final dateFormat = DateFormat('yyyy-MM-dd HH:mm');

      pdf.addPage(
        pw.MultiPage(
          pageFormat: PdfPageFormat.a4,
          margin: const pw.EdgeInsets.all(40),
          build: (pw.Context context) {
            return [
              // Header
              pw.Header(
                level: 0,
                child: pw.Row(
                  mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                  children: [
                    pw.Text(
                      'SHAQATI - Comprehensive Report',
                      style: pw.TextStyle(
                        fontSize: 24,
                        fontWeight: pw.FontWeight.bold,
                        color: PdfColors.green700,
                      ),
                    ),
                    pw.Text(
                      dateFormat.format(DateTime.now()),
                      style: pw.TextStyle(fontSize: 10, color: PdfColors.grey700),
                    ),
                  ],
                ),
              ),
              pw.SizedBox(height: 20),
              pw.Text(
                'Complete Report on Properties, Tenants, and Rentals',
                style: pw.TextStyle(fontSize: 16, fontWeight: pw.FontWeight.bold),
              ),
              pw.Text(
                'Property Owner: $_landlordName',
                style: pw.TextStyle(fontSize: 12, color: PdfColors.grey700),
              ),
              pw.Divider(),
              pw.SizedBox(height: 20),

              // Summary Section
              pw.Header(level: 1, text: 'Summary Overview'),
              pw.SizedBox(height: 10),
              _buildSummaryTable(),
              pw.SizedBox(height: 30),

              // Properties Section
              pw.Header(level: 1, text: 'Properties (${_properties.length})'),
              pw.SizedBox(height: 10),
              _buildPropertiesTable(),
              pw.SizedBox(height: 30),

              // Contracts Section
              pw.Header(level: 1, text: 'Contracts (${_contracts.length})'),
              pw.SizedBox(height: 10),
              _buildContractsTable(),
              pw.SizedBox(height: 30),

              // Tenants Section
              pw.Header(level: 1, text: 'Tenants (${_summary['totalTenants']})'),
              pw.SizedBox(height: 10),
              _buildTenantsTable(),
              pw.SizedBox(height: 30),

              // Payments Section
              pw.Header(level: 1, text: 'Payments (${_payments.length})'),
              pw.SizedBox(height: 10),
              _buildPaymentsTable(),
              pw.SizedBox(height: 30),

              // Maintenance Section
              pw.Header(level: 1, text: 'Maintenance Requests (${_maintenance.length})'),
              pw.SizedBox(height: 10),
              _buildMaintenanceTable(),
            ];
          },
        ),
      );

      final bytes = await pdf.save();
      final fileName = 'landlord_report_${DateTime.now().millisecondsSinceEpoch}.pdf';

      if (kIsWeb) {
        // Use sharePdf for direct download on web
        await Printing.sharePdf(bytes: bytes, filename: fileName);
      } else {
        if (Platform.isAndroid) {
          var status = await Permission.storage.status;
          if (!status.isGranted) {
            status = await Permission.storage.request();
          }
          if (!status.isGranted) {
            if (mounted) {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Permission denied')),
              );
            }
            return;
          }

          Directory? directory = Directory('/storage/emulated/0/Download');
          if (!await directory.exists()) {
            directory = await getExternalStorageDirectory();
          }

          final file = File('${directory!.path}/$fileName');
          await file.writeAsBytes(bytes);
          
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(content: Text('تم حفظ التقرير: $fileName')),
            );
          }
        } else if (Platform.isIOS) {
          final dir = await getApplicationDocumentsDirectory();
          final file = File('${dir.path}/$fileName');
          await file.writeAsBytes(bytes);
          await Printing.sharePdf(bytes: bytes, filename: fileName);
        } else {
          final dir = await getApplicationDocumentsDirectory();
          final file = File('${dir.path}/$fileName');
          await file.writeAsBytes(bytes);
          
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(content: Text('تم حفظ التقرير: $fileName')),
            );
          }
        }
      }

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Report exported successfully'),
            backgroundColor: _accentGreen,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Export error: $e')),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isExporting = false);
      }
    }
  }

  pw.Widget _buildSummaryTable() {
    return pw.Table(
      border: pw.TableBorder.all(),
      children: [
        _buildTableRow(['Metric', 'Value'], isHeader: true),
        _buildTableRow(['Total Properties', '${_summary['totalProperties']}']),
        _buildTableRow(['Available Properties', '${_summary['availableProperties']}']),
        _buildTableRow(['Rented Properties', '${_summary['rentedProperties']}']),
        _buildTableRow(['Active Contracts', '${_summary['activeContracts']}']),
        _buildTableRow(['Total Revenue', NumberFormat.simpleCurrency(name: 'USD', decimalDigits: 0).format(_summary['totalRevenue'])]),
        _buildTableRow(['Total Tenants', '${_summary['totalTenants']}']),
        _buildTableRow(['Pending Maintenance', '${_summary['pendingMaintenance']}']),
      ],
    );
  }

  pw.Widget _buildPropertiesTable() {
    if (_properties.isEmpty) {
      return pw.Text('No properties found', style: pw.TextStyle(color: PdfColors.grey));
    }

    return pw.Table(
      border: pw.TableBorder.all(),
      columnWidths: {
        0: const pw.FlexColumnWidth(3),
        1: const pw.FlexColumnWidth(2),
        2: const pw.FlexColumnWidth(2),
        3: const pw.FlexColumnWidth(1),
      },
      children: [
        _buildTableRow(['Title', 'City', 'Price', 'Status'], isHeader: true),
        ..._properties.take(20).map((prop) => _buildTableRow([
          prop['title'] ?? 'N/A',
          prop['city'] ?? 'N/A',
          NumberFormat.simpleCurrency(name: 'USD', decimalDigits: 0).format(prop['price'] ?? 0),
          prop['status'] ?? 'N/A',
        ])),
      ],
    );
  }

  pw.Widget _buildContractsTable() {
    if (_contracts.isEmpty) {
      return pw.Text('No contracts found', style: pw.TextStyle(color: PdfColors.grey));
    }

    return pw.Table(
      border: pw.TableBorder.all(),
      columnWidths: {
        0: const pw.FlexColumnWidth(2),
        1: const pw.FlexColumnWidth(2),
        2: const pw.FlexColumnWidth(2),
        3: const pw.FlexColumnWidth(1),
      },
      children: [
        _buildTableRow(['Property', 'Tenant', 'Monthly Rent', 'Status'], isHeader: true),
        ..._contracts.take(20).map((contract) {
          final property = contract['propertyId'] ?? {};
          final tenant = contract['tenantId'] ?? {};
          return _buildTableRow([
            property['title'] ?? 'N/A',
            tenant['name'] ?? 'N/A',
            NumberFormat.simpleCurrency(name: 'USD', decimalDigits: 0).format(contract['rentAmount'] ?? 0),
            contract['status'] ?? 'N/A',
          ]);
        }),
      ],
    );
  }

  pw.Widget _buildTenantsTable() {
    final tenants = <String, Map<dynamic, dynamic>>{};
    for (var contract in _contracts) {
      final tenant = contract['tenantId'];
      if (tenant is Map) {
        final tenantId = tenant['_id']?.toString() ?? '';
        if (!tenants.containsKey(tenantId)) {
          tenants[tenantId] = {
            'name': tenant['name'] ?? 'N/A',
            'email': tenant['email'] ?? 'N/A',
            'phone': tenant['phone'] ?? 'N/A',
            'property': (contract['propertyId'] ?? {})['title'] ?? 'N/A',
          };
        }
      }
    }

    if (tenants.isEmpty) {
      return pw.Text('No tenants found', style: pw.TextStyle(color: PdfColors.grey));
    }

    return pw.Table(
      border: pw.TableBorder.all(),
      columnWidths: {
        0: const pw.FlexColumnWidth(2),
        1: const pw.FlexColumnWidth(2),
        2: const pw.FlexColumnWidth(2),
        3: const pw.FlexColumnWidth(2),
      },
      children: [
        _buildTableRow(['Name', 'Email', 'Phone', 'Property'], isHeader: true),
        ...tenants.values.take(20).map((tenant) => _buildTableRow([
          tenant['name'],
          tenant['email'],
          tenant['phone'],
          tenant['property'],
        ])),
      ],
    );
  }

  pw.Widget _buildPaymentsTable() {
    if (_payments.isEmpty) {
      return pw.Text('No payments found', style: pw.TextStyle(color: PdfColors.grey));
    }

    return pw.Table(
      border: pw.TableBorder.all(),
      columnWidths: {
        0: const pw.FlexColumnWidth(2),
        1: const pw.FlexColumnWidth(2),
        2: const pw.FlexColumnWidth(2),
        3: const pw.FlexColumnWidth(1),
      },
      children: [
        _buildTableRow(['Date', 'Amount', 'Method', 'Status'], isHeader: true),
        ..._payments.take(20).map((payment) {
          final date = payment['date'] != null
              ? DateFormat('yyyy-MM-dd').format(DateTime.parse(payment['date']))
              : 'N/A';
          return _buildTableRow([
            date,
            NumberFormat.simpleCurrency(name: 'USD', decimalDigits: 0).format(payment['amount'] ?? 0),
            payment['method'] ?? 'N/A',
            payment['status'] ?? 'N/A',
          ]);
        }),
      ],
    );
  }

  pw.Widget _buildMaintenanceTable() {
    if (_maintenance.isEmpty) {
      return pw.Text('No maintenance requests found', style: pw.TextStyle(color: PdfColors.grey));
    }

    return pw.Table(
      border: pw.TableBorder.all(),
      columnWidths: {
        0: const pw.FlexColumnWidth(2),
        1: const pw.FlexColumnWidth(3),
        2: const pw.FlexColumnWidth(1),
      },
      children: [
        _buildTableRow(['Property', 'Description', 'Status'], isHeader: true),
        ..._maintenance.take(20).map((request) {
          final property = request['propertyId'] ?? {};
          return _buildTableRow([
            property['title'] ?? 'N/A',
            (request['description'] ?? 'N/A').toString().length > 50
                ? '${(request['description'] ?? 'N/A').toString().substring(0, 50)}...'
                : request['description'] ?? 'N/A',
            request['status'] ?? 'N/A',
          ]);
        }),
      ],
    );
  }

  pw.TableRow _buildTableRow(List<String> cells, {bool isHeader = false}) {
    return pw.TableRow(
      decoration: isHeader
          ? pw.BoxDecoration(color: PdfColors.grey300)
          : null,
      children: cells.map((cell) => pw.Padding(
        padding: const pw.EdgeInsets.all(8),
        child: pw.Text(
          cell,
          style: pw.TextStyle(
            fontSize: isHeader ? 10 : 9,
            fontWeight: isHeader ? pw.FontWeight.bold : pw.FontWeight.normal,
          ),
        ),
      )).toList(),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey[100],
      appBar: AppBar(
        title: const Text('Comprehensive Report'),
        backgroundColor: _primaryBeige,
        foregroundColor: Colors.white,
        actions: [
          if (_isExporting)
            const Padding(
              padding: EdgeInsets.all(16),
              child: SizedBox(
                width: 20,
                height: 20,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                ),
              ),
            )
          else
            IconButton(
              icon: const Icon(Icons.download),
              onPressed: _exportToPDF,
              tooltip: 'Download PDF',
            ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator(color: _accentGreen))
          : SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Summary Cards
                  _buildSummaryCards(),
                  const SizedBox(height: 24),
                  // Properties Section
                  _buildSection('Properties', _properties.length, _buildPropertiesList()),
                  const SizedBox(height: 24),
                  // Contracts Section
                  _buildSection('Contracts', _contracts.length, _buildContractsList()),
                  const SizedBox(height: 24),
                  // Tenants Section
                  _buildSection('Tenants', _summary['totalTenants'] ?? 0, _buildTenantsList()),
                  const SizedBox(height: 24),
                  // Payments Section
                  _buildSection('Payments', _payments.length, _buildPaymentsList()),
                  const SizedBox(height: 24),
                  // Maintenance Section
                  _buildSection('Maintenance Requests', _maintenance.length, _buildMaintenanceList()),
                ],
              ),
            ),
    );
  }

  Widget _buildSummaryCards() {
    return GridView.count(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      crossAxisCount: 4,
      crossAxisSpacing: 12,
      mainAxisSpacing: 12,
      childAspectRatio: 1.5,
      children: [
        _buildSummaryCard('Total Properties', '${_summary['totalProperties']}', Icons.home_work, Colors.blue),
        _buildSummaryCard('Active Contracts', '${_summary['activeContracts']}', Icons.description, _accentGreen),
        _buildSummaryCard('Total Revenue', NumberFormat.simpleCurrency(name: 'USD', decimalDigits: 0).format(_summary['totalRevenue']), Icons.attach_money, Colors.orange),
        _buildSummaryCard('Tenants', '${_summary['totalTenants']}', Icons.people, Colors.purple),
      ],
    );
  }

  Widget _buildSummaryCard(String title, String value, IconData icon, Color color) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, color: color, size: 32),
            const SizedBox(height: 8),
            Text(
              value,
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: color),
            ),
            const SizedBox(height: 4),
            Text(
              title,
              style: const TextStyle(fontSize: 12, color: _textSecondary),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSection(String title, int count, Widget content) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              '$title ($count)',
              style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: _textPrimary),
            ),
            const Divider(),
            content,
          ],
        ),
      ),
    );
  }

  Widget _buildPropertiesList() {
    if (_properties.isEmpty) {
      return const Text('No properties found', style: TextStyle(color: _textSecondary));
    }
    return Column(
      children: _properties.take(10).map((prop) => ListTile(
        leading: const Icon(Icons.home, color: _accentGreen),
        title: Text(prop['title'] ?? 'N/A'),
        subtitle: Text('${prop['city'] ?? 'N/A'} • ${NumberFormat.simpleCurrency(name: 'USD', decimalDigits: 0).format(prop['price'] ?? 0)}'),
        trailing: Chip(
          label: Text(prop['status'] ?? 'N/A', style: const TextStyle(fontSize: 10)),
          backgroundColor: (prop['status'] == 'rented') ? _accentGreen.withOpacity(0.2) : Colors.grey[200],
        ),
      )).toList(),
    );
  }

  Widget _buildContractsList() {
    if (_contracts.isEmpty) {
      return const Text('No contracts found', style: TextStyle(color: _textSecondary));
    }
    return Column(
      children: _contracts.take(10).map((contract) {
        final property = contract['propertyId'] ?? {};
        final tenant = contract['tenantId'] ?? {};
        return ListTile(
          leading: const Icon(Icons.description, color: Colors.blue),
          title: Text(property['title'] ?? 'N/A'),
          subtitle: Text('${tenant['name'] ?? 'N/A'} • ${NumberFormat.simpleCurrency(name: 'USD', decimalDigits: 0).format(contract['rentAmount'] ?? 0)}'),
          trailing: Chip(
            label: Text(contract['status'] ?? 'N/A', style: const TextStyle(fontSize: 10)),
            backgroundColor: (contract['status'] == 'active') ? _accentGreen.withOpacity(0.2) : Colors.grey[200],
          ),
        );
      }).toList(),
    );
  }

  Widget _buildTenantsList() {
    final tenants = <String, Map<dynamic, dynamic>>{};
    for (var contract in _contracts) {
      final tenant = contract['tenantId'];
      if (tenant is Map) {
        final tenantId = tenant['_id']?.toString() ?? '';
        if (!tenants.containsKey(tenantId)) {
          tenants[tenantId] = Map<dynamic, dynamic>.from(tenant);
        }
      }
    }

    if (tenants.isEmpty) {
      return const Text('No tenants found', style: TextStyle(color: _textSecondary));
    }
    return Column(
      children: tenants.values.take(10).map((tenant) => ListTile(
        leading: const Icon(Icons.person, color: Colors.purple),
        title: Text(tenant['name'] ?? 'N/A'),
        subtitle: Text('${tenant['email'] ?? 'N/A'} • ${tenant['phone'] ?? 'N/A'}'),
      )).toList(),
    );
  }

  Widget _buildPaymentsList() {
    if (_payments.isEmpty) {
      return const Text('No payments found', style: TextStyle(color: _textSecondary));
    }
    return Column(
      children: _payments.take(10).map((payment) {
        final date = payment['date'] != null
            ? DateFormat('yyyy-MM-dd').format(DateTime.parse(payment['date']))
            : 'N/A';
        return ListTile(
          leading: Icon(
            payment['status'] == 'paid' ? Icons.check_circle : Icons.pending,
            color: payment['status'] == 'paid' ? _accentGreen : Colors.orange,
          ),
          title: Text(NumberFormat.simpleCurrency(name: 'USD', decimalDigits: 0).format(payment['amount'] ?? 0)),
          subtitle: Text('$date • ${payment['method'] ?? 'N/A'}'),
          trailing: Chip(
            label: Text(payment['status'] ?? 'N/A', style: const TextStyle(fontSize: 10)),
            backgroundColor: (payment['status'] == 'paid') ? _accentGreen.withOpacity(0.2) : Colors.orange.withOpacity(0.2),
          ),
        );
      }).toList(),
    );
  }

  Widget _buildMaintenanceList() {
    if (_maintenance.isEmpty) {
      return const Text('No maintenance requests found', style: TextStyle(color: _textSecondary));
    }
    return Column(
      children: _maintenance.take(10).map((request) {
        final property = request['propertyId'] ?? {};
        return ListTile(
          leading: const Icon(Icons.build, color: Colors.orange),
          title: Text(property['title'] ?? 'N/A'),
          subtitle: Text((request['description'] ?? 'N/A').toString()),
          trailing: Chip(
            label: Text(request['status'] ?? 'N/A', style: const TextStyle(fontSize: 10)),
            backgroundColor: (request['status'] == 'resolved') ? _accentGreen.withOpacity(0.2) : Colors.orange.withOpacity(0.2),
          ),
        );
      }).toList(),
    );
  }
}


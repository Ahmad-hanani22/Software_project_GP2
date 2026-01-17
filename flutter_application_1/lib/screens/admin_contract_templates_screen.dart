import 'package:flutter/material.dart';
import 'package:flutter_application_1/services/api_service.dart';

const Color _primaryGreen = Color(0xFF2E7D32);
const Color _bgWhite = Color(0xFFF5F5F5);

class AdminContractTemplatesScreen extends StatefulWidget {
  const AdminContractTemplatesScreen({super.key});

  @override
  State<AdminContractTemplatesScreen> createState() =>
      _AdminContractTemplatesScreenState();
}

class _AdminContractTemplatesScreenState
    extends State<AdminContractTemplatesScreen> {
  bool _isLoading = true;
  List<dynamic> _templates = [];
  List<dynamic> _filteredTemplates = [];
  final TextEditingController _searchController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _fetchTemplates();
    _searchController.addListener(_onSearchChanged);
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _fetchTemplates() async {
    setState(() => _isLoading = true);
    final (ok, data) = await ApiService.getAllContractTemplates();
    if (mounted) {
      setState(() {
        if (ok && data is List) {
          _templates = data;
          _filteredTemplates = data;
        }
        _isLoading = false;
      });
    }
  }

  void _onSearchChanged() {
    final query = _searchController.text.toLowerCase();
    setState(() {
      _filteredTemplates = _templates.where((template) {
        final name = (template['name'] ?? '').toString().toLowerCase();
        final description =
            (template['description'] ?? '').toString().toLowerCase();
        return name.contains(query) || description.contains(query);
      }).toList();
    });
  }

  void _showAddEditDialog({dynamic template}) {
    final nameController =
        TextEditingController(text: template?['name'] ?? '');
    final descriptionController =
        TextEditingController(text: template?['description'] ?? '');
    final rentAmountController = TextEditingController(
        text: (template?['defaultRentAmount'] ?? 0).toString());
    final depositAmountController = TextEditingController(
        text: (template?['defaultDepositAmount'] ?? 0).toString());
    final durationController = TextEditingController(
        text: (template?['defaultContractDuration'] ?? 12).toString());
    final templateContentController =
        TextEditingController(text: template?['templateContent'] ?? '');
    final paymentCycle = template?['defaultPaymentCycle'] ?? 'monthly';
    bool isActive = template?['isActive'] ?? true;
    bool isDefault = template?['isDefault'] ?? false;

    String selectedPaymentCycle = paymentCycle;

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) => Dialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          child: Container(
            constraints: const BoxConstraints(maxWidth: 600),
            padding: const EdgeInsets.all(24),
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        template == null ? 'Add Template' : 'Edit Template',
                        style: const TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      IconButton(
                        icon: const Icon(Icons.close),
                        onPressed: () => Navigator.of(ctx).pop(),
                      ),
                    ],
                  ),
                  const SizedBox(height: 24),
                  TextFormField(
                    controller: nameController,
                    decoration: const InputDecoration(
                      labelText: 'Template Name *',
                      border: OutlineInputBorder(),
                      prefixIcon: Icon(Icons.description),
                    ),
                  ),
                  const SizedBox(height: 16),
                  TextFormField(
                    controller: descriptionController,
                    decoration: const InputDecoration(
                      labelText: 'Description',
                      border: OutlineInputBorder(),
                      prefixIcon: Icon(Icons.info_outline),
                    ),
                    maxLines: 3,
                  ),
                  const SizedBox(height: 16),
                  Row(
                    children: [
                      Expanded(
                        child: TextFormField(
                          controller: rentAmountController,
                          decoration: const InputDecoration(
                            labelText: 'Default Rent Amount',
                            border: OutlineInputBorder(),
                            prefixIcon: Icon(Icons.attach_money),
                          ),
                          keyboardType: const TextInputType.numberWithOptions(
                              decimal: true),
                        ),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: TextFormField(
                          controller: depositAmountController,
                          decoration: const InputDecoration(
                            labelText: 'Default Deposit Amount',
                            border: OutlineInputBorder(),
                            prefixIcon: Icon(Icons.security),
                          ),
                          keyboardType: const TextInputType.numberWithOptions(
                              decimal: true),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  Row(
                    children: [
                      Expanded(
                        child: TextFormField(
                          controller: durationController,
                          decoration: const InputDecoration(
                            labelText: 'Contract Duration (Months)',
                            border: OutlineInputBorder(),
                            prefixIcon: Icon(Icons.calendar_today),
                          ),
                          keyboardType: TextInputType.number,
                        ),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: DropdownButtonFormField<String>(
                          value: selectedPaymentCycle,
                          decoration: const InputDecoration(
                            labelText: 'Payment Cycle',
                            border: OutlineInputBorder(),
                            prefixIcon: Icon(Icons.payment),
                          ),
                          items: const [
                            DropdownMenuItem(
                                value: 'monthly', child: Text('Monthly')),
                            DropdownMenuItem(
                                value: 'quarterly', child: Text('Quarterly')),
                            DropdownMenuItem(
                                value: 'yearly', child: Text('Yearly')),
                          ],
                          onChanged: (value) {
                            setDialogState(() {
                              selectedPaymentCycle = value ?? 'monthly';
                            });
                          },
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  TextFormField(
                    controller: templateContentController,
                    decoration: const InputDecoration(
                      labelText: 'Template Content (Terms & Conditions)',
                      border: OutlineInputBorder(),
                      prefixIcon: Icon(Icons.article),
                      alignLabelWithHint: true,
                    ),
                    maxLines: 8,
                  ),
                  const SizedBox(height: 16),
                  Row(
                    children: [
                      Checkbox(
                        value: isActive,
                        onChanged: (value) {
                          setDialogState(() {
                            isActive = value ?? true;
                          });
                        },
                      ),
                      const Text('Active'),
                      const SizedBox(width: 24),
                      Checkbox(
                        value: isDefault,
                        onChanged: (value) {
                          setDialogState(() {
                            isDefault = value ?? false;
                          });
                        },
                      ),
                      const Text('Default Template'),
                    ],
                  ),
                  const SizedBox(height: 24),
                  ElevatedButton(
                    onPressed: () async {
                      final templateData = {
                        'name': nameController.text.trim(),
                        'description': descriptionController.text.trim(),
                        'defaultRentAmount': double.tryParse(
                                rentAmountController.text) ??
                            0,
                        'defaultDepositAmount': double.tryParse(
                                depositAmountController.text) ??
                            0,
                        'defaultContractDuration':
                            int.tryParse(durationController.text) ?? 12,
                        'defaultPaymentCycle': selectedPaymentCycle,
                        'templateContent': templateContentController.text.trim(),
                        'isActive': isActive,
                        'isDefault': isDefault,
                      };

                      Navigator.of(ctx).pop();
                      setState(() => _isLoading = true);

                      final (ok, message) = template == null
                          ? await ApiService.addContractTemplate(templateData)
                          : await ApiService.updateContractTemplate(
                              template['_id'].toString(), templateData);

                      if (mounted) {
                        setState(() => _isLoading = false);
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: Text(message),
                            backgroundColor:
                                ok ? _primaryGreen : Colors.red,
                          ),
                        );
                        if (ok) _fetchTemplates();
                      }
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: _primaryGreen,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 14),
                    ),
                    child: Text(template == null
                        ? 'Create Template'
                        : 'Update Template'),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Future<void> _deleteTemplate(dynamic template) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text('Delete Template'),
        content: Text(
          'Are you sure you want to delete "${template['name']}"? This action cannot be undone.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red,
              foregroundColor: Colors.white,
            ),
            child: const Text('Delete'),
          ),
        ],
      ),
    );

    if (confirm == true) {
      setState(() => _isLoading = true);
      final (ok, message) = await ApiService.deleteContractTemplate(
          template['_id'].toString());
      if (mounted) {
        setState(() => _isLoading = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(message),
            backgroundColor: ok ? _primaryGreen : Colors.red,
          ),
        );
        if (ok) _fetchTemplates();
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _bgWhite,
      appBar: AppBar(
        backgroundColor: _primaryGreen,
        title: const Text('Contract Templates'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _fetchTemplates,
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator(color: _primaryGreen))
          : Column(
              children: [
                Padding(
                  padding: const EdgeInsets.all(16),
                  child: Row(
                    children: [
                      Expanded(
                        child: TextField(
                          controller: _searchController,
                          decoration: InputDecoration(
                            hintText: 'Search templates...',
                            prefixIcon: const Icon(Icons.search),
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                            filled: true,
                            fillColor: Colors.white,
                          ),
                        ),
                      ),
                      const SizedBox(width: 16),
                      ElevatedButton.icon(
                        onPressed: () => _showAddEditDialog(),
                        icon: const Icon(Icons.add),
                        label: const Text('Add Template'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: _primaryGreen,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(
                              horizontal: 20, vertical: 12),
                        ),
                      ),
                    ],
                  ),
                ),
                Expanded(
                  child: _filteredTemplates.isEmpty
                      ? const Center(
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(Icons.description_outlined,
                                  size: 80, color: Colors.grey),
                              SizedBox(height: 10),
                              Text('No templates found.',
                                  style:
                                      TextStyle(color: Colors.grey, fontSize: 18)),
                            ],
                          ),
                        )
                      : ListView.builder(
                          padding: const EdgeInsets.all(16),
                          itemCount: _filteredTemplates.length,
                          itemBuilder: (context, index) {
                            final template = _filteredTemplates[index];
                            return _TemplateCard(
                              template: template,
                              onEdit: () => _showAddEditDialog(template: template),
                              onDelete: () => _deleteTemplate(template),
                            );
                          },
                        ),
                ),
              ],
            ),
    );
  }
}

class _TemplateCard extends StatelessWidget {
  final dynamic template;
  final VoidCallback onEdit;
  final VoidCallback onDelete;

  const _TemplateCard({
    required this.template,
    required this.onEdit,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    final isActive = template['isActive'] ?? true;
    final isDefault = template['isDefault'] ?? false;
    final usageCount = template['usageCount'] ?? 0;

    return Card(
      margin: const EdgeInsets.only(bottom: 16),
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Text(
                            template['name'] ?? 'Unnamed Template',
                            style: const TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          const SizedBox(width: 8),
                          if (isDefault)
                            Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 8, vertical: 4),
                              decoration: BoxDecoration(
                                color: _primaryGreen,
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: const Text(
                                'DEFAULT',
                                style: TextStyle(
                                  color: Colors.white,
                                  fontSize: 10,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                          if (!isActive)
                            Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 8, vertical: 4),
                              decoration: BoxDecoration(
                                color: Colors.grey,
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: const Text(
                                'INACTIVE',
                                style: TextStyle(
                                  color: Colors.white,
                                  fontSize: 10,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                        ],
                      ),
                      if (template['description'] != null)
                        Padding(
                          padding: const EdgeInsets.only(top: 4),
                          child: Text(
                            template['description'],
                            style: TextStyle(
                              color: Colors.grey[600],
                              fontSize: 14,
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
                PopupMenuButton<String>(
                  onSelected: (value) {
                    if (value == 'edit') onEdit();
                    if (value == 'delete') onDelete();
                  },
                  itemBuilder: (ctx) => [
                    const PopupMenuItem(
                      value: 'edit',
                      child: Row(
                        children: [
                          Icon(Icons.edit, size: 20),
                          SizedBox(width: 8),
                          Text('Edit'),
                        ],
                      ),
                    ),
                    const PopupMenuItem(
                      value: 'delete',
                      child: Row(
                        children: [
                          Icon(Icons.delete, size: 20, color: Colors.red),
                          SizedBox(width: 8),
                          Text('Delete', style: TextStyle(color: Colors.red)),
                        ],
                      ),
                    ),
                  ],
                ),
              ],
            ),
            const Divider(),
            Wrap(
              spacing: 16,
              runSpacing: 8,
              children: [
                _InfoChip(
                  icon: Icons.attach_money,
                  label:
                      'Rent: \$${template['defaultRentAmount'] ?? 0}',
                ),
                _InfoChip(
                  icon: Icons.security,
                  label:
                      'Deposit: \$${template['defaultDepositAmount'] ?? 0}',
                ),
                _InfoChip(
                  icon: Icons.calendar_today,
                  label:
                      'Duration: ${template['defaultContractDuration'] ?? 12} months',
                ),
                _InfoChip(
                  icon: Icons.payment,
                  label:
                      'Cycle: ${template['defaultPaymentCycle'] ?? 'monthly'}',
                ),
                _InfoChip(
                  icon: Icons.trending_up,
                  label: 'Used: $usageCount times',
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _InfoChip extends StatelessWidget {
  final IconData icon;
  final String label;

  const _InfoChip({required this.icon, required this.label});

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 16, color: Colors.grey[600]),
        const SizedBox(width: 4),
        Text(
          label,
          style: TextStyle(color: Colors.grey[700], fontSize: 12),
        ),
      ],
    );
  }
}

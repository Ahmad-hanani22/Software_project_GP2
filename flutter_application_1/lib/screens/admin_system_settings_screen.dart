import 'package:flutter/material.dart';
import 'package:flutter/services.dart'; // For TextInputFormatter
import 'package:flutter_application_1/services/api_service.dart'; // Make sure this path is correct
import 'package:provider/provider.dart'; // ✅ جديد: استيراد provider
import 'package:flutter_application_1/utils/app_theme_settings.dart'; // ✅ جديد: استيراد AppThemeSettings

// Reusing AppAlertType and showAppAlert from previous screens
enum AppAlertType { success, error, info }

void showAppAlert({
  required BuildContext context,
  required String title,
  required String message,
  AppAlertType type = AppAlertType.info,
}) {
  Color iconColor;
  IconData iconData;
  switch (type) {
    case AppAlertType.success:
      iconColor = Colors.green;
      iconData = Icons.check_circle_outline;
      break;
    case AppAlertType.error:
      iconColor = Colors.red;
      iconData = Icons.error_outline;
      break;
    case AppAlertType.info:
      iconColor = Colors.blue;
      iconData = Icons.info_outline;
      break;
  }

  showDialog(
    context: context,
    builder: (ctx) => Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(iconData, color: iconColor, size: 48),
            const SizedBox(height: 16),
            Text(
              title,
              style: TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: 20,
                color: iconColor,
              ),
            ),
            const SizedBox(height: 10),
            Text(
              message,
              textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 16),
            ),
            const SizedBox(height: 24),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: () => Navigator.pop(ctx),
                style: ElevatedButton.styleFrom(
                  backgroundColor: iconColor,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                child: const Text('OK'),
              ),
            ),
          ],
        ),
      ),
    ),
  );
}

const double _kMobileBreakpoint = 600.0;
// Using a primary color from Material 3 spec for better dark mode compatibility
const Color _primaryGreen = Color(0xFF2E7D32); // Deep Green
// const Color _lightGreen = Color(0xFFE8F5E9); // Not directly used in this screen's theming anymore

class AdminSystemSettingsScreen extends StatefulWidget {
  const AdminSystemSettingsScreen({super.key});

  @override
  State<AdminSystemSettingsScreen> createState() =>
      _AdminSystemSettingsScreenState();
}

class _AdminSystemSettingsScreenState extends State<AdminSystemSettingsScreen> {
  bool _isLoading = true;
  String? _errorMessage;
  List<SystemSetting> _settings = [];
  final Map<String, TextEditingController> _textControllers = {};
  final Map<String, bool> _switchValues = {};
  final Map<String, String?> _dropdownValues = {}; // For dropdown settings
  final Map<String, bool> _expansionStates = {}; // To manage ExpansionTile states

  @override
  void initState() {
    super.initState();
    _fetchSettings();
  }

  @override
  void dispose() {
    _textControllers.forEach((key, controller) => controller.dispose());
    super.dispose();
  }

  Future<void> _fetchSettings() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    final (ok, data) = await ApiService.getSystemSettings();

    if (mounted) {
      setState(() {
        _isLoading = false;
        if (ok) {
          _settings = data;
          _initializeSettingControllers();
          _initializeExpansionStates(); // Initialize expansion states
        } else {
          _errorMessage = 'Failed to load settings: $data';
          showAppAlert(
            context: context,
            title: 'Error',
            message: _errorMessage!,
            type: AppAlertType.error,
          );
        }
      });
    }
  }

  void _initializeSettingControllers() {
    _textControllers.forEach((key, controller) => controller.dispose()); // Dispose existing
    _textControllers.clear();
    _switchValues.clear();
    _dropdownValues.clear();

    for (var setting in _settings) {
      if (setting.type == 'text' || setting.type == 'number') {
        _textControllers[setting.key] = TextEditingController(text: setting.value.toString());
      } else if (setting.type == 'boolean') {
        _switchValues[setting.key] = setting.value as bool;
      } else if (setting.type == 'dropdown') {
        _dropdownValues[setting.key] = setting.value?.toString();
      }
    }
  }

  void _initializeExpansionStates() {
    _expansionStates.clear();
    final categories = _settings.map((s) => s.category).toSet();
    for (var category in categories) {
      _expansionStates[category] = true; // Default to expanded
    }
  }


  Future<void> _updateSetting(String key, dynamic newValue) async {
    final (ok, message) = await ApiService.updateSystemSetting(key, newValue);
    if (mounted) {
      if (ok) {
        setState(() {
          // Update the local setting value
          final index = _settings.indexWhere((s) => s.key == key);
          if (index != -1) {
            _settings[index].value = newValue;
          }
          // ✅ جديد: معالجة خاصة لإعداد الوضع الليلي
          if (key == 'dark_mode_enabled' && newValue is bool) {
            Provider.of<AppThemeSettings>(context, listen: false).setThemeMode(newValue);
          }
        });
        showAppAlert(
          context: context,
          title: 'Success',
          message: message,
          type: AppAlertType.success,
        );
      } else {
        showAppAlert(
          context: context,
          title: 'Error',
          message: message,
          type: AppAlertType.error,
        );
        // Revert UI change if update failed
        _fetchSettings(); // Re-fetch to ensure UI matches backend
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final screenWidth = MediaQuery.of(context).size.width;
    final isMobile = screenWidth <= _kMobileBreakpoint;
    final ColorScheme colorScheme = Theme.of(context).colorScheme;

    return Scaffold(
      appBar: AppBar(
        elevation: 4,
        backgroundColor: _primaryGreen, // Always primary green for consistency
        foregroundColor: Colors.white, // White icons/text on green AppBar
        titleSpacing: isMobile ? 0 : 12,
        title: Row(
          children: [
            Container(
              width: 38,
              height: 38,
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(.2),
                borderRadius: BorderRadius.circular(8),
              ),
              child: const Icon(Icons.settings_outlined, color: Colors.white),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                'System Settings',
                style: TextStyle(
                  fontWeight: FontWeight.w700,
                  fontSize: isMobile ? 18 : 20,
                  color: Colors.white,
                ),
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ),
        actions: [
          IconButton(
            tooltip: 'Refresh Settings',
            icon: const Icon(Icons.refresh, color: Colors.white),
            onPressed: _fetchSettings,
          ),
          if (!isMobile) const SizedBox(width: 12),
        ],
      ),
      body: _isLoading
          ? Center(child: CircularProgressIndicator(color: _primaryGreen))
          : _errorMessage != null
              ? Center(
                  child: Padding(
                    padding: const EdgeInsets.all(24.0),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          Icons.error_outline,
                          color: colorScheme.error, // Use theme error color
                          size: 60,
                        ),
                        const SizedBox(height: 16),
                        Text(
                          _errorMessage!,
                          textAlign: TextAlign.center,
                          style: TextStyle(color: colorScheme.error, fontSize: 16),
                        ),
                        const SizedBox(height: 24),
                        ElevatedButton.icon(
                          onPressed: _fetchSettings,
                          icon: const Icon(Icons.refresh),
                          label: const Text('Try Again'),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: _primaryGreen,
                            foregroundColor: Colors.white,
                          ),
                        ),
                      ],
                    ),
                  ),
                )
              : ListView(
                  padding: const EdgeInsets.all(16.0),
                  children: _buildSettingCategories(context, colorScheme),
                ),
    );
  }

  List<Widget> _buildSettingCategories(BuildContext context, ColorScheme colorScheme) {
    List<Widget> categoryWidgets = [];
    final Map<String, List<SystemSetting>> groupedSettings = {};

    // Group settings by category
    for (var setting in _settings) {
      groupedSettings.putIfAbsent(setting.category, () => []).add(setting);
    }

    // Sort categories for consistent order
    final sortedCategories = groupedSettings.keys.toList()..sort();

    for (var categoryName in sortedCategories) {
      final settingsList = groupedSettings[categoryName]!;
      categoryWidgets.add(
        Padding(
          padding: const EdgeInsets.only(bottom: 16.0),
          child: Card(
            elevation: 3,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
            color: colorScheme.surfaceVariant.withOpacity(0.3), // A subtle background for the card
            child: Theme( // Override expansion tile theme for better aesthetics
              data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
              child: ExpansionTile(
                initiallyExpanded: _expansionStates[categoryName] ?? true,
                onExpansionChanged: (isExpanded) {
                  setState(() {
                    _expansionStates[categoryName] = isExpanded;
                  });
                },
                leading: Icon(_getCategoryIcon(categoryName), color: _primaryGreen),
                title: Text(
                  categoryName,
                  style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                        fontWeight: FontWeight.bold,
                        color: _primaryGreen,
                      ),
                ),
                children: settingsList.map((s) => _buildSettingTile(context, s, colorScheme)).toList(),
              ),
            ),
          ),
        ),
      );
    }
    return categoryWidgets;
  }

  // Helper to get an icon for each category
  IconData _getCategoryIcon(String category) {
    switch (category) {
      case 'General':
        return Icons.tune;
      case 'User Management':
        return Icons.people_alt_outlined;
      case 'Property Settings':
        return Icons.home_work_outlined;
      case 'Notification Settings':
        return Icons.notifications_active_outlined;
      default:
        return Icons.category_outlined;
    }
  }


  Widget _buildSettingTile(BuildContext context, SystemSetting setting, ColorScheme colorScheme) {
    Widget controlWidget;

    // Common input decoration for consistency
    InputDecoration _commonInputDecoration(String hint) {
      return InputDecoration(
        hintText: hint,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: BorderSide(color: colorScheme.outline.withOpacity(0.5)),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: BorderSide(color: _primaryGreen, width: 2),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: BorderSide(color: colorScheme.outlineVariant),
        ),
        contentPadding: const EdgeInsets.symmetric(vertical: 12, horizontal: 12),
        isDense: true,
        floatingLabelBehavior: FloatingLabelBehavior.never, // No floating label
      );
    }

    switch (setting.type) {
      case 'text':
        controlWidget = TextFormField(
          controller: _textControllers[setting.key],
          decoration: _commonInputDecoration(setting.label),
          onFieldSubmitted: (newValue) {
            _updateSetting(setting.key, newValue);
          },
        );
        break;
      case 'number':
        controlWidget = TextFormField(
          controller: _textControllers[setting.key],
          keyboardType: TextInputType.number,
          inputFormatters: [FilteringTextInputFormatter.digitsOnly],
          decoration: _commonInputDecoration(setting.label),
          onFieldSubmitted: (newValue) {
            _updateSetting(setting.key, int.tryParse(newValue) ?? setting.value);
          },
        );
        break;
      case 'boolean':
        controlWidget = Switch.adaptive( // Adaptive switch for platform-specific look
          value: _switchValues[setting.key] ?? false,
          onChanged: (newValue) {
            setState(() {
              _switchValues[setting.key] = newValue;
            });
            _updateSetting(setting.key, newValue);
          },
          activeColor: _primaryGreen,
          // inactiveThumbColor: colorScheme.outline,
          // inactiveTrackColor: colorScheme.surfaceVariant,
        );
        break;
      case 'dropdown':
        controlWidget = DropdownButtonFormField<String>(
          value: _dropdownValues[setting.key],
          decoration: _commonInputDecoration(setting.label),
          items: setting.options
                  ?.map((option) => DropdownMenuItem(
                        value: option,
                        child: Text(option, style: TextStyle(color: colorScheme.onSurface)),
                      ))
                  .toList() ??
              [],
          onChanged: (newValue) {
            if (newValue != null) {
              setState(() {
                _dropdownValues[setting.key] = newValue;
              });
              _updateSetting(setting.key, newValue);
            }
          },
          dropdownColor: colorScheme.surface, // Background for dropdown items
          style: TextStyle(color: colorScheme.onSurface), // Text style for selected item
        );
        break;
      default:
        controlWidget = Text('Unsupported setting type: ${setting.type}', style: TextStyle(color: colorScheme.error));
    }

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Expanded(
            flex: 2,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  setting.label,
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    color: colorScheme.onSurface,
                  ),
                ),
                if (setting.description != null && setting.description!.isNotEmpty)
                  Padding(
                    padding: const EdgeInsets.only(top: 4.0),
                    child: Text(
                      setting.description!,
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ),
              ],
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            flex: 3,
            child: Align(
              alignment: Alignment.centerRight,
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 200), // Slightly reduce width for controls
                child: controlWidget,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
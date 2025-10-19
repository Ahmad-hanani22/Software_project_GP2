import 'package:flutter/material.dart';
import 'package:flutter/services.dart'; // For TextInputFormatter
import 'package:flutter_application_1/services/api_service.dart'; // Make sure this path is correct
import 'package:provider/provider.dart'; // ✅ Provider import
import 'package:flutter_application_1/utils/app_theme_settings.dart'; // ✅ AppThemeSettings import

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
// --- UPDATED COLOR PALETTE (matching LoginScreen's green) ---
const Color _primaryGreen =
    Color(0xFF2E7D32); // The exact green from LoginScreen
const Color _lightGreenAccent =
    Color(0xFFE8F5E9); // A very light tint of green for accents
const Color _darkGreenAccent = Color(0xFF1B5E20); // A darker shade of green
const Color _scaffoldBackground = Color(0xFFFAFAFA); // Grey 50
const Color _cardBackground = Colors.white;
const Color _textPrimary = Color(0xFF424242); // Grey 800
const Color _textSecondary = Color(0xFF757575); // Grey 600
const Color _borderColor = Color(0xFFE0E0E0); // Grey 300

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
  final Map<String, bool> _expansionStates =
      {}; // To manage ExpansionTile states

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
    _textControllers
        .forEach((key, controller) => controller.dispose()); // Dispose existing
    _textControllers.clear();
    _switchValues.clear();
    _dropdownValues.clear();

    for (var setting in _settings) {
      if (setting.type == 'text' || setting.type == 'number') {
        _textControllers[setting.key] =
            TextEditingController(text: setting.value.toString());
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
          // ✅ Handle dark mode setting specifically
          if (key == 'dark_mode_enabled' && newValue is bool) {
            Provider.of<AppThemeSettings>(context, listen: false)
                .setThemeMode(newValue);
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
      backgroundColor: _scaffoldBackground, // Consistent background color
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
                          color:
                              Colors.red.shade700, // Use a strong red for error
                          size: 60,
                        ),
                        const SizedBox(height: 16),
                        Text(
                          _errorMessage!,
                          textAlign: TextAlign.center,
                          style: TextStyle(
                              color: Colors.red.shade700, fontSize: 16),
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
                  children: _buildSettingCategories(context), // Simplified call
                ),
    );
  }

  List<Widget> _buildSettingCategories(BuildContext context) {
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
            shape:
                RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
            color: _cardBackground, // White card background
            child: Theme(
              // Override expansion tile theme for better aesthetics
              data: Theme.of(context).copyWith(
                dividerColor:
                    Colors.transparent, // No divider inside ExpansionTile
                splashColor: _primaryGreen.withOpacity(0.1), // Green splash
                highlightColor:
                    _primaryGreen.withOpacity(0.05), // Green highlight
              ),
              child: ExpansionTile(
                initiallyExpanded: _expansionStates[categoryName] ?? true,
                onExpansionChanged: (isExpanded) {
                  setState(() {
                    _expansionStates[categoryName] = isExpanded;
                  });
                },
                leading: Icon(_getCategoryIcon(categoryName),
                    color: _darkGreenAccent), // Darker green icon
                title: Text(
                  categoryName,
                  style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                        fontWeight: FontWeight.bold,
                        color:
                            _textPrimary, // Primary text color for category title
                      ),
                ),
                children: settingsList
                    .map((s) => _buildSettingTile(context, s))
                    .toList(), // Simplified call
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
        return Icons.tune_rounded;
      case 'User Management':
        return Icons.people_alt_rounded;
      case 'Property Settings':
        return Icons.home_work_rounded;
      case 'Notification Settings':
        return Icons.notifications_active_rounded;
      case 'Security': // Example new category
        return Icons.security_rounded;
      default:
        return Icons.category_rounded;
    }
  }

  Widget _buildSettingTile(BuildContext context, SystemSetting setting) {
    Widget controlWidget;

    // Common input decoration for consistency
    InputDecoration _commonInputDecoration(String hint) {
      return InputDecoration(
        hintText: hint,
        hintStyle: TextStyle(color: _textSecondary.withOpacity(0.7)),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10), // More rounded borders
          borderSide: BorderSide(color: _borderColor),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: const BorderSide(
              color: _primaryGreen, width: 2), // Primary green focus
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: BorderSide(color: _borderColor),
        ),
        contentPadding: const EdgeInsets.symmetric(
            vertical: 14, horizontal: 16), // More padding
        isDense: true,
        filled: true,
        fillColor: _scaffoldBackground, // Light background for input fields
        floatingLabelBehavior: FloatingLabelBehavior.never,
      );
    }

    switch (setting.type) {
      case 'text':
        controlWidget = TextFormField(
          controller: _textControllers[setting.key],
          style: TextStyle(color: _textPrimary),
          decoration: _commonInputDecoration(setting.label),
          onFieldSubmitted: (newValue) {
            _updateSetting(setting.key, newValue);
          },
        );
        break;
      case 'number':
        controlWidget = TextFormField(
          controller: _textControllers[setting.key],
          style: TextStyle(color: _textPrimary),
          keyboardType: TextInputType.number,
          inputFormatters: [FilteringTextInputFormatter.digitsOnly],
          decoration: _commonInputDecoration(setting.label),
          onFieldSubmitted: (newValue) {
            _updateSetting(
                setting.key, int.tryParse(newValue) ?? setting.value);
          },
        );
        break;
      case 'boolean':
        controlWidget = Switch.adaptive(
          // Adaptive switch for platform-specific look
          value: _switchValues[setting.key] ?? false,
          onChanged: (newValue) {
            setState(() {
              _switchValues[setting.key] = newValue;
            });
            _updateSetting(setting.key, newValue);
          },
          activeColor: _primaryGreen, // Primary green for active state
          inactiveThumbColor:
              _textSecondary.withOpacity(0.5), // Grey for inactive thumb
          inactiveTrackColor: _borderColor, // Light grey for inactive track
        );
        break;
      case 'dropdown':
        controlWidget = DropdownButtonFormField<String>(
          value: _dropdownValues[setting.key],
          decoration: _commonInputDecoration(setting.label),
          items: setting.options
                  ?.map((option) => DropdownMenuItem(
                        value: option,
                        child: Text(option,
                            style:
                                TextStyle(color: _textPrimary)), // Text color
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
          dropdownColor: _cardBackground, // White background for dropdown items
          style: TextStyle(color: _textPrimary), // Text style for selected item
          icon: Icon(Icons.arrow_drop_down_rounded,
              color: _primaryGreen), // Green dropdown icon
        );
        break;
      default:
        controlWidget = Text(
          'Unsupported setting type: ${setting.type}',
          style: TextStyle(color: Colors.red.shade700),
        );
    }

    return Padding(
      padding: const EdgeInsets.symmetric(
          horizontal: 16.0, vertical: 10.0), // Adjusted padding
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
                        color: _textPrimary, // Primary text color
                        fontWeight: FontWeight.w600,
                      ),
                ),
                if (setting.description != null &&
                    setting.description!.isNotEmpty)
                  Padding(
                    padding: const EdgeInsets.only(top: 4.0),
                    child: Text(
                      setting.description!,
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                            color:
                                _textSecondary, // Secondary text color for description
                          ),
                    ),
                  ),
              ],
            ),
          ),
          const SizedBox(width: 20), // Increased spacing
          Expanded(
            flex: 3,
            child: Align(
              alignment: Alignment.centerRight,
              child: ConstrainedBox(
                constraints: const BoxConstraints(
                    maxWidth: 250), // Increased max width for controls
                child: controlWidget,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

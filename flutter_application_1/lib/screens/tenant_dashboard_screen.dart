import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

// --- 🌿 Dashboard Theme Matching Home ---
class DashboardTheme {
  static const Color primary = Color(0xFF00695C);
  // التموج اللوني المتناسق مع الصفحة الرئيسية
  static const LinearGradient headerGradient = LinearGradient(
    colors: [Color(0xFF004D40), Color(0xFF00695C), Color(0xFF4DB6AC)],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );
}

// --- 🖥️ MAIN DASHBOARD SCREEN ---
class TenantDashboardScreen extends StatefulWidget {
  const TenantDashboardScreen({super.key});

  @override
  State<TenantDashboardScreen> createState() => _TenantDashboardScreenState();
}

class _TenantDashboardScreenState extends State<TenantDashboardScreen> {
  String _userName = "Tenant";

  @override
  void initState() {
    super.initState();
    _loadUser();
  }

  Future<void> _loadUser() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      _userName = prefs.getString('userName') ?? "Tenant";
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF5F7FA),
      body: SingleChildScrollView(
        child: Column(
          children: [
            // 1. Header Section
            Container(
              padding: const EdgeInsets.fromLTRB(24, 60, 24, 30),
              decoration: const BoxDecoration(
                gradient: DashboardTheme.headerGradient,
                borderRadius:
                    BorderRadius.vertical(bottom: Radius.circular(30)),
              ),
              child: Column(
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text("Welcome back,",
                              style: TextStyle(
                                  color: Colors.white70, fontSize: 16)),
                          Text(_userName,
                              style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 24,
                                  fontWeight: FontWeight.bold)),
                        ],
                      ),
                      const CircleAvatar(
                          radius: 25,
                          backgroundColor: Colors.white,
                          child: Icon(Icons.person,
                              color: DashboardTheme.primary)),
                    ],
                  ),
                  const SizedBox(height: 20),
                  // Stats Card
                  Container(
                    padding: const EdgeInsets.all(15),
                    decoration: BoxDecoration(
                        color: Colors.white.withOpacity(0.15),
                        borderRadius: BorderRadius.circular(15)),
                    child: const Row(
                      mainAxisAlignment: MainAxisAlignment.spaceAround,
                      children: [
                        _StatItem("Active", "Contracts"),
                        _StatItem("Pending", "Requests"),
                        _StatItem("Due", "Payments"),
                      ],
                    ),
                  )
                ],
              ),
            ),

            const SizedBox(height: 25),

            // 2. Services Grid (أزرار الخدمات)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text("Quick Services",
                      style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: Colors.black87)),
                  const SizedBox(height: 15),
                  GridView.count(
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    crossAxisCount: 2,
                    crossAxisSpacing: 15,
                    mainAxisSpacing: 15,
                    childAspectRatio: 1.3,
                    children: [
                      _ServiceCard(
                        icon: Icons.support_agent,
                        title: "Contact Us",
                        color: Colors.orange,
                        onTap: () => Navigator.push(
                            context,
                            MaterialPageRoute(
                                builder: (_) => const ContactUsScreen())),
                      ),
                      _ServiceCard(
                        icon: Icons.help_outline,
                        title: "Help & FAQ",
                        color: Colors.blue,
                        onTap: () => Navigator.push(
                            context,
                            MaterialPageRoute(
                                builder: (_) => const HelpSupportScreen())),
                      ),
                      _ServiceCard(
                        icon: Icons.mosque,
                        title: "Find Mosque",
                        color: Colors.green,
                        onTap: () {
                          ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(
                                  content: Text("Opening Mosque Locator...")));
                        },
                      ),
                      _ServiceCard(
                        icon: Icons.tour,
                        title: "Tourism",
                        color: Colors.purple,
                        onTap: () {
                          ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(
                                  content:
                                      Text("Discovering Tourist Spots...")));
                        },
                      ),
                    ],
                  ),
                ],
              ),
            ),

            const SizedBox(height: 30),

            // 3. Recent Activity List
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text("Recent Activity",
                      style:
                          TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 10),
                  ListView.builder(
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    itemCount: 2,
                    itemBuilder: (context, index) {
                      return Card(
                        margin: const EdgeInsets.only(bottom: 10),
                        elevation: 2,
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12)),
                        child: ListTile(
                          leading: Container(
                            padding: const EdgeInsets.all(8),
                            decoration: BoxDecoration(
                                color: DashboardTheme.primary.withOpacity(0.1),
                                shape: BoxShape.circle),
                            child: const Icon(Icons.history,
                                color: DashboardTheme.primary),
                          ),
                          title: const Text("Rent Paid",
                              style: TextStyle(fontWeight: FontWeight.bold)),
                          subtitle: const Text("Last Week • Apartment #101"),
                          trailing: const Text("-\$800",
                              style: TextStyle(
                                  color: Colors.red,
                                  fontWeight: FontWeight.bold)),
                        ),
                      );
                    },
                  )
                ],
              ),
            ),
            const SizedBox(height: 40),
          ],
        ),
      ),
    );
  }
}

class _StatItem extends StatelessWidget {
  final String label;
  final String sub;
  const _StatItem(this.label, this.sub);
  @override
  Widget build(BuildContext context) {
    return Column(children: [
      Text("0",
          style: const TextStyle(
              color: Colors.white, fontSize: 20, fontWeight: FontWeight.bold)),
      Text("$label $sub",
          style: const TextStyle(color: Colors.white70, fontSize: 10)),
    ]);
  }
}

class _ServiceCard extends StatelessWidget {
  final IconData icon;
  final String title;
  final Color color;
  final VoidCallback onTap;
  const _ServiceCard(
      {required this.icon,
      required this.title,
      required this.color,
      required this.onTap});
  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(20),
          boxShadow: [
            BoxShadow(
                color: Colors.black.withOpacity(0.05),
                blurRadius: 10,
                offset: const Offset(0, 5))
          ],
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                  color: color.withOpacity(0.1), shape: BoxShape.circle),
              child: Icon(icon, size: 30, color: color),
            ),
            const SizedBox(height: 10),
            Text(title,
                style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 15,
                    color: Colors.black87)),
          ],
        ),
      ),
    );
  }
}

// --- 📞 1. CONTACT US SCREEN ---
class ContactUsScreen extends StatelessWidget {
  const ContactUsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF5F7FA),
      appBar: AppBar(
        title: const Text("Contact Support",
            style: TextStyle(color: Colors.white)),
        backgroundColor: DashboardTheme.primary,
        iconTheme: const IconThemeData(color: Colors.white),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          children: [
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(15),
                  boxShadow: [
                    BoxShadow(
                        color: Colors.black.withOpacity(0.05), blurRadius: 10)
                  ]),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text("Send us a message",
                      style: TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                          color: DashboardTheme.primary)),
                  const SizedBox(height: 20),
                  _buildField("Subject", Icons.title),
                  const SizedBox(height: 15),
                  _buildField("Message", Icons.message, maxLines: 5),
                  const SizedBox(height: 20),
                  SizedBox(
                    width: double.infinity,
                    height: 50,
                    child: ElevatedButton.icon(
                      onPressed: () {
                        ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(content: Text("Message Sent!")));
                        Navigator.pop(context);
                      },
                      style: ElevatedButton.styleFrom(
                          backgroundColor: DashboardTheme.primary,
                          foregroundColor: Colors.white),
                      icon: const Icon(Icons.send),
                      label: const Text("Submit"),
                    ),
                  )
                ],
              ),
            ),
            const SizedBox(height: 20),
            _infoTile(Icons.phone, "+970 599 000 000"),
            _infoTile(Icons.email, "support@shaqati.com"),
          ],
        ),
      ),
    );
  }

  Widget _buildField(String label, IconData icon, {int maxLines = 1}) {
    return TextField(
      maxLines: maxLines,
      decoration: InputDecoration(
        labelText: label,
        prefixIcon: Icon(icon, color: DashboardTheme.primary),
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
        filled: true,
        fillColor: Colors.grey[50],
      ),
    );
  }

  Widget _infoTile(IconData icon, String txt) => Card(
      child: ListTile(
          leading: Icon(icon, color: DashboardTheme.primary),
          title:
              Text(txt, style: const TextStyle(fontWeight: FontWeight.bold))));
}

// --- ❓ 2. HELP & FAQ SCREEN ---
class HelpSupportScreen extends StatelessWidget {
  const HelpSupportScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
          title:
              const Text("Help & FAQ", style: TextStyle(color: Colors.white)),
          backgroundColor: DashboardTheme.primary,
          iconTheme: const IconThemeData(color: Colors.white)),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          const Text("Common Questions",
              style: TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.bold,
                  color: DashboardTheme.primary)),
          const SizedBox(height: 15),
          _faqItem("How to pay rent?",
              "You can pay via credit card or cash at our offices."),
          _faqItem("Can I visit property?",
              "Yes, click 'Book Tour' on any property page."),
          _faqItem("Refund Policy?",
              "Refunds depend on the landlord's contract terms."),
        ],
      ),
    );
  }

  Widget _faqItem(String q, String a) {
    return Card(
      margin: const EdgeInsets.only(bottom: 10),
      elevation: 0,
      shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
          side: BorderSide(color: Colors.grey.shade200)),
      child: ExpansionTile(
        title: Text(q, style: const TextStyle(fontWeight: FontWeight.bold)),
        children: [Padding(padding: const EdgeInsets.all(16), child: Text(a))],
      ),
    );
  }
}

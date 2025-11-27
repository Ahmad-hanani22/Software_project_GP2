import 'package:flutter/material.dart';

class LifestyleScreen extends StatelessWidget {
  const LifestyleScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final List<Map<String, dynamic>> services = [
      {
        "title": "Luxury Jacuzzi",
        "image":
            "https://images.unsplash.com/photo-1584622650111-993a426fbf0a?ixlib=rb-1.2.1&auto=format&fit=crop&w=500&q=60",
        "price": "\$50/day",
        "desc": "Add a portable jacuzzi to your rental."
      },
      {
        "title": "City Tour Guide",
        "image":
            "https://images.unsplash.com/photo-1476514525535-07fb3b4ae5f1?ixlib=rb-1.2.1&auto=format&fit=crop&w=500&q=60",
        "price": "\$30/hr",
        "desc": "Explore the city with a local expert."
      },
      {
        "title": "Hiking Trip",
        "image":
            "https://images.unsplash.com/photo-1551632811-561732d1e306?ixlib=rb-1.2.1&auto=format&fit=crop&w=500&q=60",
        "price": "\$20/person",
        "desc": "Group hiking to mountains and valleys."
      },
      {
        "title": "House Cleaning",
        "image":
            "https://images.unsplash.com/photo-1581578731117-10d52143b0e8?ixlib=rb-1.2.1&auto=format&fit=crop&w=500&q=60",
        "price": "\$40/visit",
        "desc": "Professional deep cleaning service."
      },
      {
        "title": "Car Rental",
        "image":
            "https://images.unsplash.com/photo-1549317661-bd32c8ce0db2?ixlib=rb-1.2.1&auto=format&fit=crop&w=500&q=60",
        "price": "\$45/day",
        "desc": "Rent a luxury car for your stay."
      },
      {
        "title": "Event Booking",
        "image":
            "https://images.unsplash.com/photo-1511795409834-ef04bbd61622?ixlib=rb-1.2.1&auto=format&fit=crop&w=500&q=60",
        "price": "Custom",
        "desc": "Tickets to local concerts and events."
      },
    ];

    return Scaffold(
      appBar: AppBar(
        title: const Text("Lifestyle & Services"),
        backgroundColor: Colors.purple[700],
        foregroundColor: Colors.white,
      ),
      body: Padding(
        padding: const EdgeInsets.all(12.0),
        child: GridView.builder(
          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: 2,
            childAspectRatio: 0.75, // بطاقات طويلة
            crossAxisSpacing: 12,
            mainAxisSpacing: 12,
          ),
          itemCount: services.length,
          itemBuilder: (context, index) {
            final service = services[index];
            return Card(
              elevation: 4,
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16)),
              clipBehavior: Clip.hardEdge,
              child: InkWell(
                onTap: () {
                  ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                      content: Text(
                          "Booking request sent for ${service['title']}")));
                },
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      flex: 3,
                      child: Image.network(service['image'],
                          fit: BoxFit.cover, width: double.infinity),
                    ),
                    Expanded(
                      flex: 2,
                      child: Padding(
                        padding: const EdgeInsets.all(10.0),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          mainAxisAlignment: MainAxisAlignment.spaceAround,
                          children: [
                            Text(service['title'],
                                style: const TextStyle(
                                    fontWeight: FontWeight.bold, fontSize: 16)),
                            Text(service['desc'],
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                                style: TextStyle(
                                    fontSize: 12, color: Colors.grey[600])),
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Text(service['price'],
                                    style: TextStyle(
                                        color: Colors.purple[700],
                                        fontWeight: FontWeight.bold)),
                                const Icon(Icons.add_circle,
                                    color: Colors.purple),
                              ],
                            )
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            );
          },
        ),
      ),
    );
  }
}

import 'package:flutter/material.dart';
import '../models/service.dart';
import 'booking_screen.dart';

class ServiceDetailScreen extends StatelessWidget {
  final ServiceItem service;

  const ServiceDetailScreen({super.key, required this.service});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(service.name)),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              service.name,
              style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 4),
            Text(service.category, style: const TextStyle(color: Colors.grey)),
            const SizedBox(height: 16),
            Text(service.description),
            const SizedBox(height: 16),
            Text(
              '₹${service.price.toStringAsFixed(0)}',
              style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
            ),
            const Spacer(),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: () {
                  Navigator.of(context).push(
                    MaterialPageRoute(
                      builder: (_) => BookingScreen(service: service),
                    ),
                  );
                },
                child: const Text('Book This Service'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

import 'package:flutter/material.dart';

class ApartmentCard extends StatelessWidget {
  final Map<String, dynamic> apartment;
  final VoidCallback onEdit;
  final VoidCallback onDelete;

  const ApartmentCard({
    required this.apartment,
    required this.onEdit,
    required this.onDelete,
    super.key, // Added Key for best practice
  });

  @override
  Widget build(BuildContext context) {
    // Check if tenant_id is NOT null to determine occupation status
    bool occupied = apartment['tenant_id'] != null;

    return Card(
      margin: EdgeInsets.symmetric(vertical: 8, horizontal: 16),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      elevation: 3,
      child: Padding(
        padding: EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Apartment Name
            Text(
              apartment['name'] ?? 'N/A', // Null safety added
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            SizedBox(height: 6),

            // Details (Beds, Baths, Location)
            Text(
              "${apartment['bedrooms'] ?? 0} beds • ${apartment['bathrooms'] ?? 0} baths • ${apartment['location'] ?? 'Unknown'}",
            ),
            SizedBox(height: 6),

            // Rent and Status Row
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                // Rent
                Text(
                  "Rent: ${apartment['rent'] ?? 0} ETB",
                  style: TextStyle(fontWeight: FontWeight.w500),
                ),
                // Status (Occupied/Available)
                Text(
                  occupied ? "Occupied" : "Available",
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    color: occupied ? Colors.red : Colors.green,
                  ),
                ),
              ],
            ),
            SizedBox(height: 8),

            // Action Buttons Row (Edit & Delete)
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                // Edit Button
                IconButton(
                  onPressed: onEdit,
                  icon: Icon(Icons.edit, color: Colors.blue),
                ),
                // Delete Button
                IconButton(
                  onPressed: onDelete,
                  icon: Icon(Icons.delete, color: Colors.red),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
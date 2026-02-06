
class Booking {
  final int id;
  final DateTime startDate;
  final DateTime endDate;
  final String status;
  final double totalPrice;
  final int renterId;
  final int propertyId;
  final String? propertyTitle;
  final String? propertyImage;
  final String? renterName;

  Booking({
    required this.id,
    required this.startDate,
    required this.endDate,
    required this.status,
    required this.totalPrice,
    required this.renterId,
    required this.propertyId,
    this.propertyTitle,
    this.propertyImage,
    this.renterName,
  });

  factory Booking.fromJson(Map<String, dynamic> json) {
    return Booking(
      id: json['id'],
      startDate: DateTime.parse(json['startDate']),
      endDate: DateTime.parse(json['endDate']),
      status: json['status'],
      totalPrice: json['totalPrice'].toDouble(),
      renterId: json['renterId'],
      propertyId: json['propertyId'],
      propertyTitle: json['property']?['title'],
      propertyImage: (json['property']?['images'] as List?)?.first,
      renterName: json['renter']?['name'],
    );
  }
}

class NotificationModel {
  final int id;
  final String content;
  final String type;
  final bool isRead;
  final DateTime createdAt;

  NotificationModel({
    required this.id,
    required this.content,
    required this.type,
    required this.isRead,
    required this.createdAt,
  });

  factory NotificationModel.fromJson(Map<String, dynamic> json) {
    return NotificationModel(
      id: json['id'],
      content: json['content'],
      type: json['type'],
      isRead: json['isRead'],
      createdAt: DateTime.parse(json['createdAt']),
    );
  }
}

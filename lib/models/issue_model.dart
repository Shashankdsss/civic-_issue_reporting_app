class IssueModel {
  final String? id;
  final String category;
  final String? description;
  final double latitude;
  final double longitude;
  final String imagePath;
  final String timestamp;
  final String status;
  final String department;
  final String priority;
  final int feedbackRating;
  final String feedbackMessage;
  final int upvotes;
  final int hasUpvoted;

  IssueModel({
    this.id,
    required this.category,
    this.description,
    required this.latitude,
    required this.longitude,
    required this.imagePath,
    required this.timestamp,
    this.status = 'Pending',
    this.department = '',
    this.priority = 'Low',
    this.feedbackRating = 0,
    this.feedbackMessage = '',
    this.upvotes = 0,
    this.hasUpvoted = 0,
  });

  // Convert an IssueModel into a Map for the database.
  Map<String, dynamic> toMap() {
    return {
      if (id != null) 'id': id,
      'category': category,
      'description': description,
      'latitude': latitude,
      'longitude': longitude,
      'imagePath': imagePath,
      'timestamp': timestamp,
      'status': status,
      'department': department,
      'priority': priority,
      'feedbackRating': feedbackRating,
      'feedbackMessage': feedbackMessage,
      'upvotes': upvotes,
      'hasUpvoted': hasUpvoted,
    };
  }

  // A factory constructor to create an IssueModel from a Default map
  factory IssueModel.fromMap(Map<String, dynamic> map, {String? documentId}) {
    return IssueModel(
      id: documentId ?? map['id'],
      category: map['category'] ?? '',
      description: map['description'],
      latitude: map['latitude'] ?? 0.0,
      longitude: map['longitude'] ?? 0.0,
      imagePath: map['imagePath'] ?? '',
      timestamp: map['timestamp'] ?? '',
      status: map['status'] ?? 'Pending',
      department: map['department'] ?? '',
      priority: map['priority'] ?? 'Low',
      feedbackRating: map['feedbackRating'] ?? 0,
      feedbackMessage: map['feedbackMessage'] ?? '',
      upvotes: map['upvotes'] ?? 0,
      hasUpvoted: map['hasUpvoted'] ?? 0,
    );
  }
}

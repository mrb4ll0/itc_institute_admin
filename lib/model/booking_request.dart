class BookingRequest {
  final String id;
  final String accommodationId;
  final String studentId;
  final DateTime moveInDate;
  final int durationMonths;
  final String notes;
  final String status; // e.g. pending, approved, rejected

  BookingRequest({
    required this.id,
    required this.accommodationId,
    required this.studentId,
    required this.moveInDate,
    required this.durationMonths,
    required this.notes,
    required this.status,
  });
}

class SeatEntry {
  final int? id;
  final String phone;
  final String trainNumber;
  final String trainDate;
  final String departureTime;
  final String currentBogie;
  final String currentSeat;
  final String desiredBogie;
  final String desiredSeat;
  final String? createdAt;

  SeatEntry({
    this.id,
    required this.phone,
    required this.trainNumber,
    required this.trainDate,
    required this.departureTime,
    required this.currentBogie,
    required this.currentSeat,
    required this.desiredBogie,
    required this.desiredSeat,
    this.createdAt,
  });

  Map<String, dynamic> toJson() {
    return {
      'phone': phone,
      'train_number': trainNumber,
      'train_date': trainDate,
      'departure_time': departureTime,
      'current_bogie': currentBogie,
      'current_seat': currentSeat,
      'desired_bogie': desiredBogie,
      'desired_seat': desiredSeat,
    };
  }

  factory SeatEntry.fromJson(Map<String, dynamic> json) {
    return SeatEntry(
      id: json['id'],
      phone: json['phone'],
      trainNumber: json['train_number'],
      trainDate: json['train_date'],
      departureTime: json['departure_time'],
      currentBogie: json['current_bogie'],
      currentSeat: json['current_seat'],
      desiredBogie: json['desired_bogie'],
      desiredSeat: json['desired_seat'],
      createdAt: json['created_at'],
    );
  }
}

class Studio {
  final String id;
  final String name;
  final String? address;

  const Studio({required this.id, required this.name, this.address});

  factory Studio.fromJson(Map<String, dynamic> json) => Studio(
        id: json['id'] as String,
        name: json['name'] as String,
        address: json['address'] as String?,
      );

  @override
  bool operator ==(Object other) => other is Studio && other.id == id;

  @override
  int get hashCode => id.hashCode;
}

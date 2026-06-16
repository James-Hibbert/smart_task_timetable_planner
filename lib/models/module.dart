class Module {
  final int? id;
  final String name;
  final String code;

  Module({
    this.id,
    required this.name,
    required this.code,
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'name': name,
      'code': code,
    };
  }

  factory Module.fromMap(Map<String, dynamic> map) {
    return Module(
      id: map['id'],
      name: map['name'],
      code: map['code'],
    );
  }

  @override
  String toString() {
    return '$name ($code)';
  }
}
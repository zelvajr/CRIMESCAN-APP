class CaseModel {
  final String id;
  final String caseNumber;
  final String firNumber;
  final String officerName;
  final String agency;
  final String location;
  final String sceneType;
  final String notes;
  final double? latitude;
  final double? longitude;
  final DateTime createdAt;
  final bool isActive;

  CaseModel({
    required this.id,
    required this.caseNumber,
    required this.firNumber,
    required this.officerName,
    required this.agency,
    required this.location,
    required this.sceneType,
    required this.notes,
    this.latitude,
    this.longitude,
    required this.createdAt,
    this.isActive = true,
  });

  Map<String, dynamic> toMap() => {
    'id':           id,
    'case_number':  caseNumber,
    'fir_number':   firNumber,
    'officer_name': officerName,
    'agency':       agency,
    'location':     location,
    'scene_type':   sceneType,
    'notes':        notes,
    'latitude':     latitude,
    'longitude':    longitude,
    'created_at':   createdAt.toIso8601String(),
    'is_active':    isActive ? 1 : 0,
  };

  factory CaseModel.fromMap(Map<String, dynamic> m) => CaseModel(
    id:           m['id'],
    caseNumber:   m['case_number'],
    firNumber:    m['fir_number'],
    officerName:  m['officer_name'],
    agency:       m['agency'],
    location:     m['location'],
    sceneType:    m['scene_type'],
    notes:        m['notes'] ?? '',
    latitude:     m['latitude'],
    longitude:    m['longitude'],
    createdAt:    DateTime.parse(m['created_at']),
    isActive:     m['is_active'] == 1,
  );
}
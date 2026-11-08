class EvidenceModel {
  final String id;
  final String caseId;
  final String evidenceNumber; // E-001
  final String category;
  final String? photoPath;
  final String? videoPath;
  final String? voiceNotePath;
  final String? notes;
  final double? latitude;
  final double? longitude;
  final String sha256Hash;
  final String collectedBy;
  final DateTime timestamp;
  final bool synced;

  EvidenceModel({
    required this.id,
    required this.caseId,
    required this.evidenceNumber,
    required this.category,
    this.photoPath,
    this.videoPath,
    this.voiceNotePath,
    this.notes,
    this.latitude,
    this.longitude,
    required this.sha256Hash,
    required this.collectedBy,
    required this.timestamp,
    this.synced = false,
  });

  Map<String, dynamic> toMap() => {
    'id':               id,
    'case_id':          caseId,
    'evidence_number':  evidenceNumber,
    'category':         category,
    'photo_path':       photoPath,
    'video_path':       videoPath,
    'voice_note_path':  voiceNotePath,
    'notes':            notes,
    'latitude':         latitude,
    'longitude':        longitude,
    'sha256_hash':      sha256Hash,
    'collected_by':     collectedBy,
    'timestamp':        timestamp.toIso8601String(),
    'synced':           synced ? 1 : 0,
  };

  factory EvidenceModel.fromMap(Map<String, dynamic> m) => EvidenceModel(
    id:              m['id'],
    caseId:          m['case_id'],
    evidenceNumber:  m['evidence_number'],
    category:        m['category'],
    photoPath:       m['photo_path'],
    videoPath:       m['video_path'],
    voiceNotePath:   m['voice_note_path'],
    notes:           m['notes'],
    latitude:        m['latitude'],
    longitude:       m['longitude'],
    sha256Hash:      m['sha256_hash'],
    collectedBy:     m['collected_by'],
    timestamp:       DateTime.parse(m['timestamp']),
    synced:          m['synced'] == 1,
  );

  EvidenceModel copyWith({bool? synced}) => EvidenceModel(
    id:              id,
    caseId:          caseId,
    evidenceNumber:  evidenceNumber,
    category:        category,
    photoPath:       photoPath,
    videoPath:       videoPath,
    voiceNotePath:   voiceNotePath,
    notes:           notes,
    latitude:        latitude,
    longitude:       longitude,
    sha256Hash:      sha256Hash,
    collectedBy:     collectedBy,
    timestamp:       timestamp,
    synced:          synced ?? this.synced,
  );
}
/// Model representing a hospital/clinic medical treatment record with attached prescription
class MedicalTreatmentRecord {
  final String id;
  final String? studentId;
  final String rollNo;
  final String studentName;
  final String hostelId;
  final DateTime treatmentDate;
  final String hospitalName;
  final String doctorName;
  final String diagnosis;
  final String medicinesPrescribed;
  final String notes;
  final DateTime? followUpDate;
  final double cost;
  final String? prescriptionUrl;
  final String? prescriptionBase64;
  final DateTime createdAt;

  const MedicalTreatmentRecord({
    required this.id,
    this.studentId,
    required this.rollNo,
    required this.studentName,
    this.hostelId = 'boys_hostel',
    required this.treatmentDate,
    this.hospitalName = '',
    this.doctorName = '',
    required this.diagnosis,
    this.medicinesPrescribed = '',
    this.notes = '',
    this.followUpDate,
    this.cost = 0.0,
    this.prescriptionUrl,
    this.prescriptionBase64,
    required this.createdAt,
  });

  MedicalTreatmentRecord copyWith({
    String? id,
    String? studentId,
    String? rollNo,
    String? studentName,
    String? hostelId,
    DateTime? treatmentDate,
    String? hospitalName,
    String? doctorName,
    String? diagnosis,
    String? medicinesPrescribed,
    String? notes,
    DateTime? followUpDate,
    double? cost,
    String? prescriptionUrl,
    String? prescriptionBase64,
    DateTime? createdAt,
  }) {
    return MedicalTreatmentRecord(
      id: id ?? this.id,
      studentId: studentId ?? this.studentId,
      rollNo: rollNo ?? this.rollNo,
      studentName: studentName ?? this.studentName,
      hostelId: hostelId ?? this.hostelId,
      treatmentDate: treatmentDate ?? this.treatmentDate,
      hospitalName: hospitalName ?? this.hospitalName,
      doctorName: doctorName ?? this.doctorName,
      diagnosis: diagnosis ?? this.diagnosis,
      medicinesPrescribed: medicinesPrescribed ?? this.medicinesPrescribed,
      notes: notes ?? this.notes,
      followUpDate: followUpDate ?? this.followUpDate,
      cost: cost ?? this.cost,
      prescriptionUrl: prescriptionUrl ?? this.prescriptionUrl,
      prescriptionBase64: prescriptionBase64 ?? this.prescriptionBase64,
      createdAt: createdAt ?? this.createdAt,
    );
  }

  factory MedicalTreatmentRecord.fromJson(Map<String, dynamic> json) {
    DateTime? parsedTreatmentDate;
    final tdStr = json['treatmentDate'] ?? json['treatment_date'];
    if (tdStr != null) {
      parsedTreatmentDate = DateTime.tryParse(tdStr.toString());
    }

    DateTime? parsedFollowUp;
    final fuStr = json['followUpDate'] ?? json['follow_up_date'];
    if (fuStr != null) {
      parsedFollowUp = DateTime.tryParse(fuStr.toString());
    }

    DateTime? parsedCreated;
    final crStr = json['createdAt'] ?? json['created_at'];
    if (crStr != null) {
      parsedCreated = DateTime.tryParse(crStr.toString());
    }

    return MedicalTreatmentRecord(
      id: json['id']?.toString() ?? '',
      studentId: json['studentId']?.toString() ?? json['student_id']?.toString(),
      rollNo: json['rollNo']?.toString() ?? json['roll_no']?.toString() ?? '',
      studentName: json['studentName']?.toString() ?? json['student_name']?.toString() ?? '',
      hostelId: json['hostelId']?.toString() ?? json['hostel_id']?.toString() ?? 'boys_hostel',
      treatmentDate: parsedTreatmentDate ?? DateTime.now(),
      hospitalName: json['hospitalName']?.toString() ?? json['hospital_name']?.toString() ?? '',
      doctorName: json['doctorName']?.toString() ?? json['doctor_name']?.toString() ?? '',
      diagnosis: json['diagnosis']?.toString() ?? 'Consultation',
      medicinesPrescribed: json['medicinesPrescribed']?.toString() ?? json['medicines_prescribed']?.toString() ?? '',
      notes: json['notes']?.toString() ?? '',
      followUpDate: parsedFollowUp,
      cost: double.tryParse(json['cost']?.toString() ?? '0') ?? 0.0,
      prescriptionUrl: json['prescriptionUrl']?.toString() ?? json['prescription_url']?.toString(),
      prescriptionBase64: json['prescriptionBase64']?.toString() ?? json['prescription_base64']?.toString(),
      createdAt: parsedCreated ?? DateTime.now(),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'studentId': studentId,
      'rollNo': rollNo,
      'studentName': studentName,
      'hostelId': hostelId,
      'treatmentDate': treatmentDate.toIso8601String(),
      'hospitalName': hospitalName,
      'doctorName': doctorName,
      'diagnosis': diagnosis,
      'medicinesPrescribed': medicinesPrescribed,
      'notes': notes,
      'followUpDate': followUpDate?.toIso8601String().substring(0, 10),
      'cost': cost,
      'prescriptionUrl': prescriptionUrl,
      'prescriptionBase64': prescriptionBase64,
      'createdAt': createdAt.toIso8601String(),
    };
  }

  Map<String, dynamic> toBackend() {
    return {
      if (id.isNotEmpty && !id.startsWith('MED_LOCAL')) 'id': id,
      'student_id': studentId,
      'roll_no': rollNo,
      'student_name': studentName,
      'hostel_id': hostelId,
      'treatment_date': treatmentDate.toIso8601String(),
      'hospital_name': hospitalName,
      'doctor_name': doctorName,
      'diagnosis': diagnosis,
      'medicines_prescribed': medicinesPrescribed,
      'notes': notes,
      'follow_up_date': followUpDate?.toIso8601String().substring(0, 10),
      'cost': cost,
      'prescription_url': prescriptionUrl,
      'prescription_base64': prescriptionBase64,
    };
  }
}

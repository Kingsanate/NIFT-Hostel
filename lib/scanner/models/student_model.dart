/// Represents a student entry extracted from a scanned form.
class StudentModel {
  final String id;
  final String name;
  final String rollNo;
  final String department;
  final String semester;
  final String dateOfBirth;
  final String gender;
  final String contactNo;
  final String emailId;
  final String roomNo;
  final String hostel;
  final String? photoPath; // local path or Supabase URL
  final String? profilePhotoBase64; // Extracted base64 face crop
  final String? medicalBookingType; // 'doctor' or 'counsellor'
  final DateTime? medicalBookingTime; 
  final DateTime createdAt;

  const StudentModel({
    required this.id,
    required this.name,
    required this.rollNo,
    required this.department,
    required this.semester,
    required this.dateOfBirth,
    required this.gender,
    required this.contactNo,
    required this.emailId,
    required this.roomNo,
    required this.hostel,
    this.photoPath,
    this.profilePhotoBase64,
    this.medicalBookingType,
    this.medicalBookingTime,
    required this.createdAt,
  });

  StudentModel copyWith({
    String? id,
    String? name,
    String? rollNo,
    String? department,
    String? semester,
    String? dateOfBirth,
    String? gender,
    String? contactNo,
    String? emailId,
    String? roomNo,
    String? hostel,
    String? photoPath,
    String? profilePhotoBase64,
    String? medicalBookingType,
    DateTime? medicalBookingTime,
    DateTime? createdAt,
  }) {
    return StudentModel(
      id: id ?? this.id,
      name: name ?? this.name,
      rollNo: rollNo ?? this.rollNo,
      department: department ?? this.department,
      semester: semester ?? this.semester,
      dateOfBirth: dateOfBirth ?? this.dateOfBirth,
      gender: gender ?? this.gender,
      contactNo: contactNo ?? this.contactNo,
      emailId: emailId ?? this.emailId,
      roomNo: roomNo ?? this.roomNo,
      hostel: hostel ?? this.hostel,
      photoPath: photoPath ?? this.photoPath,
      profilePhotoBase64: profilePhotoBase64 ?? this.profilePhotoBase64,
      medicalBookingType: medicalBookingType ?? this.medicalBookingType,
      medicalBookingTime: medicalBookingTime ?? this.medicalBookingTime,
      createdAt: createdAt ?? this.createdAt,
    );
  }

  /// Demo data used to simulate AI extraction result
  static StudentModel demoExtracted({
    String? photoPath,
    required String hostel,
  }) => StudentModel(
    id: 'STU${DateTime.now().millisecondsSinceEpoch}',
    name: 'Rahul Kumar Sharma',
    rollNo: 'NIFT/2024/045',
    department: 'Fashion Design',
    semester: 'Semester 3 / Year 2',
    dateOfBirth: '12 May 2003',
    gender: hostel.contains('Girls') ? 'Female' : 'Male', // Dynamically assign gender
    contactNo: '+91 98765 43210',
    emailId: 'rahul.s@example.com',
    roomNo: '', // Room number blank by default
    hostel: hostel,
    photoPath: photoPath,
    medicalBookingType: null,
    medicalBookingTime: null,
    createdAt: DateTime.now(),
  );

  factory StudentModel.fromJson(Map<String, dynamic> json) {
    return StudentModel(
      id: json['id']?.toString() ?? '',
      name: json['name']?.toString() ?? '',
      rollNo: json['rollNo']?.toString() ?? '',
      department: json['department']?.toString() ?? json['course']?.toString() ?? '',
      semester: json['semester']?.toString() ?? json['year']?.toString() ?? '',
      dateOfBirth: json['dateOfBirth']?.toString() ?? '',
      gender: json['gender']?.toString() ?? '',
      contactNo: json['contactNo']?.toString() ?? json['phone']?.toString() ?? '',
      emailId: json['emailId']?.toString() ?? '',
      roomNo: json['roomNo']?.toString() ?? json['room']?.toString() ?? '',
      hostel: json['hostel']?.toString() ?? '',
      photoPath: json['photoPath']?.toString(),
      profilePhotoBase64: json['profilePhotoBase64']?.toString(),
      medicalBookingType: json['medicalBookingType']?.toString(),
      medicalBookingTime: DateTime.tryParse(json['medicalBookingTime']?.toString() ?? ''),
      createdAt: DateTime.tryParse(json['created_at']?.toString() ?? '') ?? DateTime.now(),
    );
  }

  factory StudentModel.fromSupabase(Map<String, dynamic> json, String hostel) {
    return StudentModel(
      id: json['id']?.toString() ?? '',
      name: json['name']?.toString() ?? '',
      rollNo: json['rollNo']?.toString() ?? '',
      department: json['course']?.toString() ?? '',
      semester: json['year']?.toString() ?? '',
      dateOfBirth: json['dateOfBirth']?.toString() ?? '',
      gender: json['gender']?.toString() ?? '',
      contactNo: json['phone']?.toString() ?? '',
      emailId: json['emailId']?.toString() ?? '',
      roomNo: json['room']?.toString() ?? '',
      hostel: hostel,
      photoPath: json['photoPath']?.toString(),
      profilePhotoBase64: json['profilePhotoBase64']?.toString(),
      medicalBookingType: json['medicalBookingType']?.toString(),
      medicalBookingTime: DateTime.tryParse(json['medicalBookingTime']?.toString() ?? ''),
      createdAt: DateTime.tryParse(json['created_at']?.toString() ?? '') ?? DateTime.now(),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'rollNo': rollNo,
      'department': department,
      'semester': semester,
      'dateOfBirth': dateOfBirth,
      'gender': gender,
      'contactNo': contactNo,
      'emailId': emailId,
      'guardianName': '', // Passed as empty string to prevent breaking old DB schema
      'address': '',      // Passed as empty string to prevent breaking old DB schema
      'roomNo': roomNo,
      'hostel': hostel,
      'photoPath': photoPath,
      'profilePhotoBase64': profilePhotoBase64,
      'medicalBookingType': medicalBookingType,
      'medicalBookingTime': medicalBookingTime?.toIso8601String(),
      'createdAt': createdAt.toIso8601String(),
    };
  }

  static String? formatDobForPostgres(String dob) {
    final clean = dob.trim();
    if (clean.isEmpty ||
        clean.toLowerCase() == 'unknown' ||
        clean.toLowerCase() == 'pending' ||
        clean.toLowerCase() == 'n/a') {
      return null;
    }

    // 1. Clean suffixes like 'th', 'st', 'nd', 'rd' (e.g., 25th May 2003 -> 25 May 2003)
    final sanitized = clean.replaceAll(RegExp(r'(\d+)(st|nd|rd|th)', caseSensitive: false), r'$1');

    // 2. Already YYYY-MM-DD
    if (RegExp(r'^\d{4}-\d{2}-\d{2}$').hasMatch(sanitized)) {
      return sanitized;
    }

    // 3. YYYY/MM/DD or YYYY-M-D or YYYY.MM.DD
    final yearFirstMatch = RegExp(r'^(\d{4})[/.-](\d{1,2})[/.-](\d{1,2})$').firstMatch(sanitized);
    if (yearFirstMatch != null) {
      final year = yearFirstMatch.group(1)!;
      final month = yearFirstMatch.group(2)!.padLeft(2, '0');
      final day = yearFirstMatch.group(3)!.padLeft(2, '0');
      final mInt = int.tryParse(month) ?? 0;
      final dInt = int.tryParse(day) ?? 0;
      if (mInt >= 1 && mInt <= 12 && dInt >= 1 && dInt <= 31) {
        return '$year-$month-$day';
      }
    }

    // 4. DD/MM/YYYY or DD-MM-YYYY or DD.MM.YYYY
    final dayFirstMatch = RegExp(r'^(\d{1,2})[/.-](\d{1,2})[/.-](\d{4})$').firstMatch(sanitized);
    if (dayFirstMatch != null) {
      int p1 = int.tryParse(dayFirstMatch.group(1)!) ?? 0;
      int p2 = int.tryParse(dayFirstMatch.group(2)!) ?? 0;
      final year = dayFirstMatch.group(3)!;

      int day = p1;
      int month = p2;
      if (p1 <= 12 && p2 > 12) {
        // MM/DD/YYYY format
        month = p1;
        day = p2;
      }

      final mStr = month.toString().padLeft(2, '0');
      final dStr = day.toString().padLeft(2, '0');
      return '$year-$mStr-$dStr';
    }

    // 5. Textual month (e.g. 25 May 2003 or May 25 2003 or 25-May-2003)
    const months = {
      'jan': '01', 'january': '01',
      'feb': '02', 'february': '02',
      'mar': '03', 'march': '03',
      'apr': '04', 'april': '04',
      'may': '05',
      'jun': '06', 'june': '06',
      'jul': '07', 'july': '07',
      'aug': '08', 'august': '08',
      'sep': '09', 'september': '09',
      'oct': '10', 'october': '10',
      'nov': '11', 'november': '11',
      'dec': '12', 'december': '12',
    };

    final tokens = sanitized.replaceAll(',', ' ').split(RegExp(r'\s+')).where((t) => t.isNotEmpty).toList();
    if (tokens.length >= 3) {
      String? yearStr;
      String? monthStr;
      String? dayStr;

      for (var token in tokens) {
        final tLower = token.toLowerCase();
        if (months.containsKey(tLower)) {
          monthStr = months[tLower];
        } else if (RegExp(r'^\d{4}$').hasMatch(token)) {
          yearStr = token;
        } else if (RegExp(r'^\d{1,2}$').hasMatch(token)) {
          dayStr = token.padLeft(2, '0');
        }
      }

      if (yearStr != null && monthStr != null && dayStr != null) {
        return '$yearStr-$monthStr-$dayStr';
      }
    }

    // 6. DateTime.tryParse (ISO8601 etc)
    final dt = DateTime.tryParse(sanitized);
    if (dt != null) {
      final y = dt.year.toString().padLeft(4, '0');
      final m = dt.month.toString().padLeft(2, '0');
      final d = dt.day.toString().padLeft(2, '0');
      return '$y-$m-$d';
    }

    return null;
  }

  Map<String, dynamic> toSupabase() {
    final formattedDob = formatDobForPostgres(dateOfBirth);

    String hId = 'boys_hostel'; // default
    final hName = hostel.toLowerCase();
    if (hName.contains('boys')) {
      hId = 'boys_hostel';
    } else if (hName.contains('umsawli')) {
      hId = 'umsawli_girls';
    } else if (hName.contains('nongthymmai')) {
      hId = 'nongthymmai_girls';
    }

    final data = <String, dynamic>{
      'name': name.trim(),
      'rollNo': rollNo.trim(),
      'course': department.trim(),
      'year': semester.trim(),
      'gender': gender.trim(),
      'phone': contactNo.trim(),
      'emailId': emailId.trim(),
      'room': roomNo.trim(),
      'status': 'present',
      'hostelId': hId,
    };

    if (formattedDob != null) {
      data['dateOfBirth'] = formattedDob;
    }

    if (profilePhotoBase64 != null && profilePhotoBase64!.isNotEmpty) {
      data['profilePhotoBase64'] = profilePhotoBase64;
    } else if (photoPath != null && photoPath!.isNotEmpty && photoPath!.startsWith('http')) {
      data['photoPath'] = photoPath;
    }

    if (medicalBookingType != null) {
      data['medicalBookingType'] = medicalBookingType;
      data['medicalBookingTime'] = medicalBookingTime?.toIso8601String();
    }

    return data;
  }

  Map<String, String> get displayFields => {
    'Name': name,
    'Roll No': rollNo,
    'Department': department,
    'Semester': semester,
    'Date of Birth': dateOfBirth,
    'Gender': gender,
    'Contact': contactNo,
    'Email ID': emailId,
    'Hostel': hostel, // Display hostel in card
    'Room Assigned': roomNo,
  };
}

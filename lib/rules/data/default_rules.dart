import 'dart:convert';
import '../models/rules_model.dart';

class DefaultRulesData {
  static const Map<String, List<Map<String, String>>> rawRules = {
    'Boys Hostel': [
      {
        'rule_number': '1',
        'category': 'Capacity',
        'title': 'Accommodation & Room Capacity (Double Occupancy)',
        'description':
            'Total 27 rooms with 54 occupancies for Boys at NIFT Campus, Umsawli Hostel in double occupancy of rooms (strictly 2 students per room). Situated approximately 500 meters from the main campus gate. Equipped with common room, 24-hour hot/cold water, high-speed internet, and 24x7 security with CCTV surveillance. FP and MFM-I allocated rooms on a first-come-first-served basis after total hostel & mess fee payment of Rs. 1,50,040/-. Single bed provided; students must bring mattress, pillow, blanket, bed linen, bucket, mug, and personal items.'
      },
      {
        'rule_number': '2',
        'category': 'Timings',
        'title': 'Hostel In-Time & Night Roll-Call',
        'description':
            'Students going out for academic work or personal reasons must return to the campus/hostel by 9:00 P.M. Night roll-call attendance is taken at 10:30 P.M. sharp by the Assistant Warden in rooms. Students not found in their rooms during roll-call will receive a formal warning letter and parent intimation.'
      },
      {
        'rule_number': '3',
        'category': 'Timings',
        'title': 'Late Entry Policy & Escalation Penalties',
        'description':
            'Strict progressive penalty policy for late entry past 9:00 P.M.:\n• 1st Violation: Warning letter issued and parents informed.\n• 2nd Violation: Rs. 1,000/- fine + written undertaking + intimation to parents.\n• 3rd Violation: Rs. 5,000/- fine + written undertaking + intimation to parents.\n• 4th Violation: Permanent expulsion from the hostel + intimation to parents.'
      },
      {
        'rule_number': '4',
        'category': 'Mess & Refectory',
        'title': 'Refectory & Mess Meal Timings',
        'description':
            'Mess operation schedule:\n• Breakfast: 8:00 AM - 9:00 AM\n• Lunch: 12:00 PM - 1:00 PM\n• Evening Snack: 5:00 PM - 6:00 PM\n• Dinner: 8:00 PM - 10:00 PM.'
      },
      {
        'rule_number': '5',
        'category': 'Mess & Refectory',
        'title': 'Refectory Membership & Food Guidelines',
        'description':
            'Refectory facility is compulsory for all hostel residents (permanent member for entire academic year). Self-service system with unlimited food (except special items). Prior intimation must be given if absent for more than 24 hours to prevent food wastage. Cooking in rooms or mess is strictly prohibited. Carrying food or mess utensils to rooms is strictly prohibited. Food wastage is prohibited.'
      },
      {
        'rule_number': '6',
        'category': 'Leaves & Visitors',
        'title': 'Visitor & Day Scholar Restrictions',
        'description':
            'Entertaining unauthorized guests is strictly prohibited. No person is permitted to stay overnight in any part of the hostel. Day scholars are not allowed inside hostel premises without prior written permission. Entry of female students into the Boys\' Hostel is strictly prohibited. Parents are requested to leave their wards at the hostel gate. Unauthorized outsider entry incurs a fine of Rs. 1,000/- and disciplinary action.'
      },
      {
        'rule_number': '7',
        'category': 'Prohibited Items',
        'title': 'Zero-Tolerance Anti-Ragging Policy & Fines',
        'description':
            'Ragging in any form (verbal, psychological, rowdy, or physical conduct) is a serious criminal offence. All residents must submit a signed Anti-Ragging Undertaking Form. Penalties include fine up to Rs. 25,000/-, cancellation of admission, suspension from classes, debarment from examinations/evaluations, withholding results, hostel expulsion, or restriction from entering any educational institute for 1 to 4 years.'
      },
      {
        'rule_number': '8',
        'category': 'Prohibited Items',
        'title': 'Prohibition of Narcotics, Alcohol & Smoking',
        'description':
            'Use of narcotics, drugs, smoking, consumption of alcohol, and gambling is strictly prohibited within the hostel premises. Chewing tobacco, gutkha, betel (pan), and spitting on NIFT premises is strictly prohibited.'
      },
      {
        'rule_number': '9',
        'category': 'Prohibited Items',
        'title': 'Electrical Appliances & Fire Safety Policy',
        'description':
            'Students must switch off lights, fans, geysers, and electronic gadgets when leaving rooms. Use of personal electrical heating/cooking appliances and candles in rooms is prohibited (Fine of Rs. 500/-). Tampering with electrical installations or fixtures is strictly prohibited.'
      },
      {
        'rule_number': '10',
        'category': 'General Conduct',
        'title': 'Room Upkeep, Security & Maintenance',
        'description':
            'Room doors must be locked securely when leaving. Rooms must be kept neat and tidy at all times. Defacing walls, doors, corridors, and cupboards is strictly prohibited. Misuse or damage to property will result in cost recovery and disciplinary action. For civil/electrical repairs, register in the Complaint Register at the hostel reception. Personal couriers are collected from the main gate.'
      },
      {
        'rule_number': '11',
        'category': 'General Conduct',
        'title': 'Summer Vacation & Room Handover',
        'description':
            'All residents must vacate rooms along with their belongings during the summer break. Before leaving, residents must hand over room possession to the Assistant Warden and complete the NO DUES form. Students from other NIFT campuses on internship/industry programs may stay up to 8 weeks with prior approval.'
      },
      {
        'rule_number': '12',
        'category': 'General Conduct',
        'title': 'Hostel Committee & Supervision Directory',
        'description':
            'Supervision by Ms. Rimi Das, Assoc. Prof. & Joint Director. Committee members: Dr. Ngamkholen Haokip (Asst. Prof.), Dr. Lisa L Pachuau (Asst. Prof.), Dr. Natalie Diengdoh (Asst. Prof. & SDAC), Mr. Quest Sanate (Asst. Warden, Boys\' Hostel), Ms. Thricepetal Sancley (Asst. Warden, Nongthymmai Girls\' Hostel), Ms. Macfelia Khongwir (MTS, NIFT Campus Girls\' Hostel). Doctor and counsellor available on call.'
      },
      {
        'rule_number': '13',
        'category': 'General Conduct',
        'title': 'Identity Cards & Code of Conduct',
        'description':
            'Residents must carry valid NIFT identity cards at all times. High standards of behaviour are expected; zero tolerance for prejudice, discrimination, or insult based on caste, religion, language, or community. Valuable cash and items should not be kept in rooms; hostel is not liable for theft. Keep original fee receipts safely.'
      },
    ],
    'Umsawli Girls': [
      {
        'rule_number': '1',
        'category': 'Capacity',
        'title': 'Accommodation & Room Capacity (127 Occupancy)',
        'description':
            'Umsawli Girls\' Hostel (Permanent Campus, Mawpat, ~500m from main gate) accommodates 127 senior students (UG 2nd, 3rd, 4th yr & MFM-II) across 61 rooms:\n• 58 Twin Sharing Rooms (116 capacity)\n• 1 Triple Sharing Room (3 capacity)\n• 2 Four-Sharing Rooms (8 capacity)\nFacilities include common room, 24h water, high-speed internet, and 24x7 security with CCTV surveillance. Preference given: UG 2nd yr → 3rd yr → 4th yr → MFM-II. Total fee: Rs. 62,320/- per semester. Single bed provided; students bring mattress, pillow, blanket, linen, bucket, mug, and personal items.'
      },
      {
        'rule_number': '2',
        'category': 'Timings',
        'title': 'Hostel In-Time & Night Attendance',
        'description':
            'Students going out for academic work or personal errands must return to the campus/hostel by 9:00 P.M. Late return must be informed in writing to the Assistant Warden in advance and parents will be informed. Night attendance is conducted at 10:30 P.M. sharp by the Assistant Warden in rooms with random checks. Defaulters receive a formal warning letter and parent intimation.'
      },
      {
        'rule_number': '3',
        'category': 'Timings',
        'title': 'Late Entry Policy & Escalation Penalties',
        'description':
            'Progressive disciplinary action for late entry past 9:00 P.M.:\n• 1st Violation: Warning letter issued and parents informed.\n• 2nd Violation: Rs. 1,000/- fine + written undertaking + intimation to parents.\n• 3rd Violation: Rs. 5,000/- fine + written undertaking + intimation to parents.\n• 4th Violation: Permanent expulsion from the hostel + intimation to parents.'
      },
      {
        'rule_number': '4',
        'category': 'Mess & Refectory',
        'title': 'Refectory & Mess Meal Schedule',
        'description':
            'Dining hall operating hours:\n• Breakfast: 8:00 AM – 9:00 AM\n• Lunch: 1:00 PM – 2:00 PM\n• Evening Snack: 5:00 PM – 6:00 PM\n• Dinner: 8:30 PM – 10:00 PM.'
      },
      {
        'rule_number': '5',
        'category': 'Mess & Refectory',
        'title': 'Mess Regulations & Dining Etiquette',
        'description':
            'Refectory is compulsory for all residents (permanent membership for academic year). Self-service system with unlimited food (except special items). Prior intimation required if absent >24 hours to prevent food waste. Cooking in rooms/mess is prohibited. Carrying food or utensils (plates, spoons, tumblers) to rooms or outside dining hall is strictly prohibited. No pets/animals inside dining area. Cleanliness and respectful behavior towards staff are mandatory.'
      },
      {
        'rule_number': '6',
        'category': 'Leaves & Visitors',
        'title': 'Visitor & Non-Resident Prohibition',
        'description':
            'No person (male or female) other than registered residents is permitted to enter the Girls\' Hostel. Male students and unauthorized visitors are strictly prohibited and face immediate expulsion. Overnight stay by guests or classmates is strictly prohibited. Day scholars prohibited without written permission. Unauthorized guest violation attracts Rs. 1,000/- fine and severe disciplinary action.'
      },
      {
        'rule_number': '7',
        'category': 'Prohibited Items',
        'title': 'Zero-Tolerance Anti-Ragging Policy & Fines',
        'description':
            'Ragging in any form (verbal, psychological, physical, or rowdy behavior) is strictly prohibited by law. Signed Anti-Ragging Undertaking Form is mandatory. Penalties include fine up to Rs. 25,000/-, cancellation of admission, class suspension, exam debarment, withholding results, hostel expulsion, or restriction from educational institutions for 1 to 4 years.'
      },
      {
        'rule_number': '8',
        'category': 'Prohibited Items',
        'title': 'Prohibition of Narcotics, Alcohol & Smoking',
        'description':
            'All hostel premises (rooms, common rooms, dining hall, washrooms, corridors, terraces) are strictly smoke-free and substance-free. Possession or consumption of alcohol, narcotics, smoking, chewing tobacco, gutkha, pan, spitting, or gambling is grounds for immediate expulsion and rustication.'
      },
      {
        'rule_number': '9',
        'category': 'Prohibited Items',
        'title': 'Electrical Appliances & Fire Safety Policy',
        'description':
            'Switch off lights, fans, geysers, and gadgets when leaving rooms. Use of personal electrical heating/cooking appliances (electric kettles, irons, induction cookers, heaters) is strictly prohibited. Violators face Rs. 500/- fine, confiscation of appliances, and disciplinary action. Candles are prohibited (use torches during power outages).'
      },
      {
        'rule_number': '10',
        'category': 'General Conduct',
        'title': 'Room Upkeep, Wall Decor & Damage Liability',
        'description':
            'Room doors must be securely locked. Rooms, corridors, and washrooms must be kept clean. Regular inspections are conducted. Defacing walls, doors, corridors, or cupboards with writing, painting, glue, tape, nails, or posters is strictly prohibited (leads to expulsion). Furniture cannot be removed or brought in. Civil/electrical complaints must be logged in the Reception Complaint Register.'
      },
      {
        'rule_number': '11',
        'category': 'General Conduct',
        'title': 'Summer Vacation & Room Handover',
        'description':
            'All residents must vacate rooms and take all belongings during the summer break. Hand over room keys to the Assistant Warden and obtain a completed NO DUES form (including canteen clearance). Internship/industry stay for students from other NIFT campuses permitted up to 8 weeks with prior approval.'
      },
      {
        'rule_number': '12',
        'category': 'General Conduct',
        'title': 'Hostel Committee & Supervision Directory',
        'description':
            'Supervised by Ms. Rimi Das, Assoc. Prof. & Joint Director. Committee members: Dr. Ngamkholen Haokip (Asst. Prof.), Dr. Lisa L Pachuau (Asst. Prof.), Dr. Natalie Diengdoh (Asst. Prof. & SDAC), Ms. Thricepetal Sancley (Asst. Warden, Nongthymmai Girls\' Hostel), Mr. Quest Sanate (Asst. Warden, Boys\' Hostel), Ms. Macfelia Khongwir (MTS, NIFT Campus Girls\' Hostel). Doctor & counsellor available on call.'
      },
      {
        'rule_number': '13',
        'category': 'General Conduct',
        'title': 'Identity Cards & Code of Conduct',
        'description':
            'Valid NIFT ID cards must be carried at all times. High standards of courtesy and respect required; zero tolerance for discrimination based on caste, religion, language, or community. Valuable cash and jewelry should not be kept in rooms (hostel is not liable for theft). Keep original fee receipts safely.'
      },
    ],
    'Nongthymmai Girls': [
      {
        'rule_number': '1',
        'category': 'Capacity',
        'title': 'Accommodation & Room Capacity (153 Occupancy)',
        'description':
            'Nongthymmai Girls\' Hostel (Old NEHU Campus, Mayurbhanj, 20 km from main campus) accommodates 153 students across 88 rooms:\n• 46 Single Rooms (46 capacity)\n• 28 Twin Sharing Rooms (56 capacity)\n• 5 Triple Sharing Rooms (15 capacity)\n• 9 Four-Sharing Rooms (36 capacity)\nFacilities include common room, 24h water, internet, mess, and basketball court. Single rooms allotted first, followed by 2, 3, and 4-bedded rooms. MFM-I allocated 2-bedded rooms. Total hostel & mess fee is Rs. 1,50,040/-. Provided with single cot, mattress, chair, and almirah. Students bring pillow, blanket, linen, bucket, mug, and personal items.'
      },
      {
        'rule_number': '2',
        'category': 'Timings',
        'title': 'Hostel In-Time & Night Attendance',
        'description':
            'Students going out for academic work or personal errands must return to the hostel by 9:00 P.M. Late return must be informed in writing to Warden in advance and parents will be informed. Night attendance is conducted at 10:30 P.M. by the Hostel Warden with random checks. Absence during attendance results in a formal warning letter, parent notification, and disciplinary action.'
      },
      {
        'rule_number': '3',
        'category': 'Timings',
        'title': 'Late Entry Policy & Escalation Penalties',
        'description':
            'Progressive disciplinary action for late entry past 9:00 P.M.:\n• 1st Violation: Warning letter issued and parents informed.\n• 2nd Violation: Rs. 1,000/- fine + written undertaking + intimation to parents.\n• 3rd Violation: Rs. 5,000/- fine + written undertaking + intimation to parents.\n• 4th Violation: Permanent expulsion from the hostel + intimation to parents.'
      },
      {
        'rule_number': '4',
        'category': 'Mess & Refectory',
        'title': 'Refectory & Mess Meal Schedule',
        'description':
            'Dining hall operating hours:\n• Breakfast: 7:30 AM – 8:30 AM\n• Lunch: 1:00 PM – 2:30 PM\n• Snacks: 5:00 PM – 6:00 PM\n• Dinner: 8:00 PM – 9:30 PM.'
      },
      {
        'rule_number': '5',
        'category': 'Mess & Refectory',
        'title': 'Mess Regulations & Dining Etiquette',
        'description':
            'Refectory is compulsory for all residents (permanent membership for academic year). Self-service system with unlimited food (except special items). Prior intimation required if absent >24 hours to prevent food waste. Cooking in rooms/mess is prohibited. Carrying food or utensils (plates, spoons, tumblers) to rooms or outside dining hall is strictly prohibited. No pets/animals inside dining area. Cleanliness and respectful behavior towards staff are mandatory.'
      },
      {
        'rule_number': '6',
        'category': 'Leaves & Visitors',
        'title': 'Visitor & Male Entry Prohibition',
        'description':
            'No visitors are allowed inside the Girls\' Hostel. Entry of male students into the Girls\' Hostel is strictly prohibited and results in immediate expulsion. Overnight stay by guests or classmates is strictly prohibited. Day scholars prohibited without written permission. Parents must leave their wards at the hostel gate (hostel staff will assist first-time students with luggage). Unauthorized guest violation attracts Rs. 1,000/- fine and severe disciplinary action.'
      },
      {
        'rule_number': '7',
        'category': 'Prohibited Items',
        'title': 'Zero-Tolerance Anti-Ragging Policy & Fines',
        'description':
            'Ragging in any form (verbal, psychological, physical, or rowdy behavior) is strictly prohibited by law. Signed Anti-Ragging Undertaking Form is mandatory. Penalties include fine up to Rs. 25,000/-, cancellation of admission, class suspension, exam debarment, withholding results, hostel expulsion, or restriction from educational institutions for 1 to 4 years.'
      },
      {
        'rule_number': '8',
        'category': 'Prohibited Items',
        'title': 'Prohibition of Narcotics, Alcohol & Smoking',
        'description':
            'All hostel premises (rooms, common rooms, dining hall, washrooms, corridors, terraces) are strictly smoke-free and substance-free. Possession or consumption of alcohol, narcotics, smoking, chewing tobacco, gutkha, pan, spitting, or gambling is grounds for immediate expulsion and rustication.'
      },
      {
        'rule_number': '9',
        'category': 'Prohibited Items',
        'title': 'Electrical Appliances & Fire Safety Policy',
        'description':
            'Switch off lights, fans, geysers, and gadgets when leaving rooms. Use of personal electrical heating/cooking appliances (electric kettles, irons, induction cookers, heaters) is strictly prohibited. Violators face Rs. 500/- fine, confiscation of appliances, and disciplinary action. Candles are prohibited (use torches during power outages).'
      },
      {
        'rule_number': '10',
        'category': 'General Conduct',
        'title': 'Room Upkeep, Wall Decor & Damage Liability',
        'description':
            'Room doors must be securely locked. Rooms, corridors, and washrooms must be kept clean. Regular inspections are conducted. Defacing walls, doors, corridors, or cupboards with writing, painting, glue, tape, nails, or posters is strictly prohibited (leads to expulsion). Furniture cannot be removed or brought in. Civil/electrical complaints must be logged in the Reception Complaint Register.'
      },
      {
        'rule_number': '11',
        'category': 'General Conduct',
        'title': 'Summer Vacation & Room Handover',
        'description':
            'All residents must vacate rooms and take all belongings during the summer break. Hand over room keys to the Warden and obtain a completed NO DUES form (including canteen clearance). Internship/industry stay for students from other NIFT campuses permitted up to 8 weeks with prior approval.'
      },
      {
        'rule_number': '12',
        'category': 'General Conduct',
        'title': 'Hostel Committee & Supervision Directory',
        'description':
            'Supervised by Ms. Rimi Das, Assoc. Prof. & Joint Director. Committee members: Dr. Ngamkholen Haokip (Asst. Prof.), Dr. Lisa L Pachuau (Asst. Prof.), Dr. Natalie Diengdoh (Asst. Prof. & SDAC), Ms. Thricepetal Sancley (Asst. Warden, Nongthymmai Girls\' Hostel), Mr. Quest Sanate (Asst. Warden, Boys\' Hostel), Ms. Macfelia Khongwir (MTS, NIFT Campus Girls\' Hostel). Doctor & counsellor available on call.'
      },
      {
        'rule_number': '13',
        'category': 'General Conduct',
        'title': 'Identity Cards & Code of Conduct',
        'description':
            'Valid NIFT ID cards must be carried at all times. High standards of courtesy and respect required; zero tolerance for discrimination based on caste, religion, language, or community. Valuable cash and jewelry should not be kept in rooms (hostel is not liable for theft). Keep original fee receipts safely.'
      },
    ],
  };

  static Map<String, RulesModel> getDefaultRulesModels() {
    final Map<String, RulesModel> models = {};
    rawRules.forEach((hostel, list) {
      final jsonStr = jsonEncode(list);
      models[hostel] = RulesModel(
        id: 'default-$hostel',
        hostelName: hostel,
        extractedText: jsonStr,
        createdAt: DateTime.now(),
      );
    });
    return models;
  }
}

// ============================================================
// models.dart  —  part of liquid_logistics main library
// Auto-extracted from main_v23_8.dart (original lines 1105-3057)
// DO NOT add imports here — all imports live in main.dart
// ============================================================
part of 'package:liquid_logistics/main.dart';

class UserProfile {
  String companyName,
      gstin,
      phone,
      address,
      email,
      bankName,
      bankAccount,
      bankIfsc,
      panNumber;
  UserRole role;

  UserProfile({
    this.companyName = 'Sandhu Logistics',
    this.gstin = 'Unregistered',
    this.phone = '+91 0000000000',
    this.address = 'Ahmedabad, Gujarat',
    this.email = '',
    this.bankName = '',
    this.bankAccount = '',
    this.bankIfsc = '',
    this.panNumber = '',
    this.role = UserRole.owner,
  });

  Map<String, dynamic> toJson() => {
        'companyName': companyName,
        'gstin': gstin,
        'phone': phone,
        'address': address,
        'email': email,
        'bankName': bankName,
        'bankAccount': bankAccount,
        'bankIfsc': bankIfsc,
        'panNumber': panNumber,
        'role': role.index,
      };

  factory UserProfile.fromJson(Map<String, dynamic> json) => UserProfile(
        companyName: json['companyName'] ?? '',
        gstin: json['gstin'] ?? '',
        phone: json['phone'] ?? '',
        address: json['address'] ?? '',
        email: json['email'] ?? '',
        bankName: json['bankName'] ?? '',
        bankAccount: json['bankAccount'] ?? '',
        bankIfsc: json['bankIfsc'] ?? '',
        panNumber: json['panNumber'] ?? '',
        role: json.containsKey('role')
            ? UserRole.values[(json['role'] as int)]
            : UserRole.owner,
      );

  Null get pan => null;
}

class VehicleDocConfig {
  static List<String> getRequiredDocs(String vehicleType) {
    final vt = vehicleType.toLowerCase().trim();
    final common = [
      "RC Book",
      "Insurance",
      "PUCC / Emission",
      "Fitness Certificate",
      "National Permit"
    ];
    if (vt.contains('tanker') || vt.contains('ss') || vt.contains('ms')) {
      return [
        ...common,
        "Explosive / Hazmat Auth",
        "Dangerous Goods Permit",
        "ADR Certificate",
        "Tank Calibration Certificate",
        "Tank Inspection Report",
        "Driver Hazmat Training"
      ];
    }
    if (vt.contains('container')) {
      return [
        ...common,
        "Container Seal Certificate",
        "Port Pass (if applicable)"
      ];
    }
    if (vt.contains('trailer') || vt.contains('abnormal')) {
      return [
        ...common,
        "Overloading Permit",
        "Abnormal Load Permit",
        "Pilot Vehicle Auth"
      ];
    }
    if (vt.contains('reefer') || vt.contains('refrigerated')) {
      return [
        ...common,
        "Cold Chain Certificate",
        "Temperature Log Book",
        "Reefer Unit Service Record"
      ];
    }
    if (vt.contains('lcv') || vt.contains('light')) {
      return ["RC Book", "Insurance", "PUCC / Emission", "National Permit"];
    }
    if (vt.contains('open') || vt.contains('truck')) {
      return [...common, "Weight Bridge Slip (per trip)"];
    }
    return common;
  }
}

// ================================================================
// INDIA DATA
// ================================================================
const List<Map<String, String>> kIndianCities = [
  {'city': 'Ahmedabad', 'state': 'Gujarat', 'full': 'Ahmedabad, Gujarat'},
  {'city': 'Surat', 'state': 'Gujarat', 'full': 'Surat, Gujarat'},
  {'city': 'Vadodara', 'state': 'Gujarat', 'full': 'Vadodara, Gujarat'},
  {'city': 'Rajkot', 'state': 'Gujarat', 'full': 'Rajkot, Gujarat'},
  {'city': 'Gandhinagar', 'state': 'Gujarat', 'full': 'Gandhinagar, Gujarat'},
  {'city': 'Bharuch', 'state': 'Gujarat', 'full': 'Bharuch, Gujarat'},
  {'city': 'Ankleshwar', 'state': 'Gujarat', 'full': 'Ankleshwar, Gujarat'},
  {'city': 'Hazira', 'state': 'Gujarat', 'full': 'Hazira, Gujarat'},
  {'city': 'Dahej', 'state': 'Gujarat', 'full': 'Dahej, Gujarat'},
  {'city': 'Mundra Port', 'state': 'Gujarat', 'full': 'Mundra Port, Gujarat'},
  {'city': 'Kandla Port', 'state': 'Gujarat', 'full': 'Kandla Port, Gujarat'},
  {'city': 'Vapi', 'state': 'Gujarat', 'full': 'Vapi, Gujarat'},
  {'city': 'Morbi', 'state': 'Gujarat', 'full': 'Morbi, Gujarat'},
  {'city': 'Bhavnagar', 'state': 'Gujarat', 'full': 'Bhavnagar, Gujarat'},
  {'city': 'Jamnagar', 'state': 'Gujarat', 'full': 'Jamnagar, Gujarat'},
  {'city': 'Mehsana', 'state': 'Gujarat', 'full': 'Mehsana, Gujarat'},
  {'city': 'Navsari', 'state': 'Gujarat', 'full': 'Navsari, Gujarat'},
  {'city': 'Anand', 'state': 'Gujarat', 'full': 'Anand, Gujarat'},
  {'city': 'Nadiad', 'state': 'Gujarat', 'full': 'Nadiad, Gujarat'},
  {
    'city': 'Surendranagar',
    'state': 'Gujarat',
    'full': 'Surendranagar, Gujarat'
  },
  {'city': 'Botad', 'state': 'Gujarat', 'full': 'Botad, Gujarat'},
  {'city': 'Amreli', 'state': 'Gujarat', 'full': 'Amreli, Gujarat'},
  {'city': 'Junagadh', 'state': 'Gujarat', 'full': 'Junagadh, Gujarat'},
  {'city': 'Porbandar', 'state': 'Gujarat', 'full': 'Porbandar, Gujarat'},
  {'city': 'Palanpur', 'state': 'Gujarat', 'full': 'Palanpur, Gujarat'},
  {'city': 'Himatnagar', 'state': 'Gujarat', 'full': 'Himatnagar, Gujarat'},
  {'city': 'Godhra', 'state': 'Gujarat', 'full': 'Godhra, Gujarat'},
  {'city': 'Bhuj', 'state': 'Gujarat', 'full': 'Bhuj, Gujarat'},
  {'city': 'Gandhidham', 'state': 'Gujarat', 'full': 'Gandhidham, Gujarat'},
  {'city': 'Veraval', 'state': 'Gujarat', 'full': 'Veraval, Gujarat'},
  {'city': 'Halol', 'state': 'Gujarat', 'full': 'Halol, Gujarat'},
  {'city': 'Dholera', 'state': 'Gujarat', 'full': 'Dholera, Gujarat'},
  {'city': 'Mandvi', 'state': 'Gujarat', 'full': 'Mandvi, Gujarat'},
  {'city': 'Silvassa', 'state': 'Dadra & NH', 'full': 'Silvassa, Dadra & NH'},
  {'city': 'Mumbai', 'state': 'Maharashtra', 'full': 'Mumbai, Maharashtra'},
  {'city': 'Pune', 'state': 'Maharashtra', 'full': 'Pune, Maharashtra'},
  {'city': 'Nagpur', 'state': 'Maharashtra', 'full': 'Nagpur, Maharashtra'},
  {'city': 'Nashik', 'state': 'Maharashtra', 'full': 'Nashik, Maharashtra'},
  {
    'city': 'Chhatrapati Sambhajinagar',
    'state': 'Maharashtra',
    'full': 'Chhatrapati Sambhajinagar, Maharashtra'
  },
  {'city': 'JNPT', 'state': 'Maharashtra', 'full': 'JNPT, Maharashtra'},
  {'city': 'Bhiwandi', 'state': 'Maharashtra', 'full': 'Bhiwandi, Maharashtra'},
  {
    'city': 'Navi Mumbai',
    'state': 'Maharashtra',
    'full': 'Navi Mumbai, Maharashtra'
  },
  {'city': 'Solapur', 'state': 'Maharashtra', 'full': 'Solapur, Maharashtra'},
  {'city': 'Kolhapur', 'state': 'Maharashtra', 'full': 'Kolhapur, Maharashtra'},
  {'city': 'Thane', 'state': 'Maharashtra', 'full': 'Thane, Maharashtra'},
  {'city': 'Raigad', 'state': 'Maharashtra', 'full': 'Raigad, Maharashtra'},
  {
    'city': 'Ahmednagar',
    'state': 'Maharashtra',
    'full': 'Ahmednagar, Maharashtra'
  },
  {'city': 'Latur', 'state': 'Maharashtra', 'full': 'Latur, Maharashtra'},
  {'city': 'Jalgaon', 'state': 'Maharashtra', 'full': 'Jalgaon, Maharashtra'},
  {'city': 'Akola', 'state': 'Maharashtra', 'full': 'Akola, Maharashtra'},
  {'city': 'Amravati', 'state': 'Maharashtra', 'full': 'Amravati, Maharashtra'},
  {'city': 'Nanded', 'state': 'Maharashtra', 'full': 'Nanded, Maharashtra'},
  {'city': 'Sangli', 'state': 'Maharashtra', 'full': 'Sangli, Maharashtra'},
  {'city': 'Satara', 'state': 'Maharashtra', 'full': 'Satara, Maharashtra'},
  {'city': 'Wardha', 'state': 'Maharashtra', 'full': 'Wardha, Maharashtra'},
  {
    'city': 'Chandrapur',
    'state': 'Maharashtra',
    'full': 'Chandrapur, Maharashtra'
  },
  {'city': 'Dhule', 'state': 'Maharashtra', 'full': 'Dhule, Maharashtra'},
  {
    'city': 'Taloja MIDC',
    'state': 'Maharashtra',
    'full': 'Taloja MIDC, Maharashtra'
  },
  {
    'city': 'Tarapur MIDC',
    'state': 'Maharashtra',
    'full': 'Tarapur MIDC, Maharashtra'
  },
  {'city': 'Delhi', 'state': 'Delhi', 'full': 'Delhi, Delhi'},
  {'city': 'New Delhi', 'state': 'Delhi', 'full': 'New Delhi, Delhi'},
  {'city': 'Noida', 'state': 'Uttar Pradesh', 'full': 'Noida, Uttar Pradesh'},
  {'city': 'Gurgaon', 'state': 'Haryana', 'full': 'Gurgaon, Haryana'},
  {'city': 'Faridabad', 'state': 'Haryana', 'full': 'Faridabad, Haryana'},
  {
    'city': 'Ghaziabad',
    'state': 'Uttar Pradesh',
    'full': 'Ghaziabad, Uttar Pradesh'
  },
  {
    'city': 'Greater Noida',
    'state': 'Uttar Pradesh',
    'full': 'Greater Noida, Uttar Pradesh'
  },
  {'city': 'Manesar', 'state': 'Haryana', 'full': 'Manesar, Haryana'},
  {'city': 'Bahadurgarh', 'state': 'Haryana', 'full': 'Bahadurgarh, Haryana'},
  {'city': 'Palwal', 'state': 'Haryana', 'full': 'Palwal, Haryana'},
  {'city': 'Jaipur', 'state': 'Rajasthan', 'full': 'Jaipur, Rajasthan'},
  {'city': 'Jodhpur', 'state': 'Rajasthan', 'full': 'Jodhpur, Rajasthan'},
  {'city': 'Udaipur', 'state': 'Rajasthan', 'full': 'Udaipur, Rajasthan'},
  {'city': 'Kota', 'state': 'Rajasthan', 'full': 'Kota, Rajasthan'},
  {'city': 'Ajmer', 'state': 'Rajasthan', 'full': 'Ajmer, Rajasthan'},
  {'city': 'Bikaner', 'state': 'Rajasthan', 'full': 'Bikaner, Rajasthan'},
  {'city': 'Alwar', 'state': 'Rajasthan', 'full': 'Alwar, Rajasthan'},
  {'city': 'Bhilwara', 'state': 'Rajasthan', 'full': 'Bhilwara, Rajasthan'},
  {'city': 'Sikar', 'state': 'Rajasthan', 'full': 'Sikar, Rajasthan'},
  {
    'city': 'Sriganganagar',
    'state': 'Rajasthan',
    'full': 'Sriganganagar, Rajasthan'
  },
  {'city': 'Barmer', 'state': 'Rajasthan', 'full': 'Barmer, Rajasthan'},
  {'city': 'Jaisalmer', 'state': 'Rajasthan', 'full': 'Jaisalmer, Rajasthan'},
  {'city': 'Pali', 'state': 'Rajasthan', 'full': 'Pali, Rajasthan'},
  {'city': 'Nagaur', 'state': 'Rajasthan', 'full': 'Nagaur, Rajasthan'},
  {'city': 'Bhiwadi', 'state': 'Rajasthan', 'full': 'Bhiwadi, Rajasthan'},
  {'city': 'Neemrana', 'state': 'Rajasthan', 'full': 'Neemrana, Rajasthan'},
  {
    'city': 'Chittorgarh',
    'state': 'Rajasthan',
    'full': 'Chittorgarh, Rajasthan'
  },
  {'city': 'Bundi', 'state': 'Rajasthan', 'full': 'Bundi, Rajasthan'},
  {'city': 'Amritsar', 'state': 'Punjab', 'full': 'Amritsar, Punjab'},
  {'city': 'Ludhiana', 'state': 'Punjab', 'full': 'Ludhiana, Punjab'},
  {'city': 'Chandigarh', 'state': 'Punjab', 'full': 'Chandigarh, Punjab'},
  {'city': 'Jalandhar', 'state': 'Punjab', 'full': 'Jalandhar, Punjab'},
  {'city': 'Patiala', 'state': 'Punjab', 'full': 'Patiala, Punjab'},
  {'city': 'Bathinda', 'state': 'Punjab', 'full': 'Bathinda, Punjab'},
  {'city': 'Mohali', 'state': 'Punjab', 'full': 'Mohali, Punjab'},
  {'city': 'Moga', 'state': 'Punjab', 'full': 'Moga, Punjab'},
  {'city': 'Pathankot', 'state': 'Punjab', 'full': 'Pathankot, Punjab'},
  {'city': 'Hoshiarpur', 'state': 'Punjab', 'full': 'Hoshiarpur, Punjab'},
  {'city': 'Phagwara', 'state': 'Punjab', 'full': 'Phagwara, Punjab'},
  {'city': 'Ropar', 'state': 'Punjab', 'full': 'Ropar, Punjab'},
  {'city': 'Panipat', 'state': 'Haryana', 'full': 'Panipat, Haryana'},
  {'city': 'Hisar', 'state': 'Haryana', 'full': 'Hisar, Haryana'},
  {'city': 'Ambala', 'state': 'Haryana', 'full': 'Ambala, Haryana'},
  {'city': 'Karnal', 'state': 'Haryana', 'full': 'Karnal, Haryana'},
  {'city': 'Rohtak', 'state': 'Haryana', 'full': 'Rohtak, Haryana'},
  {'city': 'Sonipat', 'state': 'Haryana', 'full': 'Sonipat, Haryana'},
  {'city': 'Rewari', 'state': 'Haryana', 'full': 'Rewari, Haryana'},
  {'city': 'Jhajjar', 'state': 'Haryana', 'full': 'Jhajjar, Haryana'},
  {'city': 'Sirsa', 'state': 'Haryana', 'full': 'Sirsa, Haryana'},
  {'city': 'Bhiwani', 'state': 'Haryana', 'full': 'Bhiwani, Haryana'},
  {'city': 'Yamunanagar', 'state': 'Haryana', 'full': 'Yamunanagar, Haryana'},
  {'city': 'Kurukshetra', 'state': 'Haryana', 'full': 'Kurukshetra, Haryana'},
  {
    'city': 'Lucknow',
    'state': 'Uttar Pradesh',
    'full': 'Lucknow, Uttar Pradesh'
  },
  {'city': 'Kanpur', 'state': 'Uttar Pradesh', 'full': 'Kanpur, Uttar Pradesh'},
  {'city': 'Agra', 'state': 'Uttar Pradesh', 'full': 'Agra, Uttar Pradesh'},
  {
    'city': 'Varanasi',
    'state': 'Uttar Pradesh',
    'full': 'Varanasi, Uttar Pradesh'
  },
  {'city': 'Meerut', 'state': 'Uttar Pradesh', 'full': 'Meerut, Uttar Pradesh'},
  {
    'city': 'Mathura',
    'state': 'Uttar Pradesh',
    'full': 'Mathura, Uttar Pradesh'
  },
  {
    'city': 'Allahabad',
    'state': 'Uttar Pradesh',
    'full': 'Allahabad, Uttar Pradesh'
  },
  {
    'city': 'Bareilly',
    'state': 'Uttar Pradesh',
    'full': 'Bareilly, Uttar Pradesh'
  },
  {
    'city': 'Aligarh',
    'state': 'Uttar Pradesh',
    'full': 'Aligarh, Uttar Pradesh'
  },
  {
    'city': 'Moradabad',
    'state': 'Uttar Pradesh',
    'full': 'Moradabad, Uttar Pradesh'
  },
  {
    'city': 'Gorakhpur',
    'state': 'Uttar Pradesh',
    'full': 'Gorakhpur, Uttar Pradesh'
  },
  {
    'city': 'Firozabad',
    'state': 'Uttar Pradesh',
    'full': 'Firozabad, Uttar Pradesh'
  },
  {'city': 'Jhansi', 'state': 'Uttar Pradesh', 'full': 'Jhansi, Uttar Pradesh'},
  {
    'city': 'Saharanpur',
    'state': 'Uttar Pradesh',
    'full': 'Saharanpur, Uttar Pradesh'
  },
  {
    'city': 'Muzaffarnagar',
    'state': 'Uttar Pradesh',
    'full': 'Muzaffarnagar, Uttar Pradesh'
  },
  {'city': 'Hapur', 'state': 'Uttar Pradesh', 'full': 'Hapur, Uttar Pradesh'},
  {'city': 'Unnao', 'state': 'Uttar Pradesh', 'full': 'Unnao, Uttar Pradesh'},
  {
    'city': 'Bulandshahr',
    'state': 'Uttar Pradesh',
    'full': 'Bulandshahr, Uttar Pradesh'
  },
  {
    'city': 'Bhopal',
    'state': 'Madhya Pradesh',
    'full': 'Bhopal, Madhya Pradesh'
  },
  {
    'city': 'Indore',
    'state': 'Madhya Pradesh',
    'full': 'Indore, Madhya Pradesh'
  },
  {
    'city': 'Jabalpur',
    'state': 'Madhya Pradesh',
    'full': 'Jabalpur, Madhya Pradesh'
  },
  {
    'city': 'Ratlam',
    'state': 'Madhya Pradesh',
    'full': 'Ratlam, Madhya Pradesh'
  },
  {'city': 'Dewas', 'state': 'Madhya Pradesh', 'full': 'Dewas, Madhya Pradesh'},
  {
    'city': 'Gwalior',
    'state': 'Madhya Pradesh',
    'full': 'Gwalior, Madhya Pradesh'
  },
  {
    'city': 'Ujjain',
    'state': 'Madhya Pradesh',
    'full': 'Ujjain, Madhya Pradesh'
  },
  {'city': 'Sagar', 'state': 'Madhya Pradesh', 'full': 'Sagar, Madhya Pradesh'},
  {'city': 'Satna', 'state': 'Madhya Pradesh', 'full': 'Satna, Madhya Pradesh'},
  {'city': 'Katni', 'state': 'Madhya Pradesh', 'full': 'Katni, Madhya Pradesh'},
  {
    'city': 'Chhindwara',
    'state': 'Madhya Pradesh',
    'full': 'Chhindwara, Madhya Pradesh'
  },
  {
    'city': 'Pithampur',
    'state': 'Madhya Pradesh',
    'full': 'Pithampur, Madhya Pradesh'
  },
  {
    'city': 'Mandideep',
    'state': 'Madhya Pradesh',
    'full': 'Mandideep, Madhya Pradesh'
  },
  {
    'city': 'Khandwa',
    'state': 'Madhya Pradesh',
    'full': 'Khandwa, Madhya Pradesh'
  },
  {'city': 'Rewa', 'state': 'Madhya Pradesh', 'full': 'Rewa, Madhya Pradesh'},
  {'city': 'Hyderabad', 'state': 'Telangana', 'full': 'Hyderabad, Telangana'},
  {'city': 'Warangal', 'state': 'Telangana', 'full': 'Warangal, Telangana'},
  {'city': 'Karimnagar', 'state': 'Telangana', 'full': 'Karimnagar, Telangana'},
  {'city': 'Nizamabad', 'state': 'Telangana', 'full': 'Nizamabad, Telangana'},
  {'city': 'Khammam', 'state': 'Telangana', 'full': 'Khammam, Telangana'},
  {
    'city': 'Secunderabad',
    'state': 'Telangana',
    'full': 'Secunderabad, Telangana'
  },
  {'city': 'Sangareddy', 'state': 'Telangana', 'full': 'Sangareddy, Telangana'},
  {'city': 'Mancherial', 'state': 'Telangana', 'full': 'Mancherial, Telangana'},
  {
    'city': 'Visakhapatnam',
    'state': 'Andhra Pradesh',
    'full': 'Visakhapatnam, Andhra Pradesh'
  },
  {
    'city': 'Vijayawada',
    'state': 'Andhra Pradesh',
    'full': 'Vijayawada, Andhra Pradesh'
  },
  {
    'city': 'Guntur',
    'state': 'Andhra Pradesh',
    'full': 'Guntur, Andhra Pradesh'
  },
  {
    'city': 'Kakinada',
    'state': 'Andhra Pradesh',
    'full': 'Kakinada, Andhra Pradesh'
  },
  {
    'city': 'Nellore',
    'state': 'Andhra Pradesh',
    'full': 'Nellore, Andhra Pradesh'
  },
  {
    'city': 'Tirupati',
    'state': 'Andhra Pradesh',
    'full': 'Tirupati, Andhra Pradesh'
  },
  {
    'city': 'Kurnool',
    'state': 'Andhra Pradesh',
    'full': 'Kurnool, Andhra Pradesh'
  },
  {
    'city': 'Rajamahendravaram',
    'state': 'Andhra Pradesh',
    'full': 'Rajamahendravaram, Andhra Pradesh'
  },
  {
    'city': 'Anantapur',
    'state': 'Andhra Pradesh',
    'full': 'Anantapur, Andhra Pradesh'
  },
  {
    'city': 'Ongole',
    'state': 'Andhra Pradesh',
    'full': 'Ongole, Andhra Pradesh'
  },
  {
    'city': 'Vizianagaram',
    'state': 'Andhra Pradesh',
    'full': 'Vizianagaram, Andhra Pradesh'
  },
  {'city': 'Eluru', 'state': 'Andhra Pradesh', 'full': 'Eluru, Andhra Pradesh'},
  {'city': 'Bengaluru', 'state': 'Karnataka', 'full': 'Bengaluru, Karnataka'},
  {'city': 'Mysuru', 'state': 'Karnataka', 'full': 'Mysuru, Karnataka'},
  {'city': 'Mangaluru', 'state': 'Karnataka', 'full': 'Mangaluru, Karnataka'},
  {'city': 'Hubballi', 'state': 'Karnataka', 'full': 'Hubballi, Karnataka'},
  {'city': 'Belagavi', 'state': 'Karnataka', 'full': 'Belagavi, Karnataka'},
  {'city': 'Davangere', 'state': 'Karnataka', 'full': 'Davangere, Karnataka'},
  {'city': 'Ballari', 'state': 'Karnataka', 'full': 'Ballari, Karnataka'},
  {'city': 'Tumakuru', 'state': 'Karnataka', 'full': 'Tumakuru, Karnataka'},
  {'city': 'Kalaburagi', 'state': 'Karnataka', 'full': 'Kalaburagi, Karnataka'},
  {'city': 'Raichur', 'state': 'Karnataka', 'full': 'Raichur, Karnataka'},
  {'city': 'Udupi', 'state': 'Karnataka', 'full': 'Udupi, Karnataka'},
  {'city': 'Bidar', 'state': 'Karnataka', 'full': 'Bidar, Karnataka'},
  {'city': 'Shivamogga', 'state': 'Karnataka', 'full': 'Shivamogga, Karnataka'},
  {'city': 'Hassan', 'state': 'Karnataka', 'full': 'Hassan, Karnataka'},
  {
    'city': 'Chikmagalur',
    'state': 'Karnataka',
    'full': 'Chikmagalur, Karnataka'
  },
  {'city': 'Chennai', 'state': 'Tamil Nadu', 'full': 'Chennai, Tamil Nadu'},
  {
    'city': 'Coimbatore',
    'state': 'Tamil Nadu',
    'full': 'Coimbatore, Tamil Nadu'
  },
  {'city': 'Madurai', 'state': 'Tamil Nadu', 'full': 'Madurai, Tamil Nadu'},
  {
    'city': 'Thoothukudi',
    'state': 'Tamil Nadu',
    'full': 'Thoothukudi, Tamil Nadu'
  },
  {
    'city': 'Tiruchirappalli',
    'state': 'Tamil Nadu',
    'full': 'Tiruchirappalli, Tamil Nadu'
  },
  {'city': 'Salem', 'state': 'Tamil Nadu', 'full': 'Salem, Tamil Nadu'},
  {
    'city': 'Tirunelveli',
    'state': 'Tamil Nadu',
    'full': 'Tirunelveli, Tamil Nadu'
  },
  {'city': 'Tiruppur', 'state': 'Tamil Nadu', 'full': 'Tiruppur, Tamil Nadu'},
  {'city': 'Vellore', 'state': 'Tamil Nadu', 'full': 'Vellore, Tamil Nadu'},
  {'city': 'Erode', 'state': 'Tamil Nadu', 'full': 'Erode, Tamil Nadu'},
  {'city': 'Hosur', 'state': 'Tamil Nadu', 'full': 'Hosur, Tamil Nadu'},
  {'city': 'Cuddalore', 'state': 'Tamil Nadu', 'full': 'Cuddalore, Tamil Nadu'},
  {
    'city': 'Ennore Port',
    'state': 'Tamil Nadu',
    'full': 'Ennore Port, Tamil Nadu'
  },
  {
    'city': 'Kamarajar Port',
    'state': 'Tamil Nadu',
    'full': 'Kamarajar Port, Tamil Nadu'
  },
  {'city': 'Nagercoil', 'state': 'Tamil Nadu', 'full': 'Nagercoil, Tamil Nadu'},
  {'city': 'Kochi', 'state': 'Kerala', 'full': 'Kochi, Kerala'},
  {
    'city': 'Thiruvananthapuram',
    'state': 'Kerala',
    'full': 'Thiruvananthapuram, Kerala'
  },
  {'city': 'Kozhikode', 'state': 'Kerala', 'full': 'Kozhikode, Kerala'},
  {'city': 'Thrissur', 'state': 'Kerala', 'full': 'Thrissur, Kerala'},
  {'city': 'Kollam', 'state': 'Kerala', 'full': 'Kollam, Kerala'},
  {'city': 'Kannur', 'state': 'Kerala', 'full': 'Kannur, Kerala'},
  {'city': 'Alappuzha', 'state': 'Kerala', 'full': 'Alappuzha, Kerala'},
  {'city': 'Palakkad', 'state': 'Kerala', 'full': 'Palakkad, Kerala'},
  {'city': 'Malappuram', 'state': 'Kerala', 'full': 'Malappuram, Kerala'},
  {'city': 'Kottayam', 'state': 'Kerala', 'full': 'Kottayam, Kerala'},
  {'city': 'Kasaragod', 'state': 'Kerala', 'full': 'Kasaragod, Kerala'},
  {'city': 'Kolkata', 'state': 'West Bengal', 'full': 'Kolkata, West Bengal'},
  {
    'city': 'Haldia Port',
    'state': 'West Bengal',
    'full': 'Haldia Port, West Bengal'
  },
  {'city': 'Howrah', 'state': 'West Bengal', 'full': 'Howrah, West Bengal'},
  {'city': 'Durgapur', 'state': 'West Bengal', 'full': 'Durgapur, West Bengal'},
  {'city': 'Asansol', 'state': 'West Bengal', 'full': 'Asansol, West Bengal'},
  {'city': 'Siliguri', 'state': 'West Bengal', 'full': 'Siliguri, West Bengal'},
  {
    'city': 'Kharagpur',
    'state': 'West Bengal',
    'full': 'Kharagpur, West Bengal'
  },
  {
    'city': 'Bardhaman',
    'state': 'West Bengal',
    'full': 'Bardhaman, West Bengal'
  },
  {'city': 'Malda', 'state': 'West Bengal', 'full': 'Malda, West Bengal'},
  {'city': 'Bhubaneswar', 'state': 'Odisha', 'full': 'Bhubaneswar, Odisha'},
  {'city': 'Paradip', 'state': 'Odisha', 'full': 'Paradip, Odisha'},
  {'city': 'Cuttack', 'state': 'Odisha', 'full': 'Cuttack, Odisha'},
  {'city': 'Rourkela', 'state': 'Odisha', 'full': 'Rourkela, Odisha'},
  {'city': 'Berhampur', 'state': 'Odisha', 'full': 'Berhampur, Odisha'},
  {'city': 'Sambalpur', 'state': 'Odisha', 'full': 'Sambalpur, Odisha'},
  {'city': 'Jharsuguda', 'state': 'Odisha', 'full': 'Jharsuguda, Odisha'},
  {'city': 'Angul', 'state': 'Odisha', 'full': 'Angul, Odisha'},
  {'city': 'Talcher', 'state': 'Odisha', 'full': 'Talcher, Odisha'},
  {'city': 'Dhamra Port', 'state': 'Odisha', 'full': 'Dhamra Port, Odisha'},
  {'city': 'Patna', 'state': 'Bihar', 'full': 'Patna, Bihar'},
  {'city': 'Muzaffarpur', 'state': 'Bihar', 'full': 'Muzaffarpur, Bihar'},
  {'city': 'Gaya', 'state': 'Bihar', 'full': 'Gaya, Bihar'},
  {'city': 'Bhagalpur', 'state': 'Bihar', 'full': 'Bhagalpur, Bihar'},
  {'city': 'Purnia', 'state': 'Bihar', 'full': 'Purnia, Bihar'},
  {'city': 'Darbhanga', 'state': 'Bihar', 'full': 'Darbhanga, Bihar'},
  {'city': 'Hajipur', 'state': 'Bihar', 'full': 'Hajipur, Bihar'},
  {'city': 'Arrah', 'state': 'Bihar', 'full': 'Arrah, Bihar'},
  {'city': 'Ranchi', 'state': 'Jharkhand', 'full': 'Ranchi, Jharkhand'},
  {'city': 'Jamshedpur', 'state': 'Jharkhand', 'full': 'Jamshedpur, Jharkhand'},
  {'city': 'Dhanbad', 'state': 'Jharkhand', 'full': 'Dhanbad, Jharkhand'},
  {'city': 'Bokaro', 'state': 'Jharkhand', 'full': 'Bokaro, Jharkhand'},
  {'city': 'Hazaribagh', 'state': 'Jharkhand', 'full': 'Hazaribagh, Jharkhand'},
  {'city': 'Deoghar', 'state': 'Jharkhand', 'full': 'Deoghar, Jharkhand'},
  {'city': 'Giridih', 'state': 'Jharkhand', 'full': 'Giridih, Jharkhand'},
  {'city': 'Raipur', 'state': 'Chhattisgarh', 'full': 'Raipur, Chhattisgarh'},
  {'city': 'Bhilai', 'state': 'Chhattisgarh', 'full': 'Bhilai, Chhattisgarh'},
  {
    'city': 'Bilaspur',
    'state': 'Chhattisgarh',
    'full': 'Bilaspur, Chhattisgarh'
  },
  {'city': 'Durg', 'state': 'Chhattisgarh', 'full': 'Durg, Chhattisgarh'},
  {'city': 'Korba', 'state': 'Chhattisgarh', 'full': 'Korba, Chhattisgarh'},
  {'city': 'Raigarh', 'state': 'Chhattisgarh', 'full': 'Raigarh, Chhattisgarh'},
  {
    'city': 'Jagdalpur',
    'state': 'Chhattisgarh',
    'full': 'Jagdalpur, Chhattisgarh'
  },
  {'city': 'Guwahati', 'state': 'Assam', 'full': 'Guwahati, Assam'},
  {'city': 'Dibrugarh', 'state': 'Assam', 'full': 'Dibrugarh, Assam'},
  {'city': 'Jorhat', 'state': 'Assam', 'full': 'Jorhat, Assam'},
  {'city': 'Silchar', 'state': 'Assam', 'full': 'Silchar, Assam'},
  {'city': 'Tezpur', 'state': 'Assam', 'full': 'Tezpur, Assam'},
  {'city': 'Nagaon', 'state': 'Assam', 'full': 'Nagaon, Assam'},
  {'city': 'Bongaigaon', 'state': 'Assam', 'full': 'Bongaigaon, Assam'},
  {'city': 'Numaligarh', 'state': 'Assam', 'full': 'Numaligarh, Assam'},
  {'city': 'Dehradun', 'state': 'Uttarakhand', 'full': 'Dehradun, Uttarakhand'},
  {'city': 'Haridwar', 'state': 'Uttarakhand', 'full': 'Haridwar, Uttarakhand'},
  {'city': 'Roorkee', 'state': 'Uttarakhand', 'full': 'Roorkee, Uttarakhand'},
  {'city': 'Haldwani', 'state': 'Uttarakhand', 'full': 'Haldwani, Uttarakhand'},
  {'city': 'Rudrapur', 'state': 'Uttarakhand', 'full': 'Rudrapur, Uttarakhand'},
  {
    'city': 'Rishikesh',
    'state': 'Uttarakhand',
    'full': 'Rishikesh, Uttarakhand'
  },
  {'city': 'Kashipur', 'state': 'Uttarakhand', 'full': 'Kashipur, Uttarakhand'},
  {
    'city': 'Pantnagar',
    'state': 'Uttarakhand',
    'full': 'Pantnagar, Uttarakhand'
  },
  {
    'city': 'Shimla',
    'state': 'Himachal Pradesh',
    'full': 'Shimla, Himachal Pradesh'
  },
  {
    'city': 'Manali',
    'state': 'Himachal Pradesh',
    'full': 'Manali, Himachal Pradesh'
  },
  {
    'city': 'Solan',
    'state': 'Himachal Pradesh',
    'full': 'Solan, Himachal Pradesh'
  },
  {
    'city': 'Baddi',
    'state': 'Himachal Pradesh',
    'full': 'Baddi, Himachal Pradesh'
  },
  {
    'city': 'Paonta Sahib',
    'state': 'Himachal Pradesh',
    'full': 'Paonta Sahib, Himachal Pradesh'
  },
  {
    'city': 'Dharamsala',
    'state': 'Himachal Pradesh',
    'full': 'Dharamsala, Himachal Pradesh'
  },
  {
    'city': 'Mandi',
    'state': 'Himachal Pradesh',
    'full': 'Mandi, Himachal Pradesh'
  },
  {'city': 'Panaji', 'state': 'Goa', 'full': 'Panaji, Goa'},
  {'city': 'Vasco da Gama', 'state': 'Goa', 'full': 'Vasco da Gama, Goa'},
  {'city': 'Margao', 'state': 'Goa', 'full': 'Margao, Goa'},
  {'city': 'Mormugao Port', 'state': 'Goa', 'full': 'Mormugao Port, Goa'},
  {'city': 'Jammu', 'state': 'J&K', 'full': 'Jammu, J&K'},
  {'city': 'Srinagar', 'state': 'J&K', 'full': 'Srinagar, J&K'},
  {'city': 'Kathua', 'state': 'J&K', 'full': 'Kathua, J&K'},
  {'city': 'Udhampur', 'state': 'J&K', 'full': 'Udhampur, J&K'},
  {'city': 'Leh', 'state': 'Ladakh', 'full': 'Leh, Ladakh'},
  {'city': 'Imphal', 'state': 'Manipur', 'full': 'Imphal, Manipur'},
  {'city': 'Shillong', 'state': 'Meghalaya', 'full': 'Shillong, Meghalaya'},
  {'city': 'Agartala', 'state': 'Tripura', 'full': 'Agartala, Tripura'},
  {'city': 'Aizawl', 'state': 'Mizoram', 'full': 'Aizawl, Mizoram'},
  {'city': 'Kohima', 'state': 'Nagaland', 'full': 'Kohima, Nagaland'},
  {
    'city': 'Itanagar',
    'state': 'Arunachal Pradesh',
    'full': 'Itanagar, Arunachal Pradesh'
  },
  {'city': 'Gangtok', 'state': 'Sikkim', 'full': 'Gangtok, Sikkim'},
  {'city': 'Dimapur', 'state': 'Nagaland', 'full': 'Dimapur, Nagaland'},
  {'city': 'Tura', 'state': 'Meghalaya', 'full': 'Tura, Meghalaya'},
  // Union Territories
  {'city': 'Daman', 'state': 'Daman & Diu', 'full': 'Daman, Daman & Diu'},
  {'city': 'Diu', 'state': 'Daman & Diu', 'full': 'Diu, Daman & Diu'},
  {
    'city': 'Puducherry',
    'state': 'Puducherry',
    'full': 'Puducherry, Puducherry'
  },
  {'city': 'Karaikal', 'state': 'Puducherry', 'full': 'Karaikal, Puducherry'},
  {'city': 'Mahe', 'state': 'Puducherry', 'full': 'Mahe, Puducherry'},
  {'city': 'Yanam', 'state': 'Puducherry', 'full': 'Yanam, Puducherry'},
  {
    'city': 'Lakshadweep',
    'state': 'Lakshadweep',
    'full': 'Kavaratti, Lakshadweep'
  },
  {
    'city': 'Port Blair',
    'state': 'Andaman & Nicobar',
    'full': 'Port Blair, Andaman & Nicobar'
  },
  {
    'city': 'Chandigarh',
    'state': 'Chandigarh',
    'full': 'Chandigarh, Chandigarh'
  },
  // Additional industrial cities
  {'city': 'Ludhiana', 'state': 'Punjab', 'full': 'Ludhiana, Punjab'},
  {
    'city': 'Manali Refinery',
    'state': 'Tamil Nadu',
    'full': 'Manali Refinery, Tamil Nadu'
  },
  {'city': 'Dahej SEZ', 'state': 'Gujarat', 'full': 'Dahej SEZ, Gujarat'},
  {'city': 'Hajira', 'state': 'Gujarat', 'full': 'Hajira, Gujarat'},
  {'city': 'Savli', 'state': 'Gujarat', 'full': 'Savli, Gujarat'},
  {'city': 'Padra', 'state': 'Gujarat', 'full': 'Padra, Gujarat'},
  {'city': 'Kalol', 'state': 'Gujarat', 'full': 'Kalol, Gujarat'},
  {'city': 'Kadi', 'state': 'Gujarat', 'full': 'Kadi, Gujarat'},
  {'city': 'Vatva GIDC', 'state': 'Gujarat', 'full': 'Vatva GIDC, Gujarat'},
  {'city': 'Naroda GIDC', 'state': 'Gujarat', 'full': 'Naroda GIDC, Gujarat'},
  {'city': 'Odhav GIDC', 'state': 'Gujarat', 'full': 'Odhav GIDC, Gujarat'},
  {'city': 'Panoli GIDC', 'state': 'Gujarat', 'full': 'Panoli GIDC, Gujarat'},
  {'city': 'Jhagadia', 'state': 'Gujarat', 'full': 'Jhagadia, Gujarat'},
  {'city': 'Sachin GIDC', 'state': 'Gujarat', 'full': 'Sachin GIDC, Gujarat'},
];

// NHAI FY2024-25 FASTag toll rates — Rs. per km on National Highways
// Source: NHAI fee notification & Ministry of Road Transport FY2024-25 revision
// Validated: Delhi-Mumbai 1400km, 6-axle tanker pays ~Rs.9,500-11,500 (8.10×0.8×1400=9,072)
// Note: ~75-80% of typical long-haul route is on NH (toll-applicable)
// Remaining 20-25% is state roads / urban stretch (no toll)
const double kNhFraction =
    0.78; // 78% of route distance is typically toll-applicable NH
const Map<int, double> kTollPerAxlePerKm = {
  2: 2.55, // 2-axle LCV / mini truck (e.g. Tata 407, Bolero Pickup)
  3: 3.85, // 3-axle rigid / medium truck
  4: 5.20, // 4-axle heavy truck / Tata 2518
  5: 6.60, // 5-axle multi-axle vehicle (MAV)
  6: 8.40, // 6-axle tanker/trailer (most SS/MS tankers) — e.g. 1400km×8.40×0.78=9,173
  7: 9.80, // 7-axle oversize / ODDC
  8: 11.20, // 8-axle heavy special / multi-axle trailer
};

// Accurate toll estimator — use this everywhere instead of ad-hoc formulas
double estimateToll(num km, int axles) {
  final rate = kTollPerAxlePerKm[axles] ?? 8.40;
  return (km * rate * kNhFraction).roundToDouble();
}

// ================================================================
// MODELS
// ================================================================

class BankEntry {
  final String date, narration, refNo;
  final double debit, credit;
  bool isMatched;
  String? matchedLedgerId;
  BankEntry(
      {required this.date,
      required this.narration,
      required this.refNo,
      required this.debit,
      required this.credit,
      this.isMatched = false,
      this.matchedLedgerId});
}

class Battery {
  String make, model, serialNo, billNo, purchaseDate, warrantyExpiry;
  double warrantyYears;
  Battery(
      {required this.make,
      this.model = '',
      required this.serialNo,
      this.billNo = '',
      required this.purchaseDate,
      required this.warrantyExpiry,
      this.warrantyYears = 1.0});
  Map<String, dynamic> toJson() => {
        'make': make,
        'model': model,
        'serialNo': serialNo,
        'billNo': billNo,
        'purchaseDate': purchaseDate,
        'warrantyExpiry': warrantyExpiry,
        'warrantyYears': warrantyYears
      };
  factory Battery.fromJson(Map<String, dynamic> j) => Battery(
      make: j['make'] ?? '',
      model: j['model'] ?? '',
      serialNo: j['serialNo'] ?? '',
      billNo: j['billNo'] ?? '',
      purchaseDate: j['purchaseDate'] ?? '',
      warrantyExpiry: j['warrantyExpiry'] ?? '',
      warrantyYears: (j['warrantyYears'] as num?)?.toDouble() ?? 1.0);
}

class DriverDoc {
  String type; // aadhaar, dl, photo
  bool isUploaded;
  String fileName, uploadDate, docNumber, expiryDate, filePath, mimeType;
  DriverDoc(
      {required this.type,
      this.isUploaded = false,
      this.fileName = '',
      this.uploadDate = '',
      this.docNumber = '',
      this.expiryDate = '',
      this.filePath = '',
      this.mimeType = ''});
  String get label {
    switch (type) {
      case 'aadhaar':
        return 'Aadhaar Card';
      case 'dl':
        return 'Driving Licence';
      case 'photo':
        return 'Driver Photo';
      default:
        return type;
    }
  }

  Map<String, dynamic> toJson() => {
        'type': type,
        'isUploaded': isUploaded,
        'fileName': fileName,
        'uploadDate': uploadDate,
        'docNumber': docNumber,
        'expiryDate': expiryDate,
        'filePath': filePath,
        'mimeType': mimeType
      };
  factory DriverDoc.fromJson(Map<String, dynamic> j) => DriverDoc(
      type: j['type'] ?? '',
      isUploaded: j['isUploaded'] ?? false,
      fileName: j['fileName'] ?? '',
      uploadDate: j['uploadDate'] ?? '',
      docNumber: j['docNumber'] ?? '',
      expiryDate: j['expiryDate'] ?? '',
      filePath: j['filePath'] ?? '',
      mimeType: j['mimeType'] ?? '');
}

// ================================================================
// MSG91 WHATSAPP OTP SERVICE
// ================================================================
// Setup: msg91.com → sign up → API key + WhatsApp template ID
// Cost:  Rs.0.30/OTP  |  Speed: 1-3 sec  |  Works offline SMS fallback
// To activate: fill msg91AuthKey + msg91TemplateId in AppConfig,
//              then set whatsAppOtpEnabled = true
// ================================================================
class Msg91OtpService {
  static String? _pendingOtp; // OTP we sent (stored locally for verification)
  static String? _pendingPhone; // Phone it was sent to
  static DateTime? _sentAt; // When it was sent (10-min expiry)

  // ── Send WhatsApp OTP via MSG91 ──────────────────────────────
  static Future<Map<String, dynamic>> sendOtp(String tenDigitPhone) async {
    if (!AppConfig.hasMsg91) {
      return {
        'success': false,
        'error': 'MSG91 not configured. Set keys in AppConfig.'
      };
    }
    final fullPhone = '91$tenDigitPhone';
    // Generate 6-digit OTP
    final otp = (100000 + math.Random().nextInt(900000)).toString();
    try {
      final response = await http
          .post(
            Uri.parse('https://api.msg91.com/api/v5/otp'),
            headers: {
              'authkey': AppConfig.msg91AuthKey,
              'Content-Type': 'application/json',
            },
            body: jsonEncode({
              'authkey': AppConfig.msg91AuthKey,
              'template_id': AppConfig.msg91TemplateId,
              'mobile': fullPhone,
              'otp': otp,
              'otp_expiry': '10', // minutes
              'invisible': '0',
            }),
          )
          .timeout(const Duration(seconds: 15));

      debugPrint('MSG91 send → ${response.statusCode}: ${response.body}');

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body) as Map<String, dynamic>;
        if (data['type'] == 'success' || (data['request_id'] != null)) {
          _pendingOtp = otp;
          _pendingPhone = fullPhone;
          _sentAt = DateTime.now();
          return {'success': true};
        }
        return {'success': false, 'error': data['message'] ?? 'MSG91 error'};
      }
      return {
        'success': false,
        'error': 'Network error (${response.statusCode})'
      };
    } on TimeoutException {
      return {
        'success': false,
        'error': 'Timed out. Check internet and try again.'
      };
    } catch (e) {
      return {
        'success': false,
        'error': 'Failed: ${e.toString().replaceAll('Exception:', '').trim()}'
      };
    }
  }

  // ── Resend OTP ───────────────────────────────────────────────
  static Future<Map<String, dynamic>> resendOtp(String tenDigitPhone) async {
    if (!AppConfig.hasMsg91) {
      return {'success': false, 'error': 'MSG91 not configured'};
    }
    try {
      final response = await http
          .post(
            Uri.parse('https://api.msg91.com/api/v5/otp/retry'),
            headers: {
              'authkey': AppConfig.msg91AuthKey,
              'Content-Type': 'application/json'
            },
            body: jsonEncode({
              'authkey': AppConfig.msg91AuthKey,
              'mobile': '91$tenDigitPhone',
              'retrytype': 'text'
            }),
          )
          .timeout(const Duration(seconds: 15));
      debugPrint('MSG91 resend → ${response.statusCode}');
      if (response.statusCode == 200) return {'success': true};
      return await sendOtp(tenDigitPhone); // fallback: send fresh OTP
    } catch (_) {
      return await sendOtp(tenDigitPhone);
    }
  }

  // ── Verify OTP entered by user ───────────────────────────────
  // Returns: {'success': true, 'uid': firebaseUid} or {'success': false, 'error': '...'}
  static Future<Map<String, dynamic>> verifyOtp({
    required String tenDigitPhone,
    required String enteredOtp,
  }) async {
    final fullPhone = '91$tenDigitPhone';
    // Check expiry
    if (_sentAt == null ||
        DateTime.now().difference(_sentAt!).inMinutes >= 10) {
      _clear();
      return {
        'success': false,
        'error': 'OTP expired. Tap Resend to get a new one.'
      };
    }
    if (_pendingPhone != fullPhone) {
      return {'success': false, 'error': 'Phone number mismatch.'};
    }
    if (_pendingOtp == null || enteredOtp.trim() != _pendingOtp) {
      return {
        'success': false,
        'error': 'Incorrect OTP. Please check and try again.'
      };
    }
    // SECURITY: refuse anonymous sign-in. Self-declared phone + anonymous auth
    // is not real verification and can be bypassed. WhatsApp OTP must be
    // verified server-side before a session is issued. Use SMS login instead.
    return {
      'success': false,
      'error': 'WhatsApp OTP is unavailable. Please use SMS login instead.'
    };
    // ignore: dead_code
    try {
      final cred = await FirebaseAuth.instance.signInAnonymously();
      final uid = cred.user!.uid;
      // Store phone in Firestore so the app treats this as a phone-authenticated user
      await FirebaseFirestore.instance.collection('users').doc(uid).set({
        'phone': tenDigitPhone,
        'loginMethod': 'whatsapp_otp',
        'updatedAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));
      _clear();
      return {'success': true, 'uid': uid};
    } catch (e) {
      return {'success': false, 'error': 'Firebase sign-in failed: $e'};
    }
  }

  static void _clear() {
    _pendingOtp = null;
    _pendingPhone = null;
    _sentAt = null;
  }
}

// ════════════════════════════════════════════════════════════════
// À LA CARTE ADD-ONS — individually purchasable features, layered on
// TOP of whatever fixed tier (Free/Pro/Business/Enterprise) a user is
// on. This is additive by design: it never replaces the existing
// tier system, so a Free user can buy just "Live GPS" without moving
// to Pro, and a Pro user can add "KredX" without jumping to Business.
// ════════════════════════════════════════════════════════════════
class AlaCarteFeature {
  final String id;
  final String label;
  final String description;
  final double monthlyPrice;
  const AlaCarteFeature({
    required this.id,
    required this.label,
    required this.description,
    required this.monthlyPrice,
  });
}

const List<AlaCarteFeature> kAlaCarteFeatures = [
  AlaCarteFeature(
      id: 'pdf_export',
      label: 'PDF Export (LR & Invoice)',
      description: 'Generate professional PDF documents',
      monthlyPrice: 199),
  AlaCarteFeature(
      id: 'live_gps',
      label: 'Live GPS Tracking',
      description: 'Real-time vehicle location tracking',
      monthlyPrice: 299),
  AlaCarteFeature(
      id: 'kredx',
      label: 'KredX Invoice Financing',
      description: 'Instant advances on pending invoices',
      monthlyPrice: 999),
  AlaCarteFeature(
      id: 'route_calc',
      label: 'Route Auto-Calculator',
      description: 'Automatic route & rate suggestions',
      monthlyPrice: 149),
  AlaCarteFeature(
      id: 'priority_support',
      label: 'Priority Support',
      description: 'Faster response on help requests',
      monthlyPrice: 149),
  AlaCarteFeature(
      id: 'branding',
      label: 'Custom Company Branding',
      description: 'Your logo on reports & PDFs',
      monthlyPrice: 249),
];
const double kAlaCartePerExtraUserPrice = 149; // per additional sub-user
const double kAlaCartePerExtraVehicleBlockPrice = 99; // per +10 vehicles

class SubscriptionInfo {
  SubscriptionTier tier;
  String expiryDate;
  int tripsUsedThisMonth;
  // À la carte add-ons — apply on top of [tier], regardless of which
  // tier the user is on. Empty/zero by default so existing behaviour
  // for anyone who hasn't bought add-ons is completely unchanged.
  Set<String> addOns;
  int extraUsers;
  int extraVehicleBlocks; // each block = +10 vehicles

  SubscriptionInfo({
    this.tier = SubscriptionTier.free,
    this.expiryDate = "",
    this.tripsUsedThisMonth = 0,
    Set<String>? addOns,
    this.extraUsers = 0,
    this.extraVehicleBlocks = 0,
  }) : addOns = addOns ?? <String>{};

  bool get canUseGPS =>
      tier != SubscriptionTier.free || addOns.contains('live_gps');
  bool get canUseKredX =>
      tier == SubscriptionTier.business ||
      tier == SubscriptionTier.enterprise ||
      addOns.contains('kredx');
  bool get canExportPDF =>
      tier != SubscriptionTier.free || addOns.contains('pdf_export');
  bool get isEnterprise => tier == SubscriptionTier.enterprise;
  int get maxUsers =>
      (tier == SubscriptionTier.enterprise
          ? 10
          : tier == SubscriptionTier.business
              ? 3
              : 1) +
      extraUsers;
  int get maxVehicles =>
      (tier == SubscriptionTier.enterprise
          ? 999
          : tier == SubscriptionTier.business
              ? 50
              : tier == SubscriptionTier.pro
                  ? 15
                  : 5) +
      (extraVehicleBlocks * 10);
  bool get isTripsLimitReached =>
      tier == SubscriptionTier.free && tripsUsedThisMonth >= 10;

  // Monthly cost of add-ons only (on top of whatever the base tier
  // itself costs — the tier's own price lives in the SubscriptionScreen
  // plan cards, not here).
  double get addOnsMonthlyPrice {
    double total = 0;
    for (final f in kAlaCarteFeatures) {
      if (addOns.contains(f.id)) total += f.monthlyPrice;
    }
    total += extraUsers * kAlaCartePerExtraUserPrice;
    total += extraVehicleBlocks * kAlaCartePerExtraVehicleBlockPrice;
    return total;
  }

  String get tierName {
    switch (tier) {
      case SubscriptionTier.free:
        return "FREE";
      case SubscriptionTier.pro:
        return "PRO";
      case SubscriptionTier.business:
        return "BUSINESS";
      case SubscriptionTier.enterprise:
        return "ENTERPRISE";
    }
  }

  Color get tierColor {
    switch (tier) {
      case SubscriptionTier.free:
        return Colors.grey;
      case SubscriptionTier.pro:
        return Colors.blueAccent;
      case SubscriptionTier.business:
        return Colors.amber.shade700;
      case SubscriptionTier.enterprise:
        return const Color(0xFF0EA5E9);
    }
  }

  Map<String, dynamic> toJson() => {
        'tier': tier.index,
        'expiryDate': expiryDate,
        'tripsUsedThisMonth': tripsUsedThisMonth,
        'addOns': addOns.toList(),
        'extraUsers': extraUsers,
        'extraVehicleBlocks': extraVehicleBlocks,
      };
  factory SubscriptionInfo.fromJson(Map<String, dynamic> j) => SubscriptionInfo(
      tier: SubscriptionTier.values[j['tier'] ?? 0],
      expiryDate: j['expiryDate'] ?? "",
      tripsUsedThisMonth: j['tripsUsedThisMonth'] ?? 0,
      addOns: ((j['addOns'] as List?)?.map((e) => e.toString()).toSet()) ??
          <String>{},
      extraUsers: j['extraUsers'] ?? 0,
      extraVehicleBlocks: j['extraVehicleBlocks'] ?? 0);
}

class KredXApplication {
  String id, invoiceLedgerId, partyName;
  double invoiceAmount, requestedAmount, approvedAmount;
  KredXStatus status;
  String appliedDate;
  int tenureDays;
  double interestRate;
  KredXApplication(
      {required this.id,
      required this.invoiceLedgerId,
      required this.partyName,
      required this.invoiceAmount,
      required this.requestedAmount,
      this.approvedAmount = 0,
      this.status = KredXStatus.draft,
      required this.appliedDate,
      this.tenureDays = 30,
      this.interestRate = 1.5});
  double get estimatedInterest =>
      (approvedAmount > 0 ? approvedAmount : requestedAmount) *
      (interestRate / 100) *
      (tenureDays / 30);
  double get netDisbursal =>
      (approvedAmount > 0 ? approvedAmount : requestedAmount) -
      estimatedInterest;
  String get statusLabel {
    switch (status) {
      case KredXStatus.draft:
        return "Draft";
      case KredXStatus.submitted:
        return "Submitted";
      case KredXStatus.underReview:
        return "Under Review";
      case KredXStatus.approved:
        return "Approved";
      case KredXStatus.disbursed:
        return "Disbursed";
      case KredXStatus.rejected:
        return "Rejected";
    }
  }

  Color get statusColor {
    switch (status) {
      case KredXStatus.draft:
        return Colors.grey;
      case KredXStatus.submitted:
        return Colors.blue;
      case KredXStatus.underReview:
        return Colors.orange;
      case KredXStatus.approved:
        return Colors.green;
      case KredXStatus.disbursed:
        return Colors.teal;
      case KredXStatus.rejected:
        return Colors.red;
    }
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'invoiceLedgerId': invoiceLedgerId,
        'partyName': partyName,
        'invoiceAmount': invoiceAmount,
        'requestedAmount': requestedAmount,
        'approvedAmount': approvedAmount,
        'status': status.index,
        'appliedDate': appliedDate,
        'tenureDays': tenureDays,
        'interestRate': interestRate
      };
  factory KredXApplication.fromJson(Map<String, dynamic> j) => KredXApplication(
      id: j['id'],
      invoiceLedgerId: j['invoiceLedgerId'],
      partyName: j['partyName'],
      invoiceAmount: (j['invoiceAmount'] as num).toDouble(),
      requestedAmount: (j['requestedAmount'] as num).toDouble(),
      approvedAmount: (j['approvedAmount'] as num? ?? 0).toDouble(),
      status: KredXStatus.values[j['status'] ?? 0],
      appliedDate: j['appliedDate'],
      tenureDays: j['tenureDays'] ?? 30,
      interestRate: (j['interestRate'] as num? ?? 1.5).toDouble());
}

// UserProfile is defined in lib/erp_features.dart and includes role information.

class DriverTx {
  String date;
  DriverTxType type;
  double amount;
  String note;
  DriverTx(
      {required this.date,
      required this.type,
      required this.amount,
      required this.note});
  Map<String, dynamic> toJson() =>
      {'date': date, 'type': type.index, 'amount': amount, 'note': note};
  factory DriverTx.fromJson(Map<String, dynamic> j) => DriverTx(
      date: j['date'],
      type: DriverTxType.values[j['type']],
      amount: (j['amount'] as num).toDouble(),
      note: j['note']);
}

class Driver {
  String id, name, phone, aadharNum, dlNum;
  String selfieDocPath, aadhaarDocPath, dlDocPath;
  String? fleetOwnerUid;
  double balance, monthlySalary;
  List<DriverTx> transactions;
  List<DriverDoc> documents;
  // Trust system
  bool isBlacklisted;
  String blacklistReason;
  int trustPoints; // starts at 100, deducted on violations
  bool isVerifiedBadge; // admin-granted verified badge
  List<Map<String, dynamic>> violations; // [{reason, points, date}]

  Driver(
      {required this.id,
      required this.name,
      required this.phone,
      required this.balance,
      required this.transactions,
      this.aadharNum = "",
      this.dlNum = "",
      this.selfieDocPath = "",
      this.aadhaarDocPath = "",
      this.dlDocPath = "",
      this.fleetOwnerUid,
      this.monthlySalary = 0,
      List<DriverDoc>? documents,
      this.isBlacklisted = false,
      this.blacklistReason = "",
      this.trustPoints = 100,
      this.isVerifiedBadge = false,
      this.violations = const []})
      : documents = documents ??
            [
              DriverDoc(type: 'aadhaar'),
              DriverDoc(type: 'dl'),
              DriverDoc(type: 'photo')
            ];
  bool get isVerified => documents.every((d) => (d).isUploaded);
  String get trustLabel => trustPoints >= 80
      ? 'Excellent'
      : trustPoints >= 60
          ? 'Good'
          : trustPoints >= 40
              ? 'Fair'
              : 'Poor';
  Color get trustColor => trustPoints >= 80
      ? const Color(0xFF10B981)
      : trustPoints >= 60
          ? const Color(0xFF3B82F6)
          : trustPoints >= 40
              ? const Color(0xFFF59E0B)
              : const Color(0xFFEF4444);
  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'phone': phone,
        'balance': balance,
        'aadharNum': aadharNum,
        'dlNum': dlNum,
        'selfieDocPath': selfieDocPath,
        'aadhaarDocPath': aadhaarDocPath,
        'dlDocPath': dlDocPath,
        'fleetOwnerUid': fleetOwnerUid,
        'monthlySalary': monthlySalary,
        'transactions': transactions.map((t) => t.toJson()).toList(),
        'documents': documents.map((d) => (d).toJson()).toList(),
        'isBlacklisted': isBlacklisted,
        'blacklistReason': blacklistReason,
        'trustPoints': trustPoints,
        'isVerifiedBadge': isVerifiedBadge,
        'violations': violations,
      };
  factory Driver.fromJson(Map<String, dynamic> j) => Driver(
      id: j['id'],
      name: j['name'],
      phone: j['phone'],
      balance: (j['balance'] as num).toDouble(),
      monthlySalary: (j['monthlySalary'] as num? ?? 0).toDouble(),
      transactions:
          (j['transactions'] as List).map((t) => DriverTx.fromJson(t)).toList(),
      aadharNum: j['aadharNum'] ?? "",
      dlNum: j['dlNum'] ?? "",
      selfieDocPath: j['selfieDocPath'] ?? "",
      aadhaarDocPath: j['aadhaarDocPath'] ?? "",
      dlDocPath: j['dlDocPath'] ?? "",
      fleetOwnerUid: j['fleetOwnerUid'],
      isBlacklisted: j['isBlacklisted'] as bool? ?? false,
      blacklistReason: j['blacklistReason'] ?? "",
      trustPoints: j['trustPoints'] as int? ?? 100,
      isVerifiedBadge: j['isVerifiedBadge'] as bool? ?? false,
      violations: (j['violations'] as List<dynamic>? ?? [])
          .cast<Map<String, dynamic>>(),
      documents: j['documents'] != null
          ? (j['documents'] as List).map((d) => DriverDoc.fromJson(d)).toList()
          : null);
}

// Part load invoice item - supports multiple products in one truck
class InvoiceItem {
  String invoiceNo;
  String materialName;
  double weight;
  String weightUnit;
  String description;
  double value; // declared value for LR

  InvoiceItem(
      {this.invoiceNo = '',
      this.materialName = '',
      this.weight = 0,
      this.weightUnit = 'MT',
      this.description = '',
      this.value = 0});

  Map<String, dynamic> toJson() => {
        'invoiceNo': invoiceNo,
        'materialName': materialName,
        'weight': weight,
        'weightUnit': weightUnit,
        'description': description,
        'value': value
      };

  factory InvoiceItem.fromJson(Map<String, dynamic> j) => InvoiceItem(
      invoiceNo: j['invoiceNo'] ?? '',
      materialName: j['materialName'] ?? '',
      weight: (j['weight'] as num? ?? 0).toDouble(),
      weightUnit: j['weightUnit'] ?? 'MT',
      description: j['description'] ?? '',
      value: (j['value'] as num? ?? 0).toDouble());
}

class TripLedger {
  String id, date, partyName, vehicleNo, route;
  VehicleOwnership ownership;
  String eWayBillNo, materialName;
  String loadingPoint, unloadingPoint, loadingState, unloadingState;
  String consignorPhone, consignorEmail, consignorGstin;
  double freightBilled, paymentReceived;
  double diesel, toll, driverExp, materialLoss;
  double marketTruckFreight, marketAdvancePaid;
  double penalties, tdsDeduction;
  double distanceKm, fuelEconomy;
  double routeDistanceSavedKm, routeDieselSavedL, routeCo2SavedKg;
  String? driverName;
  int paymentTermsDays;
  String lrNotes;
  GstType gstType;
  double gstRate;
  bool isGstInclusive;
  double weightTons;
  String weightUnit;

  List<InvoiceItem> invoiceItems; // part load items - multiple products
  String materialInvoiceNo; // main invoice number
  String dispatchedAt; // ISO timestamp when truck left
  String estimatedArrival; // ISO timestamp of expected arrival
  bool isInTransit;
  double platformCommission; // 2% of freight - platform fee from fleet owner
  double consignorCommission; // 2% of freight - platform fee from consignor
  String loadingDocPath; // photo of docs received at loading factory
  String unloadingLrPath; // stamped LR from unloading company
  String
      tripPhase; // 'dispatched' → 'loading_docs_uploaded' → 'en_route' → 'unloading_docs_uploaded' → 'completed'
  String driverFcmToken; // driver's FCM token for push notifications
  TripLedger(
      {required this.id,
      required this.date,
      required this.partyName,
      required this.vehicleNo,
      required this.route,
      required this.ownership,
      this.eWayBillNo = "PENDING",
      this.materialName = "General Goods",
      this.loadingPoint = "",
      this.unloadingPoint = "",
      this.loadingState = "",
      this.unloadingState = "",
      this.consignorPhone = "",
      this.consignorEmail = "",
      this.consignorGstin = "",
      required this.freightBilled,
      this.paymentReceived = 0,
      this.diesel = 0,
      this.toll = 0,
      this.driverExp = 0,
      this.materialLoss = 0,
      this.marketTruckFreight = 0,
      this.marketAdvancePaid = 0,
      this.penalties = 0,
      this.tdsDeduction = 0,
      this.distanceKm = 0,
      this.fuelEconomy = 3.5,
      this.routeDistanceSavedKm = 0,
      this.routeDieselSavedL = 0,
      this.routeCo2SavedKg = 0,
      this.driverName,
      this.paymentTermsDays = 30,
      this.lrNotes = "",
      this.gstType = GstType.none,
      this.gstRate = 0,
      this.isGstInclusive = false,
      this.weightTons = 0,
      this.weightUnit = "MT",
      this.dispatchedAt = "",
      this.estimatedArrival = "",
      this.isInTransit = false,
      this.platformCommission = 0,
      this.consignorCommission = 0,
      this.loadingDocPath = '',
      this.unloadingLrPath = '',
      this.tripPhase = '',
      this.driverFcmToken = '',
      List<InvoiceItem>? invoiceItems,
      this.materialInvoiceNo = ""})
      : invoiceItems = invoiceItems ?? [];

  double get gstAmount {
    if (gstType == GstType.none) return 0;
    return isGstInclusive
        ? freightBilled - (freightBilled / (1 + gstRate / 100))
        : freightBilled * gstRate / 100;
  }

  double get taxableFreight => isGstInclusive && gstRate > 0
      ? (freightBilled / (1 + gstRate / 100))
      : freightBilled;
  double get selfExpenses => diesel + toll + driverExp + materialLoss;
  double get platformCommissionTotal =>
      platformCommission + consignorCommission;
  double get tripProfit => ownership == VehicleOwnership.self
      ? (freightBilled -
          selfExpenses -
          penalties -
          tdsDeduction -
          platformCommission)
      : (freightBilled -
          marketTruckFreight -
          materialLoss -
          platformCommission);
  double get partyPending =>
      freightBilled - paymentReceived - tdsDeduction - penalties;

  DateTime? get paymentDueDate {
    try {
      final p = date.split('/');
      return DateTime(int.parse(p[2]), int.parse(p[1]), int.parse(p[0]))
          .add(Duration(days: paymentTermsDays));
    } catch (_) {
      return null;
    }
  }

  bool get isPaymentOverdue {
    final d = paymentDueDate;
    return d != null && partyPending > 0 && DateTime.now().isAfter(d);
  }

  bool get isDueSoon {
    final d = paymentDueDate;
    if (d == null || partyPending <= 0) return false;
    final diff = d.difference(DateTime.now()).inDays;
    return diff >= 0 && diff <= AppConfig.paymentAlertDays;
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'date': date,
        'partyName': partyName,
        'vehicleNo': vehicleNo,
        'route': route,
        'ownership': ownership.index,
        'eWayBillNo': eWayBillNo,
        'materialName': materialName,
        'loadingPoint': loadingPoint,
        'unloadingPoint': unloadingPoint,
        'loadingState': loadingState,
        'unloadingState': unloadingState,
        'consignorPhone': consignorPhone,
        'consignorEmail': consignorEmail,
        'consignorGstin': consignorGstin,
        'freightBilled': freightBilled,
        'paymentReceived': paymentReceived,
        'diesel': diesel,
        'toll': toll,
        'driverExp': driverExp,
        'materialLoss': materialLoss,
        'marketTruckFreight': marketTruckFreight,
        'marketAdvancePaid': marketAdvancePaid,
        'penalties': penalties,
        'tdsDeduction': tdsDeduction,
        'distanceKm': distanceKm,
        'fuelEconomy': fuelEconomy,
        'routeDistanceSavedKm': routeDistanceSavedKm,
        'routeDieselSavedL': routeDieselSavedL,
        'routeCo2SavedKg': routeCo2SavedKg,
        'driverName': driverName,
        'paymentTermsDays': paymentTermsDays,
        'lrNotes': lrNotes,
        'gstType': gstType.index,
        'gstRate': gstRate,
        'isGstInclusive': isGstInclusive,
        'weightTons': weightTons,
        'weightUnit': weightUnit,
        'dispatchedAt': dispatchedAt,
        'estimatedArrival': estimatedArrival,
        'isInTransit': isInTransit,
        'platformCommission': platformCommission,
        'consignorCommission': consignorCommission,
        'loadingDocPath': loadingDocPath,
        'unloadingLrPath': unloadingLrPath,
        'tripPhase': tripPhase,
        'driverFcmToken': driverFcmToken,
        'materialInvoiceNo': materialInvoiceNo,
        'invoiceItems': invoiceItems.map((i) => i.toJson()).toList()
      };
  factory TripLedger.fromJson(Map<String, dynamic> j) => TripLedger(
      id: j['id'] ?? "TRP${math.Random().nextInt(9999)}",
      date: j['date'] ?? "",
      partyName: j['partyName'] ?? "",
      vehicleNo: j['vehicleNo'] ?? "",
      route: j['route'] ?? "",
      ownership: VehicleOwnership.values[j['ownership'] ?? 0],
      eWayBillNo: j['eWayBillNo'] ?? "PENDING",
      materialName: j['materialName'] ?? "General Goods",
      loadingPoint: j['loadingPoint'] ?? "",
      unloadingPoint: j['unloadingPoint'] ?? "",
      loadingState: j['loadingState'] ?? "",
      unloadingState: j['unloadingState'] ?? "",
      consignorPhone: j['consignorPhone'] ?? "",
      consignorEmail: j['consignorEmail'] ?? "",
      consignorGstin: j['consignorGstin'] ?? "",
      freightBilled: (j['freightBilled'] as num? ?? 0).toDouble(),
      paymentReceived: (j['paymentReceived'] as num? ?? 0).toDouble(),
      diesel: (j['diesel'] as num? ?? 0).toDouble(),
      toll: (j['toll'] as num? ?? 0).toDouble(),
      driverExp: (j['driverExp'] as num? ?? 0).toDouble(),
      materialLoss: (j['materialLoss'] as num? ?? 0).toDouble(),
      marketTruckFreight: (j['marketTruckFreight'] as num? ?? 0).toDouble(),
      marketAdvancePaid: (j['marketAdvancePaid'] as num? ?? 0).toDouble(),
      penalties: (j['penalties'] as num? ?? 0).toDouble(),
      tdsDeduction: (j['tdsDeduction'] as num? ?? 0).toDouble(),
      distanceKm: (j['distanceKm'] as num? ?? 0).toDouble(),
      fuelEconomy: (j['fuelEconomy'] as num? ?? 3.5).toDouble(),
      routeDistanceSavedKm: (j['routeDistanceSavedKm'] as num? ?? 0).toDouble(),
      routeDieselSavedL: (j['routeDieselSavedL'] as num? ?? 0).toDouble(),
      routeCo2SavedKg: (j['routeCo2SavedKg'] as num? ?? 0).toDouble(),
      driverName: j['driverName'],
      paymentTermsDays: j['paymentTermsDays'] ?? 30,
      lrNotes: j['lrNotes'] ?? "",
      gstType: GstType.values[j['gstType'] ?? 0],
      gstRate: (j['gstRate'] as num? ?? 0).toDouble(),
      isGstInclusive: j['isGstInclusive'] ?? false,
      weightTons: (j['weightTons'] as num? ?? 0).toDouble(),
      weightUnit: j['weightUnit'] ?? "MT",
      dispatchedAt: j['dispatchedAt'] ?? '',
      estimatedArrival: j['estimatedArrival'] ?? '',
      isInTransit: j['isInTransit'] ?? false,
      platformCommission: (j['platformCommission'] as num? ?? 0).toDouble(),
      loadingDocPath: j['loadingDocPath'] ?? '',
      unloadingLrPath: j['unloadingLrPath'] ?? '',
      tripPhase: j['tripPhase'] ?? '',
      driverFcmToken: j['driverFcmToken'] ?? '',
      materialInvoiceNo: j['materialInvoiceNo'] ?? '',
      invoiceItems: (j['invoiceItems'] as List? ?? [])
          .map((i) => InvoiceItem.fromJson(i))
          .toList());

  Null get totalAdjustmentDeductions => null;

  Null get totalAdjustmentAdditions => null;

  bool? get isPaymentDue => null;

  Null get lrNumber => null;

  Iterable<Object?>? get adjustments => null;
}

class FleetDoc {
  String name;
  bool isUploaded;
  String expiryDate;
  String fileData;
  String filePath;
  String mimeType;
  // Extra extracted fields
  String engineNo;
  String chassisNo;
  String regNo;
  String ownerName;
  String insurer;
  String remarks;
  FleetDoc(
      {required this.name,
      this.isUploaded = false,
      this.expiryDate = "Pending",
      this.fileData = "",
      this.filePath = "",
      this.mimeType = "",
      this.engineNo = "",
      this.chassisNo = "",
      this.regNo = "",
      this.ownerName = "",
      this.insurer = "",
      this.remarks = ""});
  Map<String, dynamic> toJson() => {
        'name': name,
        'isUploaded': isUploaded,
        'expiryDate': expiryDate,
        'fileData': fileData,
        'filePath': filePath,
        'mimeType': mimeType,
        'engineNo': engineNo,
        'chassisNo': chassisNo,
        'regNo': regNo,
        'ownerName': ownerName,
        'insurer': insurer,
        'remarks': remarks
      };
  factory FleetDoc.fromJson(Map<String, dynamic> j) => FleetDoc(
      name: j['name'],
      isUploaded: j['isUploaded'] ?? false,
      expiryDate: j['expiryDate'] ?? "Pending",
      fileData: j['fileData'] ?? "",
      filePath: j['filePath'] ?? "",
      mimeType: j['mimeType'] ?? "",
      engineNo: j['engineNo'] ?? "",
      chassisNo: j['chassisNo'] ?? "",
      regNo: j['regNo'] ?? "",
      ownerName: j['ownerName'] ?? "",
      insurer: j['insurer'] ?? "",
      remarks: j['remarks'] ?? "");
}

class ComplianceVaultItem {
  String id, vehicleNo, documentName, expiryDate, filePath, storageUrl;
  bool alertScheduled;
  ComplianceVaultItem(
      {required this.id,
      required this.vehicleNo,
      required this.documentName,
      required this.expiryDate,
      this.filePath = "",
      this.storageUrl = "",
      this.alertScheduled = false});

  DateTime? get expiry {
    try {
      final p = expiryDate.split('/');
      if (p.length != 3) return null;
      return DateTime(int.parse(p[2]), int.parse(p[1]), int.parse(p[0]));
    } catch (_) {
      return null;
    }
  }

  int? get daysToExpiry {
    final d = expiry;
    if (d == null) return null;
    return d.difference(DateTime.now()).inDays;
  }

  bool get isCritical => (daysToExpiry ?? 9999) <= 15;
  bool get isDueSoon => (daysToExpiry ?? 9999) <= 45;

  Map<String, dynamic> toJson() => {
        'id': id,
        'vehicleNo': vehicleNo,
        'documentName': documentName,
        'expiryDate': expiryDate,
        'filePath': filePath,
        'storageUrl': storageUrl,
        'alertScheduled': alertScheduled
      };
  factory ComplianceVaultItem.fromJson(Map<String, dynamic> j) =>
      ComplianceVaultItem(
          id: j['id'] ?? '',
          vehicleNo: j['vehicleNo'] ?? '',
          documentName: j['documentName'] ?? '',
          expiryDate: j['expiryDate'] ?? '',
          filePath: j['filePath'] ?? '',
          storageUrl: j['storageUrl'] ?? '',
          alertScheduled: j['alertScheduled'] ?? false);
}

class TripExpenseReceipt {
  String id, ledgerId, driverName, receiptNo, imagePath, capturedAt, auditNote;
  ExpenseReceiptType type;
  double amount;
  bool tallyPosted;
  TripExpenseReceipt(
      {required this.id,
      required this.ledgerId,
      required this.driverName,
      required this.type,
      required this.amount,
      this.receiptNo = '',
      this.imagePath = '',
      required this.capturedAt,
      this.auditNote = '',
      this.tallyPosted = false});

  Map<String, dynamic> toTallyVoucherJson(TripLedger ledger) => {
        'voucherType':
            type == ExpenseReceiptType.fuel ? 'Fuel Expense' : 'Trip Expense',
        'ledgerId': ledger.id,
        'partyName': ledger.partyName,
        'vehicleNo': ledger.vehicleNo,
        'driverName': driverName,
        'receiptNo': receiptNo,
        'amount': amount,
        'date': capturedAt,
        'narration': auditNote.isEmpty
            ? '${type.name.toUpperCase()} receipt for ${ledger.route}'
            : auditNote
      };

  Map<String, dynamic> toJson() => {
        'id': id,
        'ledgerId': ledgerId,
        'driverName': driverName,
        'type': type.index,
        'amount': amount,
        'receiptNo': receiptNo,
        'imagePath': imagePath,
        'capturedAt': capturedAt,
        'auditNote': auditNote,
        'tallyPosted': tallyPosted
      };
  factory TripExpenseReceipt.fromJson(Map<String, dynamic> j) =>
      TripExpenseReceipt(
          id: j['id'] ?? '',
          ledgerId: j['ledgerId'] ?? '',
          driverName: j['driverName'] ?? '',
          type: ExpenseReceiptType.values[j['type'] ?? 0],
          amount: (j['amount'] as num? ?? 0).toDouble(),
          receiptNo: j['receiptNo'] ?? '',
          imagePath: j['imagePath'] ?? '',
          capturedAt: j['capturedAt'] ?? '',
          auditNote: j['auditNote'] ?? '',
          tallyPosted: j['tallyPosted'] ?? false);
}

class PodBillingEvent {
  String id, ledgerId, podImagePath, documentNo, scannedAt, gstInvoiceNo;
  PodBillingStatus status;
  PodBillingEvent(
      {required this.id,
      required this.ledgerId,
      this.podImagePath = '',
      this.documentNo = '',
      required this.scannedAt,
      this.gstInvoiceNo = '',
      this.status = PodBillingStatus.scanned});

  Map<String, dynamic> toGstInvoiceJson(TripLedger ledger) => {
        'invoiceNo': gstInvoiceNo,
        'invoiceDate': scannedAt,
        'partyName': ledger.partyName,
        'partyGstin': ledger.consignorGstin,
        'route': ledger.route,
        'vehicleNo': ledger.vehicleNo,
        'taxableValue': ledger.taxableFreight,
        'gstRate': ledger.gstRate,
        'gstAmount': ledger.gstAmount,
        'invoiceTotal': ledger.taxableFreight + ledger.gstAmount,
        'podDocumentNo': documentNo,
        'ledgerId': ledger.id
      };

  Map<String, dynamic> toJson() => {
        'id': id,
        'ledgerId': ledgerId,
        'podImagePath': podImagePath,
        'documentNo': documentNo,
        'scannedAt': scannedAt,
        'gstInvoiceNo': gstInvoiceNo,
        'status': status.index
      };
  factory PodBillingEvent.fromJson(Map<String, dynamic> j) => PodBillingEvent(
      id: j['id'] ?? '',
      ledgerId: j['ledgerId'] ?? '',
      podImagePath: j['podImagePath'] ?? '',
      documentNo: j['documentNo'] ?? '',
      scannedAt: j['scannedAt'] ?? '',
      gstInvoiceNo: j['gstInvoiceNo'] ?? '',
      status: PodBillingStatus.values[j['status'] ?? 0]);
}

class GlassPipelineLink {
  String id, ledgerId, signedToken, expiresAt, createdAt;
  bool isRevoked;
  GlassPipelineLink(
      {required this.id,
      required this.ledgerId,
      required this.signedToken,
      required this.expiresAt,
      required this.createdAt,
      this.isRevoked = false});

  bool get isActive =>
      !isRevoked &&
      DateTime.now().isBefore(DateTime.tryParse(expiresAt) ?? DateTime.now());
  String trackingUrl(String baseUrl) => '$baseUrl/track/$signedToken';

  Map<String, dynamic> toJson() => {
        'id': id,
        'ledgerId': ledgerId,
        'signedToken': signedToken,
        'expiresAt': expiresAt,
        'createdAt': createdAt,
        'isRevoked': isRevoked
      };
  factory GlassPipelineLink.fromJson(Map<String, dynamic> j) =>
      GlassPipelineLink(
          id: j['id'] ?? '',
          ledgerId: j['ledgerId'] ?? '',
          signedToken: j['signedToken'] ?? '',
          expiresAt: j['expiresAt'] ?? '',
          createdAt: j['createdAt'] ?? '',
          isRevoked: j['isRevoked'] ?? false);
}

class MaintenanceTicket {
  String id, vehicleNo, driverName, issue, photoPath, createdAt, status;
  int odometerKm, dueAtKm;
  BreakdownPriority priority;
  MaintenanceTicket(
      {required this.id,
      required this.vehicleNo,
      this.driverName = '',
      required this.issue,
      this.photoPath = '',
      required this.createdAt,
      this.status = 'open',
      this.odometerKm = 0,
      this.dueAtKm = 0,
      this.priority = BreakdownPriority.service});

  bool get isServiceDue => dueAtKm > 0 && odometerKm >= dueAtKm;
  bool get isSos => priority == BreakdownPriority.sos;

  Map<String, dynamic> toJson() => {
        'id': id,
        'vehicleNo': vehicleNo,
        'driverName': driverName,
        'issue': issue,
        'photoPath': photoPath,
        'createdAt': createdAt,
        'status': status,
        'odometerKm': odometerKm,
        'dueAtKm': dueAtKm,
        'priority': priority.index
      };
  factory MaintenanceTicket.fromJson(Map<String, dynamic> j) =>
      MaintenanceTicket(
          id: j['id'] ?? '',
          vehicleNo: j['vehicleNo'] ?? '',
          driverName: j['driverName'] ?? '',
          issue: j['issue'] ?? '',
          photoPath: j['photoPath'] ?? '',
          createdAt: j['createdAt'] ?? '',
          status: j['status'] ?? 'open',
          odometerKm: j['odometerKm'] ?? 0,
          dueAtKm: j['dueAtKm'] ?? 0,
          priority: BreakdownPriority.values[j['priority'] ?? 0]);
}

class RouteMasterModuleState {
  List<ComplianceVaultItem> complianceVault;
  List<TripExpenseReceipt> expenseReceipts;
  List<PodBillingEvent> podBilling;
  List<GlassPipelineLink> glassPipelineLinks;
  List<MaintenanceTicket> maintenanceTickets;
  // Promoted from BankImportScreen so AI and all screens share the same list
  List<BankEntry> bankEntries;
  RouteMasterModuleState(
      {List<ComplianceVaultItem>? complianceVault,
      List<TripExpenseReceipt>? expenseReceipts,
      List<PodBillingEvent>? podBilling,
      List<GlassPipelineLink>? glassPipelineLinks,
      List<MaintenanceTicket>? maintenanceTickets,
      List<BankEntry>? bankEntries})
      : complianceVault = complianceVault ?? [],
        expenseReceipts = expenseReceipts ?? [],
        podBilling = podBilling ?? [],
        glassPipelineLinks = glassPipelineLinks ?? [],
        maintenanceTickets = maintenanceTickets ?? [],
        bankEntries = bankEntries ?? [];

  Map<String, dynamic> toJson() => {
        'complianceVault': complianceVault.map((e) => e.toJson()).toList(),
        'expenseReceipts': expenseReceipts.map((e) => e.toJson()).toList(),
        'podBilling': podBilling.map((e) => e.toJson()).toList(),
        'glassPipelineLinks':
            glassPipelineLinks.map((e) => e.toJson()).toList(),
        'maintenanceTickets': maintenanceTickets.map((e) => e.toJson()).toList()
      };

  factory RouteMasterModuleState.fromJson(
          Map<String, dynamic> j) =>
      RouteMasterModuleState(
          complianceVault:
              (j['complianceVault']
                          as List? ??
                      [])
                  .map((e) => ComplianceVaultItem.fromJson(e))
                  .toList(),
          expenseReceipts:
              (j[
                          'expenseReceipts'] as List? ??
                      [])
                  .map((e) => TripExpenseReceipt.fromJson(e))
                  .toList(),
          podBilling: (j['podBilling'] as List? ?? [])
              .map((e) => PodBillingEvent.fromJson(e))
              .toList(),
          glassPipelineLinks: (j['glassPipelineLinks'] as List? ?? [])
              .map((e) => GlassPipelineLink.fromJson(e))
              .toList(),
          maintenanceTickets: (j['maintenanceTickets'] as List? ?? [])
              .map((e) => MaintenanceTicket.fromJson(e))
              .toList());

  factory RouteMasterModuleState.seedFrom(
      List<TripLedger> ledgers, List<Asset> fleet) {
    final state = RouteMasterModuleState();
    for (final a in fleet) {
      for (final d in a.docs.where((doc) => doc.isUploaded)) {
        state.complianceVault.add(ComplianceVaultItem(
            id: '${a.id}_${d.name}'.replaceAll(' ', '_'),
            vehicleNo: a.number,
            documentName: d.name,
            expiryDate: d.expiryDate,
            filePath: d.filePath));
      }
    }
    for (final l in ledgers.where((e) => e.isInTransit).take(5)) {
      state.glassPipelineLinks.add(RouteMasterOps.createGlassPipelineLink(l));
    }
    return state;
  }
}

class RouteMasterOps {
  static String _stamp() => DateTime.now().toIso8601String();

  static GlassPipelineLink createGlassPipelineLink(TripLedger ledger,
      {Duration ttl = const Duration(days: 7)}) {
    final raw =
        '${ledger.id}:${ledger.vehicleNo}:${DateTime.now().microsecondsSinceEpoch}';
    return GlassPipelineLink(
        id: 'GPL${DateTime.now().millisecondsSinceEpoch}',
        ledgerId: ledger.id,
        signedToken: base64Url.encode(utf8.encode(raw)).replaceAll('=', ''),
        createdAt: _stamp(),
        expiresAt: DateTime.now().add(ttl).toIso8601String());
  }

  static void syncExpenseToLedger(
      TripLedger ledger, TripExpenseReceipt receipt) {
    switch (receipt.type) {
      case ExpenseReceiptType.toll:
        ledger.toll += receipt.amount;
        break;
      case ExpenseReceiptType.fuel:
        ledger.diesel += receipt.amount;
        break;
      case ExpenseReceiptType.driverAdvance:
        ledger.driverExp += receipt.amount;
        break;
      case ExpenseReceiptType.repair:
      case ExpenseReceiptType.other:
        ledger.materialLoss += receipt.amount;
        break;
    }
    receipt.tallyPosted = true;
  }

  static PodBillingEvent createPodInvoice(TripLedger ledger,
      {String podImagePath = '', String documentNo = ''}) {
    final now = DateTime.now();
    final invoiceNo = 'GST-${now.year}-${ledger.id}';
    ledger.isInTransit = false;
    return PodBillingEvent(
        id: 'POD${now.millisecondsSinceEpoch}',
        ledgerId: ledger.id,
        podImagePath: podImagePath,
        documentNo: documentNo,
        scannedAt: now.toIso8601String(),
        gstInvoiceNo: invoiceNo,
        status: PodBillingStatus.invoiceDrafted);
  }

  static MaintenanceTicket createServiceTicket(Asset asset, int odometerKm,
          {String issue = 'Preventative service due',
          int serviceIntervalKm = 10000}) =>
      MaintenanceTicket(
          id: 'MNT${DateTime.now().millisecondsSinceEpoch}',
          vehicleNo: asset.number,
          issue: issue,
          createdAt: _stamp(),
          odometerKm: odometerKm,
          dueAtKm: ((odometerKm ~/ serviceIntervalKm) + 1) * serviceIntervalKm,
          priority: BreakdownPriority.service);
}

class Asset {
  String id, number, type, payload;
  int tyreCount, axleCount;
  List<String> tyreSerials;
  List<Battery> batteries;
  List<FleetDoc> docs;
  String ownerName, ownerPhone;
  String
      fuelType; // 'Diesel' | 'CNG' | 'Electric' | 'LNG' | 'Hydrogen' | 'Hybrid'
  Asset(
      {required this.id,
      required this.number,
      required this.type,
      required this.payload,
      required this.tyreCount,
      required this.tyreSerials,
      required this.batteries,
      required this.docs,
      this.axleCount = 6,
      this.ownerName = "",
      this.ownerPhone = "",
      this.fuelType = "Diesel"});
  Map<String, dynamic> toJson() => {
        'id': id,
        'number': number,
        'type': type,
        'payload': payload,
        'tyreCount': tyreCount,
        'axleCount': axleCount,
        'tyreSerials': tyreSerials,
        'batteries': batteries.map((b) => (b).toJson()).toList(),
        'docs': docs.map((d) => (d).toJson()).toList(),
        'ownerName': ownerName,
        'ownerPhone': ownerPhone,
        'fuelType': fuelType,
      };
  factory Asset.fromJson(Map<String, dynamic> j) => Asset(
      id: j['id'],
      number: j['number'],
      type: j['type'],
      payload: j['payload'],
      tyreCount: j['tyreCount'],
      axleCount: j['axleCount'] ?? 6,
      tyreSerials: List<String>.from(j['tyreSerials']),
      batteries: j['batteries'] != null
          ? (j['batteries'] as List).map((b) => Battery.fromJson(b)).toList()
          : [],
      docs: j['docs'] != null
          ? (j['docs'] as List).map((d) => FleetDoc.fromJson(d)).toList()
          : [],
      ownerName: j['ownerName'] ?? "",
      ownerPhone: j['ownerPhone'] ?? "",
      fuelType: j['fuelType'] ?? "Diesel");
}

class MarketLoad {
  String id, route, details, vehicleType, materialType, postedDate;
  String originCity,
      originState,
      destCity,
      destState,
      originFactory,
      destFactory;
  double targetPrice, weightTons;
  BidStatus status;
  // New fields
  bool isBulk; // bulk booking flag — different priority badge
  String postedByUid; // who posted this load
  String postedByName; // display name of poster
  bool isVerifiedPoster; // poster has verified KYC
  List<Map<String, dynamic>> bids; // [{uid, name, amount, time}]
  String bookedByUid; // who booked/bid successfully
  String bookedByName;
  String bookedVehicleNo; // vehicle selected at booking
  String bookedDriverName; // driver selected at booking
  String consignorApproval; // 'pending', 'approved', 'rejected'

  MarketLoad(
      {required this.id,
      required this.route,
      required this.details,
      required this.vehicleType,
      required this.targetPrice,
      this.status = BidStatus.pending,
      this.materialType = "",
      this.postedDate = "",
      this.originCity = "",
      this.originState = "",
      this.destCity = "",
      this.destState = "",
      this.originFactory = "",
      this.destFactory = "",
      this.weightTons = 0,
      this.isBulk = false,
      this.postedByUid = "",
      this.postedByName = "",
      this.isVerifiedPoster = false,
      this.bids = const [],
      this.bookedByUid = "",
      this.bookedByName = "",
      this.bookedVehicleNo = "",
      this.bookedDriverName = "",
      this.consignorApproval = ""});
  Map<String, dynamic> toJson() => {
        'id': id,
        'route': route,
        'details': details,
        'vehicleType': vehicleType,
        'targetPrice': targetPrice,
        'status': status.index,
        'materialType': materialType,
        'postedDate': postedDate,
        'originCity': originCity,
        'originState': originState,
        'destCity': destCity,
        'destState': destState,
        'originFactory': originFactory,
        'destFactory': destFactory,
        'weightTons': weightTons,
        'isBulk': isBulk,
        'postedByUid': postedByUid,
        'postedByName': postedByName,
        'isVerifiedPoster': isVerifiedPoster,
        'bids': bids,
        'bookedByUid': bookedByUid,
        'bookedByName': bookedByName,
        'bookedVehicleNo': bookedVehicleNo,
        'bookedDriverName': bookedDriverName,
        'consignorApproval': consignorApproval,
      };
  factory MarketLoad.fromJson(Map<String, dynamic> j) => MarketLoad(
      id: j['id'],
      route: j['route'],
      details: j['details'],
      vehicleType: j['vehicleType'],
      targetPrice: (j['targetPrice'] as num).toDouble(),
      status: BidStatus.values.firstWhere(
          (e) => e.index == (j['status'] as int? ?? 0),
          orElse: () => BidStatus.pending),
      materialType: j['materialType'] ?? "",
      postedDate: j['postedDate'] ?? "",
      originCity: j['originCity'] ?? "",
      originState: j['originState'] ?? "",
      destCity: j['destCity'] ?? "",
      destState: j['destState'] ?? "",
      originFactory: j['originFactory'] ?? "",
      destFactory: j['destFactory'] ?? "",
      weightTons: (j['weightTons'] as num? ?? 0).toDouble(),
      isBulk: j['isBulk'] as bool? ?? false,
      postedByUid: j['postedByUid'] ?? "",
      postedByName: j['postedByName'] ?? "",
      isVerifiedPoster: j['isVerifiedPoster'] as bool? ?? false,
      bids: (j['bids'] as List<dynamic>? ?? []).cast<Map<String, dynamic>>(),
      bookedByUid: j['bookedByUid'] ?? "",
      bookedByName: j['bookedByName'] ?? "",
      bookedVehicleNo: j['bookedVehicleNo'] ?? "",
      bookedDriverName: j['bookedDriverName'] ?? "",
      consignorApproval: j['consignorApproval'] ?? "");
}

// ================================================================
// ROUTING ENGINE
// ================================================================

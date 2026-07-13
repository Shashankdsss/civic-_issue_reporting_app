import 'package:flutter/material.dart';

class GlobalState {
  static final ValueNotifier<ThemeMode> themeNotifier =
      ValueNotifier(ThemeMode.light);
  static final ValueNotifier<String> languageNotifier =
      ValueNotifier('English');
}

const Map<String, Map<String, String>> _t = {
  // ── Navigation ──────────────────────────────────────────
  'Home': {'Hindi': 'होम', 'Marathi': 'मुख्यपृष्ठ', 'Kannada': 'ಮುಖಪುಟ', 'Tamil': 'முகப்பு', 'Telugu': 'హోమ్'},
  'Map': {'Hindi': 'नक्शा', 'Marathi': 'नकाशा', 'Kannada': 'ನಕ್ಷೆ', 'Tamil': 'வரைபடம்', 'Telugu': 'మ్యాప్'},
  'Community': {'Hindi': 'समुदाय', 'Marathi': 'समुदाय', 'Kannada': 'ಸಮುದಾಯ', 'Tamil': 'சமூகம்', 'Telugu': 'సముదాయం'},
  'History': {'Hindi': 'इतिहास', 'Marathi': 'इतिहास', 'Kannada': 'ಇತಿಹಾಸ', 'Tamil': 'வரலாறு', 'Telugu': 'చరిత్ర'},
  'Profile': {'Hindi': 'प्रोफ़ाइल', 'Marathi': 'प्रोफाइल', 'Kannada': 'ಪ್ರೊಫೈಲ್', 'Tamil': 'சுயவிவரம்', 'Telugu': 'ప్రొఫైల్'},
  // ── Home Screen ─────────────────────────────────────────
  'Locality Overview': {'Hindi': 'स्थानीय अवलोकन', 'Marathi': 'स्थानिक आढावा', 'Kannada': 'ಸ್ಥಳೀಯ ಸಾರಾಂಶ', 'Tamil': 'உள்ளூர் கண்ணோட்டம்', 'Telugu': 'స్థానిక అవలోకనం'},
  'Total reported': {'Hindi': 'कुल रिपोर्ट', 'Marathi': 'एकूण तक्रारी', 'Kannada': 'ಒಟ್ಟು ವರದಿಗಳು', 'Tamil': 'மொத்த புகார்கள்', 'Telugu': 'మొత్తం నివేదికలు'},
  'In progress': {'Hindi': 'प्रगति में', 'Marathi': 'प्रगतीत', 'Kannada': 'ಪ್ರಗತಿಯಲ್ಲಿದೆ', 'Tamil': 'செயல்பாட்டில்', 'Telugu': 'పురోగతిలో'},
  'Resolved': {'Hindi': 'हल हुआ', 'Marathi': 'सोडवले', 'Kannada': 'ಪರಿಹರಿಸಲಾಗಿದೆ', 'Tamil': 'தீர்க்கப்பட்டது', 'Telugu': 'పరిష్కరించబడింది'},
  'Report an Issue': {'Hindi': 'समस्या सूचित करें', 'Marathi': 'समस्या नोंदवा', 'Kannada': 'ಸಮಸ್ಯೆ ವರದಿ ಮಾಡಿ', 'Tamil': 'சிக்கலை புகாரளிக்க', 'Telugu': 'సమస్యను నివేదించు'},
  'Community Health': {'Hindi': 'सामुदायिक स्वास्थ्य', 'Marathi': 'सामुदायिक आरोग्य', 'Kannada': 'ಸಮುದಾಯ ಆರೋಗ್ಯ', 'Tamil': 'சமூக ஆரோக்கியம்', 'Telugu': 'సముదాయ ఆరోగ్యం'},
  // ── Profile Screen ───────────────────────────────────────
  'App Preferences': {'Hindi': 'ऐप प्राथमिकताएं', 'Marathi': 'अॅप प्राधान्ये', 'Kannada': 'ಅಪ್ಲಿಕೇಶನ್ ಆದ್ಯತೆಗಳು', 'Tamil': 'பயன்பாட்டு விருப்பங்கள்', 'Telugu': 'యాప్ ప్రాధాన్యతలు'},
  'Support & About': {'Hindi': 'समर्थन और जानकारी', 'Marathi': 'समर्थन आणि माहिती', 'Kannada': 'ಬೆಂಬಲ ಮತ್ತು ಬಗ್ಗೆ', 'Tamil': 'ஆதரவு மற்றும் பற்றி', 'Telugu': 'మద్దతు మరియు గురించి'},
  'Dark Mode': {'Hindi': 'डार्क मोड', 'Marathi': 'डार्क मोड', 'Kannada': 'ಡಾರ್ಕ್ ಮೋಡ್', 'Tamil': 'இருண்ட பயன்முறை', 'Telugu': 'డార్క్ మోడ్'},
  'Language': {'Hindi': 'भाषा', 'Marathi': 'भाषा', 'Kannada': 'ಭಾಷೆ', 'Tamil': 'மொழி', 'Telugu': 'భాష'},
  'Push Notifications': {'Hindi': 'सूचनाएं', 'Marathi': 'सूचना', 'Kannada': 'ಅಧಿಸೂಚನೆಗಳು', 'Tamil': 'அறிவிப்புகள்', 'Telugu': 'నోటిఫికేషన్లు'},
  'Help & Support': {'Hindi': 'सहायता', 'Marathi': 'मदत आणि समर्थन', 'Kannada': 'ಸಹಾಯ ಮತ್ತು ಬೆಂಬಲ', 'Tamil': 'உதவி மற்றும் ஆதரவு', 'Telugu': 'సహాయం మరియు మద్దతు'},
  'Privacy Policy': {'Hindi': 'गोपनीयता नीति', 'Marathi': 'गोपनीयता धोरण', 'Kannada': 'ಗೌಪ್ಯ ನೀತಿ', 'Tamil': 'தனியுரிமைக் கொள்கை', 'Telugu': 'గోప్యతా విధానం'},
  'Terms of Service': {'Hindi': 'सेवा की शर्तें', 'Marathi': 'सेवेच्या अटी', 'Kannada': 'ಸೇವಾ ನಿಯಮಗಳು', 'Tamil': 'சேவை விதிமுறைகள்', 'Telugu': 'సేవా నిబంధనలు'},
  'Personal Information': {'Hindi': 'व्यक्तिगत जानकारी', 'Marathi': 'वैयक्तिक माहिती', 'Kannada': 'ವೈಯಕ್ತಿಕ ಮಾಹಿತಿ', 'Tamil': 'தனிப்பட்ட தகவல்', 'Telugu': 'వ్యక్తిగత సమాచారం'},
  'Account Information': {'Hindi': 'खाता जानकारी', 'Marathi': 'खाते माहिती', 'Kannada': 'ಖಾತೆ ಮಾಹಿತಿ', 'Tamil': 'கணக்கு தகவல்', 'Telugu': 'ఖాతా సమాచారం'},
  'Sign Out': {'Hindi': 'साइन आउट', 'Marathi': 'साइन आउट', 'Kannada': 'ಸೈನ್ ಔಟ್', 'Tamil': 'வெளியேறு', 'Telugu': 'సైన్ అవుట్'},
  // ── Report Screen ─────────────────────────────────────────
  'Report Issue': {'Hindi': 'समस्या रिपोर्ट करें', 'Marathi': 'समस्या नोंदवा', 'Kannada': 'ಸಮಸ್ಯೆ ವರದಿ ಮಾಡಿ', 'Tamil': 'சிக்கலை புகாரளிக்க', 'Telugu': 'సమస్యను నివేదించు'},
  'Submit': {'Hindi': 'जमा करें', 'Marathi': 'सादर करा', 'Kannada': 'ಸಲ್ಲಿಸಿ', 'Tamil': 'சமர்ப்பி', 'Telugu': 'సమర్పించు'},
  'Description': {'Hindi': 'विवरण', 'Marathi': 'वर्णन', 'Kannada': 'ವಿವರಣೆ', 'Tamil': 'விளக்கம்', 'Telugu': 'వివరణ'},
  'Add Photo': {'Hindi': 'फ़ोटो जोड़ें', 'Marathi': 'फोटो जोडा', 'Kannada': 'ಫೋಟೋ ಸೇರಿಸಿ', 'Tamil': 'புகைப்படம் சேர்க்க', 'Telugu': 'ఫోటో జోడించు'},
  // ── SOS ──────────────────────────────────────────────────
  'ACCIDENT? REPORT SOS': {'Hindi': 'दुर्घटना? SOS रिपोर्ट करें', 'Marathi': 'अपघात? SOS नोंदवा', 'Kannada': 'ಅಪಘಾತ? SOS ವರದಿ ಮಾಡಿ', 'Tamil': 'விபத்தா? SOS புகாரளிக்க', 'Telugu': 'ప్రమాదమా? SOS నివేదించు'},
  'Select Language': {'Hindi': 'भाषा चुनें', 'Marathi': 'भाषा निवडा', 'Kannada': 'ಭಾಷೆ ಆಯ್ಕೆ ಮಾಡಿ', 'Tamil': 'மொழியை தேர்ந்தெடுக்கவும்', 'Telugu': 'భాషను ఎంచుకోండి'},
};

/// Translates [text] into the user's selected language.
String tr(String text) {
  final lang = GlobalState.languageNotifier.value;
  if (lang == 'English') return text;
  return _t[text]?[lang] ?? text;
}

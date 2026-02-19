import '../models/feast.dart';
import '../models/church.dart';

final List<Feast> mockFeasts = [
  Feast(
    id: '1',
    name: 'የቅዱስ ሚካኤል በዓል',
    shortDescription: 'የመላዕክት አለቃ ቅዱስ ሚካኤል ክብረ በዓል',
    description:
        'ቅዱስ ሚካኤል የመላዕክት አለቃ ሲሆን የእግዚአብሔርን ትእዛዝ የሚፈጽም እና ሰይታንን ከሰማይ የሰደደ ነው። በየወሩ 12 ኛው ቀን የሚከበር ሲሆን ልዩ ክብረ በዓሉ ግን በኅዳር 12 ነው። ቅዱስ ሚካኤል ለሀገረ ኢትዮጵያ ልዩ ጥበቃ እንደሚያደርግ ይታመናል።',
    date: '2026-01-03',
    churches: ['1', '2', '5', '7'],
    isPremium: false,
  ),
  Feast(
    id: '2',
    name: 'የቅድስት ድንግል ማርያም በዓል',
    shortDescription: 'የድንግል ማርያም ክብረ በዓል',
    description:
        'ቅድስት ድንግል ማርያም የእግዚአብሔር እናት እና ለክርስቲያኖች በጣም የምታስተጋብር ቅድስት ናት። በየወሩ 21 ኛው ቀን የሚከበር ሲሆን ሁሉም ቤተክርስቲያናት በታላቅ ክብር ያከብሩታል። ድንግል ማርያም ለሚጸልዩላት ሁሉ ምላሽ እንደምትሰጥ ይታመናል።',
    date: '2026-01-03',
    churches: ['1', '3', '4', '6', '8'],
    isPremium: true,
  ),
  Feast(
    id: '3',
    name: 'የአቡነ ገብረ መንፈስ ቅዱስ በዓል',
    shortDescription: 'የአቡነ ገብረ መንፈስ ቅዱስ የተወለዱበት በዓል',
    description:
        'አቡነ ገብረ መንፈስ ቅዱስ ከታላላቅ የኢትዮጵያ ቅዱሳን አንዱ ሲሆን በድንግል ማርያም ጸሎት ተወልደዋል። በብዙ ተአምራት እና ትምህርት የታወቁ ሲሆን ለኢትዮጵያ ኦርቶዶክስ ቤተክርስቲያን ታላቅ አስተዋጽኦ አድርገዋል።',
    date: '2026-01-03',
    churches: ['2', '5', '8'],
    isPremium: true,
  ),
];

final List<Church> mockChurches = [
  Church(
    id: '1',
    name: 'የቅዱስ ሚካኤል ቤተክርስቲያን',
    address: 'ቦሌ፣ አዲስ አበባ',
    distance: 0.8,
    latitude: 8.9806,
    longitude: 38.7578,
    feasts: ['1'],
  ),
  Church(
    id: '2',
    name: 'የቅዱስ ጊዮርጊስ ካቴድራል',
    address: 'ፒያሳ፣ አዲስ አበባ',
    distance: 1.2,
    latitude: 9.0320,
    longitude: 38.7469,
    feasts: ['1', '3'],
  ),
  Church(
    id: '3',
    name: 'የመድኃኔ ዓለም ቤተክርስቲያን',
    address: 'መርካቶ፣ አዲስ አበባ',
    distance: 1.5,
    latitude: 9.0340,
    longitude: 38.7436,
    feasts: ['2'],
  ),
  Church(
    id: '4',
    name: 'የቅድስት ማርያም ቤተክርስቲያን',
    address: '22 ማዞሪያ፣ አዲስ አበባ',
    distance: 1.8,
    latitude: 9.0054,
    longitude: 38.7636,
    feasts: ['2'],
  ),
  Church(
    id: '5',
    name: 'የመብራት ሃይል ቤተክርስቲያን',
    address: 'ሰሚት፣ አዲስ አበባ',
    distance: 2.1,
    latitude: 9.0118,
    longitude: 38.7925,
    feasts: ['1', '3'],
  ),
  Church(
    id: '6',
    name: 'የእንደራሴ ቤተክርስቲያን',
    address: 'ቂርቆስ፣ አዲስ አበባ',
    distance: 2.4,
    latitude: 9.0250,
    longitude: 38.7380,
    feasts: ['2'],
  ),
  Church(
    id: '7',
    name: 'የሰላም ቤተክርስቲያን',
    address: 'ጀሞ፣ አዲስ አበባ',
    distance: 2.7,
    latitude: 8.9950,
    longitude: 38.7850,
    feasts: ['1'],
  ),
  Church(
    id: '8',
    name: 'የብርሃን ቤተክርስቲያን',
    address: 'ቢሾፍቱ ጎዳና፣ አዲስ አበባ',
    distance: 2.9,
    latitude: 9.0100,
    longitude: 38.7700,
    feasts: ['2', '3'],
  ),
];

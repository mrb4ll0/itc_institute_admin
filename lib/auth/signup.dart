import 'dart:io';
import 'dart:math';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter/material.dart';
import 'package:fluttertoast/fluttertoast.dart';
import 'package:image_picker/image_picker.dart';
import 'package:itc_institute_admin/auth/login_view.dart';
import 'package:itc_institute_admin/generalmethods/GeneralMethods.dart';
import 'package:itc_institute_admin/itc_logic/admin_task.dart';
import 'package:itc_institute_admin/itc_logic/firebase/general_cloud.dart';
import 'package:itc_institute_admin/model/company.dart';
import 'package:itc_institute_admin/view/home/companyDashBoard.dart';

import '../firebase_cloud_storage/firebase_cloud.dart';
import '../model/authority.dart';

class CompanySignupScreen extends StatefulWidget {
  const CompanySignupScreen({super.key});

  @override
  State<CompanySignupScreen> createState() => _CompanySignupScreenState();
}

class _CompanySignupScreenState extends State<CompanySignupScreen> {
  final _formKey = GlobalKey<FormState>();
  final _companyNameController = TextEditingController();
  final _industryController = TextEditingController();
  final _registrationNumberController = TextEditingController();
  final _addressController = TextEditingController();
  final _contactNumberController = TextEditingController();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();
  ITCFirebaseLogic itcFirebaseLogic = ITCFirebaseLogic(FirebaseAuth.instance.currentUser!.uid);

  String? _selectedState;
  String? _selectedLocalGovernment;
  File? _companyLogoFile;
  bool _isPasswordVisible = false;
  bool _isConfirmPasswordVisible = false;
  bool _isLoading = false;
  int _currentStep =
      0; // 0: Company Details, 1: Location, 2: Contact, 3: Account
  FirebaseUploader cloudStorage = FirebaseUploader();



  // Nigerian states and LGAs (simplified version)
  final Map<String, List<String>> _statesAndLgas = {
    'Abia': [
      'Aba North',
      'Aba South',
      'Arochukwu',
      'Bende',
      'Ikwuano',
      'Isiala Ngwa North',
      'Isiala Ngwa South',
      'Isuikwuato',
      'Obi Ngwa',
      'Ohafia',
      'Osisioma',
      'Ugwunagbo',
      'Ukwa East',
      'Ukwa West',
      'Umuahia North',
      'Umuahia South',
      'Umu Nneochi',
    ],
    'Adamawa': [
      'Demsa',
      'Fufure',
      'Ganye',
      'Gayuk',
      'Gombi',
      'Grie',
      'Hong',
      'Jada',
      'Larmurde',
      'Madagali',
      'Maiha',
      'Mayo Belwa',
      'Michika',
      'Mubi North',
      'Mubi South',
      'Numan',
      'Shelleng',
      'Song',
      'Toungo',
      'Yola North',
      'Yola South',
    ],
    'Akwa Ibom': [
      'Abak',
      'Eastern Obolo',
      'Eket',
      'Esit Eket',
      'Essien Udim',
      'Etim Ekpo',
      'Etinan',
      'Ibeno',
      'Ibesikpo Asutan',
      'Ibiono-Ibom',
      'Ikot Abasi',
      'Ikot Ekpene',
      'Ini',
      'Itu',
      'Mbo',
      'Mkpat-Enin',
      'Nsit-Atai',
      'Nsit-Ibom',
      'Nsit-Ubium',
      'Obot Akara',
      'Okobo',
      'Onna',
      'Oron',
      'Oruk Anam',
      'Udung-Uko',
      'Ukanafun',
      'Uruan',
      'Urue-Offong/Oruko',
      'Uyo',
    ],
    'Anambra': [
      'Aguata',
      'Anambra East',
      'Anambra West',
      'Anaocha',
      'Awka North',
      'Awka South',
      'Ayamelum',
      'Dunukofia',
      'Ekwusigo',
      'Idemili North',
      'Idemili South',
      'Ihiala',
      'Njikoka',
      'Nnewi North',
      'Nnewi South',
      'Ogbaru',
      'Onitsha North',
      'Onitsha South',
      'Orumba North',
      'Orumba South',
      'Oyi',
    ],
    'Bauchi': [
      'Alkaleri',
      'Bauchi',
      'Bogoro',
      'Damban',
      'Darazo',
      'Dass',
      'Gamawa',
      'Ganjuwa',
      'Giade',
      'Itas/Gadau',
      'Jama\'are',
      'Katagum',
      'Kirfi',
      'Misau',
      'Ningi',
      'Shira',
      'Tafawa Balewa',
      'Toro',
      'Warji',
      'Zaki',
    ],
    'Bayelsa': [
      'Brass',
      'Ekeremor',
      'Kolokuma/Opokuma',
      'Nembe',
      'Ogbia',
      'Sagbama',
      'Southern Ijaw',
      'Yenagoa',
    ],
    'Benue': [
      'Ado',
      'Agatu',
      'Apa',
      'Buruku',
      'Gboko',
      'Guma',
      'Gwer East',
      'Gwer West',
      'Katsina-Ala',
      'Konshisha',
      'Kwande',
      'Logo',
      'Makurdi',
      'Obi',
      'Ogbadibo',
      'Ohimini',
      'Oju',
      'Okpokwu',
      'Oturkpo',
      'Tarka',
      'Ukum',
      'Ushongo',
      'Vandeikya',
    ],
    'Borno': [
      'Abadam',
      'Askira/Uba',
      'Bama',
      'Bayo',
      'Biu',
      'Chibok',
      'Damboa',
      'Dikwa',
      'Gubio',
      'Guzamala',
      'Gwoza',
      'Hawul',
      'Jere',
      'Kaga',
      'Kala/Balge',
      'Konduga',
      'Kukawa',
      'Kwaya Kusar',
      'Mafa',
      'Magumeri',
      'Maiduguri',
      'Marte',
      'Mobbar',
      'Monguno',
      'Ngala',
      'Nganzai',
      'Shani',
    ],
    'Cross River': [
      'Abi',
      'Akamkpa',
      'Akpabuyo',
      'Bakassi',
      'Bekwarra',
      'Biase',
      'Boki',
      'Calabar Municipal',
      'Calabar South',
      'Etung',
      'Ikom',
      'Obanliku',
      'Obubra',
      'Obudu',
      'Odukpani',
      'Ogoja',
      'Yakuur',
      'Yala',
    ],
    'Delta': [
      'Aniocha North',
      'Aniocha South',
      'Bomadi',
      'Burutu',
      'Ethiope East',
      'Ethiope West',
      'Ika North East',
      'Ika South',
      'Isoko North',
      'Isoko South',
      'Ndokwa East',
      'Ndokwa West',
      'Okpe',
      'Oshimili North',
      'Oshimili South',
      'Patani',
      'Sapele',
      'Udu',
      'Ughelli North',
      'Ughelli South',
      'Ukwuani',
      'Uvwie',
      'Warri North',
      'Warri South',
      'Warri South West',
    ],
    'Ebonyi': [
      'Abakaliki',
      'Afikpo North',
      'Afikpo South',
      'Ebonyi',
      'Ezza North',
      'Ezza South',
      'Ikwo',
      'Ishielu',
      'Ivo',
      'Izzi',
      'Ohaozara',
      'Ohaukwu',
      'Onicha',
    ],
    'Edo': [
      'Akoko-Edo',
      'Egor',
      'Esan Central',
      'Esan North-East',
      'Esan South-East',
      'Esan West',
      'Etsako Central',
      'Etsako East',
      'Etsako West',
      'Igueben',
      'Ikpoba Okha',
      'Orhionmwon',
      'Oredo',
      'Ovia North-East',
      'Ovia South-West',
      'Owan East',
      'Owan West',
      'Uhunmwonde',
    ],
    'Ekiti': [
      'Ado Ekiti',
      'Efon',
      'Ekiti East',
      'Ekiti South-West',
      'Ekiti West',
      'Emure',
      'Gbonyin',
      'Ido Osi',
      'Ijero',
      'Ikere',
      'Ilejemeje',
      'Irepodun/Ifelodun',
      'Ise/Orun',
      'Moba',
      'Oye',
    ],
    'Enugu': [
      'Aninri',
      'Awgu',
      'Enugu East',
      'Enugu North',
      'Enugu South',
      'Ezeagu',
      'Igbo Etiti',
      'Igbo Eze North',
      'Igbo Eze South',
      'Isi Uzo',
      'Nkanu East',
      'Nkanu West',
      'Nsukka',
      'Oji River',
      'Udenu',
      'Udi',
      'Uzo Uwani',
    ],
    'FCT': [
      'Abaji',
      'Bwari',
      'Gwagwalada',
      'Kuje',
      'Kwali',
      'Municipal Area Council',
    ],
    'Gombe': [
      'Akko',
      'Balanga',
      'Billiri',
      'Dukku',
      'Funakaye',
      'Gombe',
      'Kaltungo',
      'Kwami',
      'Nafada',
      'Shongom',
      'Yamaltu/Deba',
    ],
    'Imo': [
      'Aboh Mbaise',
      'Ahiazu Mbaise',
      'Ehime Mbano',
      'Ezinihitte',
      'Ideato North',
      'Ideato South',
      'Ihitte/Uboma',
      'Ikeduru',
      'Isiala Mbano',
      'Isu',
      'Mbaitoli',
      'Ngor Okpala',
      'Njaba',
      'Nkwerre',
      'Nwangele',
      'Obowo',
      'Oguta',
      'Ohaji/Egbema',
      'Okigwe',
      'Orlu',
      'Orsu',
      'Oru East',
      'Oru West',
      'Owerri Municipal',
      'Owerri North',
      'Owerri West',
      'Unuimo',
    ],
    'Jigawa': [
      'Auyo',
      'Babura',
      'Biriniwa',
      'Birnin Kudu',
      'Buji',
      'Dutse',
      'Gagarawa',
      'Garki',
      'Gumel',
      'Guri',
      'Gwaram',
      'Gwiwa',
      'Hadejia',
      'Jahun',
      'Kafin Hausa',
      'Kazaure',
      'Kiri Kasama',
      'Kiyawa',
      'Kaugama',
      'Maigatari',
      'Malam Madori',
      'Miga',
      'Ringim',
      'Roni',
      'Sule Tankarkar',
      'Taura',
      'Yankwashi',
    ],
    'Kaduna': [
      'Birnin Gwari',
      'Chikun',
      'Giwa',
      'Igabi',
      'Ikara',
      'Jaba',
      'Jema\'a',
      'Kachia',
      'Kaduna North',
      'Kaduna South',
      'Kagarko',
      'Kajuru',
      'Kaura',
      'Kauru',
      'Kubau',
      'Kudan',
      'Lere',
      'Makarfi',
      'Sabon Gari',
      'Sanga',
      'Soba',
      'Zangon Kataf',
      'Zaria',
    ],
    'Kano': [
      'Ajingi',
      'Albasu',
      'Bagwai',
      'Bebeji',
      'Bichi',
      'Bunkure',
      'Dala',
      'Dambatta',
      'Dawakin Kudu',
      'Dawakin Tofa',
      'Doguwa',
      'Fagge',
      'Gabasawa',
      'Garko',
      'Garun Mallam',
      'Gaya',
      'Gezawa',
      'Gwale',
      'Gwarzo',
      'Kabo',
      'Kano Municipal',
      'Karaye',
      'Kibiya',
      'Kiru',
      'Kumbotso',
      'Kunchi',
      'Kura',
      'Madobi',
      'Makoda',
      'Minjibir',
      'Nasarawa',
      'Rano',
      'Rimin Gado',
      'Rogo',
      'Shanono',
      'Sumaila',
      'Takai',
      'Tarauni',
      'Tofa',
      'Tsanyawa',
      'Tudun Wada',
      'Ungogo',
      'Warawa',
      'Wudil',
    ],
    'Katsina': [
      'Bakori',
      'Batagarawa',
      'Batsari',
      'Baure',
      'Bindawa',
      'Charanchi',
      'Dandume',
      'Danja',
      'Dan Musa',
      'Daura',
      'Dutsi',
      'Dutsin Ma',
      'Faskari',
      'Funtua',
      'Ingawa',
      'Jibia',
      'Kafur',
      'Kaita',
      'Kankara',
      'Kankia',
      'Katsina',
      'Kurfi',
      'Kusada',
      'Mai\'Adua',
      'Malumfashi',
      'Mani',
      'Mashi',
      'Matazu',
      'Musawa',
      'Rimi',
      'Sabuwa',
      'Safana',
      'Sandamu',
      'Zango',
    ],
    'Kebbi': [
      'Aleiro',
      'Arewa Dandi',
      'Argungu',
      'Augie',
      'Bagudo',
      'Birnin Kebbi',
      'Bunza',
      'Dandi',
      'Fakai',
      'Gwandu',
      'Jega',
      'Kalgo',
      'Koko/Besse',
      'Maiyama',
      'Ngaski',
      'Sakaba',
      'Shanga',
      'Suru',
      'Danko/Wasagu',
      'Yauri',
      'Zuru',
    ],
    'Kogi': [
      'Adavi',
      'Ajaokuta',
      'Ankpa',
      'Bassa',
      'Dekina',
      'Ibaji',
      'Idah',
      'Igalamela Odolu',
      'Ijumu',
      'Kabba/Bunu',
      'Kogi',
      'Lokoja',
      'Mopa Muro',
      'Ofu',
      'Ogori/Magongo',
      'Okehi',
      'Okene',
      'Olamaboro',
      'Omala',
      'Yagba East',
      'Yagba West',
    ],
    'Kwara': [
      'Asa',
      'Baruten',
      'Edu',
      'Ekiti',
      'Ifelodun',
      'Ilorin East',
      'Ilorin South',
      'Ilorin West',
      'Irepodun',
      'Isin',
      'Kaiama',
      'Moro',
      'Offa',
      'Oke Ero',
      'Oyun',
      'Pategi',
    ],
    'Lagos': [
      'Agege',
      'Ajeromi-Ifelodun',
      'Alimosho',
      'Amuwo-Odofin',
      'Apapa',
      'Badagry',
      'Epe',
      'Eti Osa',
      'Ibeju-Lekki',
      'Ifako-Ijaiye',
      'Ikeja',
      'Ikorodu',
      'Kosofe',
      'Lagos Island',
      'Lagos Mainland',
      'Mushin',
      'Ojo',
      'Oshodi-Isolo',
      'Shomolu',
      'Surulere',
    ],
    'Nasarawa': [
      'Akwanga',
      'Awe',
      'Doma',
      'Karu',
      'Keana',
      'Keffi',
      'Kokona',
      'Lafia',
      'Nasarawa',
      'Nasarawa Egon',
      'Obi',
      'Toto',
      'Wamba',
    ],
    'Niger': [
      'Agaie',
      'Agwara',
      'Bida',
      'Borgu',
      'Bosso',
      'Chanchaga',
      'Edati',
      'Gbako',
      'Gurara',
      'Katcha',
      'Kontagora',
      'Lapai',
      'Lavun',
      'Magama',
      'Mariga',
      'Mashegu',
      'Mokwa',
      'Moya',
      'Paikoro',
      'Rafi',
      'Rijau',
      'Shiroro',
      'Suleja',
      'Tafa',
      'Wushishi',
    ],
    'Ogun': [
      'Abeokuta North',
      'Abeokuta South',
      'Ado-Odo/Ota',
      'Egbado North',
      'Egbado South',
      'Ewekoro',
      'Ifo',
      'Ijebu East',
      'Ijebu North',
      'Ijebu North East',
      'Ijebu Ode',
      'Ikenne',
      'Imeko Afon',
      'Ipokia',
      'Obafemi Owode',
      'Odeda',
      'Odogbolu',
      'Ogun Waterside',
      'Remo North',
      'Shagamu',
    ],
    'Ondo': [
      'Akoko North-East',
      'Akoko North-West',
      'Akoko South-East',
      'Akoko South-West',
      'Akure North',
      'Akure South',
      'Ese Odo',
      'Idanre',
      'Ifedore',
      'Ilaje',
      'Ile Oluji/Okeigbo',
      'Irele',
      'Odigbo',
      'Okitipupa',
      'Ondo East',
      'Ondo West',
      'Ose',
      'Owo',
    ],
    'Osun': [
      'Aiyedaade',
      'Aiyedire',
      'Atakunmosa East',
      'Atakunmosa West',
      'Boluwaduro',
      'Boripe',
      'Ede North',
      'Ede South',
      'Egbedore',
      'Ejigbo',
      'Ife Central',
      'Ife East',
      'Ife North',
      'Ife South',
      'Ifedayo',
      'Ifelodun',
      'Ila',
      'Ilesa East',
      'Ilesa West',
      'Irepodun',
      'Irewole',
      'Isokan',
      'Iwo',
      'Obokun',
      'Odo Otin',
      'Ola Oluwa',
      'Olorunda',
      'Oriade',
      'Orolu',
      'Osogbo',
    ],
    'Oyo': [
      'Afijio',
      'Akinyele',
      'Atiba',
      'Atisbo',
      'Egbeda',
      'Ibadan North',
      'Ibadan North-East',
      'Ibadan North-West',
      'Ibadan South-East',
      'Ibadan South-West',
      'Ibarapa Central',
      'Ibarapa East',
      'Ibarapa North',
      'Ido',
      'Irepo',
      'Iseyin',
      'Itesiwaju',
      'Iwajowa',
      'Kajola',
      'Lagelu',
      'Ogbomosho North',
      'Ogbomosho South',
      'Ogo Oluwa',
      'Olorunsogo',
      'Oluyole',
      'Ona Ara',
      'Orelope',
      'Ori Ire',
      'Oyo',
      'Oyo East',
      'Saki East',
      'Saki West',
      'Surulere',
    ],
    'Plateau': [
      'Bokkos',
      'Barkin Ladi',
      'Bassa',
      'Jos East',
      'Jos North',
      'Jos South',
      'Kanam',
      'Kanke',
      'Langtang North',
      'Langtang South',
      'Mangu',
      'Mikang',
      'Pankshin',
      'Qua\'an Pan',
      'Riyom',
      'Shendam',
      'Wase',
    ],
    'Rivers': [
      'Abua/Odual',
      'Ahoada East',
      'Ahoada West',
      'Akuku-Toru',
      'Andoni',
      'Asari-Toru',
      'Bonny',
      'Degema',
      'Eleme',
      'Emuoha',
      'Etche',
      'Gokana',
      'Ikwerre',
      'Khana',
      'Obio/Akpor',
      'Ogba/Egbema/Ndoni',
      'Ogu/Bolo',
      'Okrika',
      'Omuma',
      'Opobo/Nkoro',
      'Oyigbo',
      'Port Harcourt',
      'Tai',
    ],
    'Sokoto': [
      'Binji',
      'Bodinga',
      'Dange Shuni',
      'Gada',
      'Goronyo',
      'Gudu',
      'Gwadabawa',
      'Illela',
      'Isa',
      'Kebbe',
      'Kware',
      'Rabah',
      'Sabon Birni',
      'Shagari',
      'Silame',
      'Sokoto North',
      'Sokoto South',
      'Tambuwal',
      'Tangaza',
      'Tureta',
      'Wamako',
      'Wurno',
      'Yabo',
    ],
    'Taraba': [
      'Ardo Kola',
      'Bali',
      'Donga',
      'Gashaka',
      'Gassol',
      'Ibi',
      'Jalingo',
      'Karim Lamido',
      'Kumi',
      'Lau',
      'Sardauna',
      'Takum',
      'Ussa',
      'Wukari',
      'Yorro',
      'Zing',
    ],
    'Yobe': [
      'Bade',
      'Bursari',
      'Damaturu',
      'Fika',
      'Fune',
      'Geidam',
      'Gujba',
      'Gulani',
      'Jakusko',
      'Karasuwa',
      'Machina',
      'Nangere',
      'Nguru',
      'Potiskum',
      'Tarmuwa',
      'Yunusari',
      'Yusufari',
    ],
    'Zamfara': [
      'Anka',
      'Bakura',
      'Birnin Magaji/Kiyaw',
      'Bukkuyum',
      'Bungudu',
      'Gummi',
      'Gusau',
      'Kaura Namoda',
      'Maradun',
      'Maru',
      'Shinkafi',
      'Talata Mafara',
      'Chafe',
      'Zurmi',
    ],
  };

  @override
  initState() {
    super.initState();
    _companyNameController.addListener(_updateRegistrationNumber);
    _industryController.addListener(_updateRegistrationNumber);

    // Initialize with placeholder
    _registrationNumberController.text =
        "Enter company/Organization name and industry first";
  }

  @override
  void dispose() {
    _companyNameController.dispose();
    _industryController.dispose();
    _registrationNumberController.dispose();
    _addressController.dispose();
    _contactNumberController.dispose();
    _emailController.dispose();
    _passwordController.dispose();
    _confirmPasswordController.dispose();
    super.dispose();
  }


  // NEW: Account Type variables
  String _selectedAccountType = 'Company';
  String? _selectedAuthorityId;
  String? _selectedAuthorityName;


  Future<void> _signup() async {
    if (!_formKey.currentState!.validate()) {
      return;
    }

    if (_passwordController.text != _confirmPasswordController.text) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Passwords do not match'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    setState(() {
      _isLoading = true;
      _currentStep = 3; // Move to processing step
    });

    try {
      // 1. Create user in Firebase Auth
      final UserCredential userCredential = await FirebaseAuth.instance
          .createUserWithEmailAndPassword(
            email: _emailController.text.trim(),
            password: _passwordController.text.trim(),
          );

      // 2. Upload company logo if selected
      String? logoUrl;
      if (_companyLogoFile == null) {
        Fluttertoast.showToast(msg: "Please upload a logo");
        return;
      }
      if (_companyLogoFile != null) {
        logoUrl = await cloudStorage.uploadFile(
          _companyLogoFile!,
          userCredential.user!.uid,
          "company_logo",
        );
      }

      // 3. Save company data to Firestore
      if (logoUrl == null) {
        Fluttertoast.showToast(msg: "Logo failed to upload, kindly retry");
        return;
      }
      bool result = await _saveCompanyData(userCredential.user!.uid, logoUrl);

      if (mounted && result) {
        showRegistrationSuccessDialog(context);

      }
      else if(mounted && !result)
        {
          Fluttertoast.showToast(msg: "Registration failed, kindly retry");
        }
      else {
        debugPrint("Widget disposed, cannot show dialog");
        Navigator.of(context).pushReplacement(
          MaterialPageRoute(builder: (context) => LoginScreen()),
        );
      }
    } on FirebaseAuthException catch (e) {
      _showError(_getErrorMessage(e.code));
      setState(() {
        _isLoading = false;
        _currentStep = 2; // Go back to account step on error
      });
    } catch (e) {
      _showError('An unexpected error occurred. Please try again.');
      setState(() {
        _isLoading = false;
        _currentStep = 2;
      });
    }
  }


  Future<bool> _saveCompanyData(String userId, String? logoUrl) async {
    try {
      // Get FCM token for notifications
      String? fcmToken = await FirebaseMessaging.instance.getToken();

      if (_selectedAccountType == 'Company') {
        // Create regular Company
        Company company = Company(
          id: userId,
          name: _companyNameController.text,
          industry: _industryController.text,
          registrationNumber: _registrationNumberController.text,
          email: _emailController.text,
          phoneNumber: _contactNumberController.text,
          logoURL: logoUrl!,
          state: _selectedState!,
          localGovernment: _selectedLocalGovernment!,
          description: "",
          role: "Company",
          address: _addressController.text,
          fcmToken: fcmToken ?? "",
          isfeatured: false,
          isUnderAuthority: false,
          authorityId: null,
          authorityName: null,
          authorityLinkStatus: "NONE",
        );

        await itcFirebaseLogic.addCompany(company);
        return true;

      } else if (_selectedAccountType == 'Government Authority') {
        // Create Government Authority
        Authority authority = Authority(
          id: userId,
          name: _companyNameController.text,
          email: _emailController.text,
          contactPerson: null, // You might want to add a field for this
          phoneNumber: _contactNumberController.text,
          logoURL: logoUrl,
          address: _addressController.text,
          state: _selectedState,
          localGovernment: _selectedLocalGovernment,
          registrationNumber: _registrationNumberController.text,
          description: _industryController.text, // Using industry as description
          isActive: true,
          isVerified: false,
          isApproved: false,
          isBlocked: false,
          createdAt: DateTime.now(),
          updatedAt: DateTime.now(),
          // All other fields use defaults from model
          linkedCompanies: [],
          pendingApplications: [],
          approvedApplications: [],
          rejectedApplications: [],
          admins: [userId], // Current user becomes first admin
          supervisors: [],
          fcmToken: fcmToken ?? "",
          notificationTokens: [],
          autoApproveAfterAuthority: false,
          maxCompaniesAllowed: 50,
          maxApplicationsPerBatch: 100,
          requirePhysicalLetter: false,
          letterTemplateUrl: null,
          totalApplicationsReviewed: 0,
          currentPendingCount: 0,
          averageProcessingTimeDays: 0.0,
        );

        await itcFirebaseLogic.addAuthority(authority);
        return true;

      } else if (_selectedAccountType == 'Government Facility') {
        // Create Government Facility (Company under Authority)
        Company company = Company(
          id: userId,
          name: _companyNameController.text,
          industry: _industryController.text,
          registrationNumber: _registrationNumberController.text,
          email: _emailController.text,
          phoneNumber: _contactNumberController.text,
          logoURL: logoUrl!,
          state: _selectedState!,
          localGovernment: _selectedLocalGovernment!,
          description: "",
          role: "Government Facility",
          address: _addressController.text,
          fcmToken: fcmToken ?? "",
          isfeatured: false,
          isUnderAuthority: true,
          authorityId: _selectedAuthorityId,
          authorityName: _selectedAuthorityName,
          authorityLinkStatus: 'PENDING', // Needs approval from authority
        );

        // Save the company
        await itcFirebaseLogic.addCompany(company);

        // If authority is selected, add this company to authority's pending applications
        if (_selectedAuthorityId != null && _selectedAuthorityId!.isNotEmpty) {

          await itcFirebaseLogic.addCompanyToAuthorityPendingApplications(
            authorityId: _selectedAuthorityId!,
            companyId: userId,
            companyName: _companyNameController.text,
            selectedAuthorityName: _selectedAuthorityName!,
          );
        }

        return true;
      }

      return false; // If none of the account types matched

    } catch (error, stack) {
      debugPrintStack(stackTrace: stack);
      debugPrint(error.toString());
      return false;
    }
  }
  String _getErrorMessage(String errorCode) {
    switch (errorCode) {
      case 'invalid-email':
        return 'Invalid email address format.';
      case 'email-already-in-use':
        return 'An account already exists with this email.';
      case 'weak-password':
        return 'Password is too weak. Please use a stronger password.';
      case 'operation-not-allowed':
        return 'Email/password accounts are not enabled.';
      default:
        return 'Registration failed. Please try again.';
    }
  }



  void _showError(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: Colors.red,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
    );
  }

  void _nextStep() {
    if (_currentStep == 0) {
      // Validate company details
      if (_companyNameController.text.trim().isEmpty ||
          _industryController.text.trim().isEmpty ||
          _registrationNumberController.text.trim().isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Please fill in all company details'),
            backgroundColor: Colors.red,
          ),
        );
        return;
      }
      setState(() => _currentStep = 1);
    } else if (_currentStep == 1) {
      // Validate location
      if (_addressController.text.trim().isEmpty ||
          _selectedState == null ||
          _selectedLocalGovernment == null) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Please fill in all location details'),
            backgroundColor: Colors.red,
          ),
        );
        return;
      }
      setState(() => _currentStep = 2);
    } else if (_currentStep == 2) {
      // Validate contact
      if (_contactNumberController.text.trim().isEmpty ||
          _emailController.text.trim().isEmpty ||
          !_emailController.text.contains('@')) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Please fill in all contact details'),
            backgroundColor: Colors.red,
          ),
        );
        return;
      }
      setState(() => _currentStep = 3);
    } else if (_currentStep == 3) {
      _signup();
    }
  }

  void _previousStep() {
    if (_currentStep > 0) {
      setState(() => _currentStep--);
    }
  }

  Future<void> _pickCompanyLogo() async {
    final ImagePicker picker = ImagePicker();
    final XFile? image = await picker.pickImage(
      source: ImageSource.gallery,
      maxWidth: 800,
      maxHeight: 800,
      imageQuality: 85,
    );

    if (image != null) {
      setState(() {
        _companyLogoFile = File(image.path);
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDarkMode = theme.brightness == Brightness.dark;
    final size = MediaQuery.of(context).size;

    return Scaffold(
      body: SafeArea(
        child: SingleChildScrollView(
          physics: const BouncingScrollPhysics(),
          child: Padding(
            padding: EdgeInsets.only(
              bottom: MediaQuery.of(context).viewInsets.bottom,
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // Header section
                Container(
                  padding: EdgeInsets.symmetric(
                    horizontal: size.width > 600 ? 40 : 16,
                    vertical: 30,
                  ),
                  child: Column(
                    children: [
                      _buildHeader(isDarkMode),
                      const SizedBox(height: 25),
                      _buildProgressStepper(),
                    ],
                  ),
                ),

                const SizedBox(height: 25),

                // Form section
                Container(
                  padding: EdgeInsets.symmetric(
                    horizontal: size.width > 600 ? 40 : 16,
                  ),
                  child: Form(
                    key: _formKey,
                    child: _buildCurrentStep(isDarkMode),
                  ),
                ),

                const SizedBox(height: 40),

                // Navigation section
                Container(
                  padding: EdgeInsets.symmetric(
                    horizontal: size.width > 600 ? 40 : 16,
                    vertical: 25,
                  ),
                  child: _buildNavigationButtons(theme),
                ),

                // Extra bottom padding for better scrolling on small devices
                SizedBox(height: MediaQuery.of(context).size.height * 0.05),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildHeader(bool isDarkMode) {
    return Column(
      children: [
        Container(
          width: 80,
          height: 80,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            gradient: LinearGradient(
              colors: [
                Theme.of(context).colorScheme.primary,
                Theme.of(context).colorScheme.secondary,
              ],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            boxShadow: [
              BoxShadow(
                color: Theme.of(context).colorScheme.primary.withOpacity(0.3),
                blurRadius: 15,
                spreadRadius: 2,
              ),
            ],
          ),
          child: const Icon(Icons.business, size: 40, color: Colors.white),
        ),
        const SizedBox(height: 16),
        Text(
          "Register Your Company",
          style: TextStyle(
            fontSize: 24,
            fontWeight: FontWeight.bold,
            color: isDarkMode ? Colors.white : Colors.blueGrey[900],
          ),
        ),
        const SizedBox(height: 8),
        Text(
          "Join IT Connect to find talented IT students for your organization",
          textAlign: TextAlign.center,
          style: TextStyle(
            color: Theme.of(context).colorScheme.onSurface.withOpacity(0.7),
          ),
        ),
      ],
    );
  }

  Widget _buildProgressStepper() {
    return SizedBox(
      height: 60,
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          _buildStepIndicator(0, "Details"),
          _buildStepConnector(0),
          _buildStepIndicator(1, "Location"),
          _buildStepConnector(1),
          _buildStepIndicator(2, "Contact"),
          _buildStepConnector(2),
          _buildStepIndicator(3, "Account"),
        ],
      ),
    );
  }

  Widget _buildStepIndicator(int stepIndex, String label) {
    final isActive = _currentStep >= stepIndex;
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 30,
          height: 30,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: isActive
                ? Theme.of(context).colorScheme.primary
                : Colors.grey[300],
            border: Border.all(
              color: isActive
                  ? Theme.of(context).colorScheme.primary
                  : Colors.transparent,
              width: 2,
            ),
          ),
          child: Center(
            child: isActive
                ? const Icon(Icons.check, color: Colors.white, size: 16)
                : Text(
                    (stepIndex + 1).toString(),
                    style: TextStyle(
                      color: stepIndex <= _currentStep
                          ? Colors.white
                          : Colors.grey[600],
                      fontWeight: FontWeight.bold,
                      fontSize: 12,
                    ),
                  ),
          ),
        ),
        const SizedBox(height: 4),
        Text(
          label,
          style: TextStyle(
            fontSize: 10,
            color: isActive
                ? Theme.of(context).colorScheme.primary
                : Colors.grey[500],
            fontWeight: isActive ? FontWeight.bold : FontWeight.normal,
          ),
        ),
      ],
    );
  }

  Widget _buildStepConnector(int stepIndex) {
    final isActive = _currentStep > stepIndex;
    return Container(
      width: 40,
      height: 2,
      margin: const EdgeInsets.symmetric(horizontal: 4),
      color: isActive
          ? Theme.of(context).colorScheme.primary
          : Colors.grey[300],
    );
  }

  Widget _buildCurrentStep(bool isDarkMode) {
    switch (_currentStep) {
      case 0:
        return _buildCompanyDetailsStep(isDarkMode);
      case 1:
        return _buildLocationStep(isDarkMode);
      case 2:
        return _buildContactStep(isDarkMode);
      case 3:
        return _isLoading ? _buildLoadingStep() : _buildAccountStep(isDarkMode);
      default:
        return Container();
    }
  }

  Widget _buildCompanyDetailsStep(bool isDarkMode) {

    return SingleChildScrollView(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            "Company Details",
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w600,
              color: isDarkMode ? Colors.white : Colors.blueGrey[800],
            ),
          ),
          const SizedBox(height: 8),
          Text(
            "Tell us about your company",
            style: TextStyle(color: Colors.grey[600], fontSize: 14),
          ),
          const SizedBox(height: 24),

          // Company Name
          _buildFormField(
            label: "Company/Organization Name",
            icon: Icons.business_center,
            controller: _companyNameController,
            hintText: "Enter company/Organization name",
            validator: (value) {
              if (value?.isEmpty ?? true) {
                return 'Please enter company/Organization name';
              }
              return null;
            },
            isDarkMode: isDarkMode,
          ),

          const SizedBox(height: 16),

          // Industry
          _buildFormField(
            label: "Industry or Sector",
            icon: Icons.category,
            controller: _industryController,
            hintText: "e.g., Technology, Finance",
            validator: (value) {
              if (value?.isEmpty ?? true) {
                return 'Please enter industry';
              }
              return null;
            },
            isDarkMode: isDarkMode,
          ),

          const SizedBox(height: 16),

          // 🔽 NEW: Account Type Selection
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                "Account Type",
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w500,
                  color: isDarkMode ? Colors.white : Colors.blueGrey[700],
                ),
              ),
              const SizedBox(height: 4),
              Container(
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(12),
                  color: isDarkMode
                      ? Colors.grey[800]!.withOpacity(0.5)
                      : Colors.grey[50],
                ),
                child: DropdownButtonFormField<String>(
                  isExpanded: true,
                  value: _selectedAccountType,
                  decoration: InputDecoration(
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide.none,
                    ),
                    filled: true,
                    fillColor: Colors.transparent,
                    contentPadding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 16,
                    ),
                    prefixIcon: Icon(
                      Icons.account_balance,
                      color: Theme.of(context).colorScheme.primary,
                    ),
                  ),
                  hint: const Text("Select Account Type"),
                  items: [
                    DropdownMenuItem<String>(
                      value: 'Company',
                      child: Row(
                        children: [
                          Icon(Icons.business, size: 20, color: Colors.blue),
                          SizedBox(width: 10),
                          Expanded(child: Text('Regular Company')),
                        ],
                      ),
                    ),
                    DropdownMenuItem<String>(
                      value: 'Government Authority',
                      child: Row(
                        children: [
                          Icon(Icons.account_balance, size: 20, color: Colors.green),
                          SizedBox(width: 10),
                          Expanded(child: Text('Government Authority')),
                        ],
                      ),
                    ),
                    DropdownMenuItem<String>(
                      value: 'Government Facility',
                      child: Row(
                        children: [
                          Icon(Icons.business_outlined, size: 20, color: Colors.orange),
                          SizedBox(width: 10),
                          Expanded(child: Text('Government Facility (Under Authority)')),
                        ],
                      ),
                    ),
                  ],
                  onChanged: (String? newValue) {
                    setState(() {
                      debugPrint("new value is  $newValue");
                      _selectedAccountType = newValue ?? 'Company';
                    });
                  },
                  validator: (value) {
                    if (value == null) {
                      return 'Please select account type';
                    }
                    return null;
                  },
                ),
              ),
            ],
          ),

          const SizedBox(height: 16),

          // 🔽 NEW: If Government Facility is selected, show authority selection
          if (_selectedAccountType == 'Government Facility')
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  "Parent Authority",
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w500,
                    color: isDarkMode ? Colors.white : Colors.blueGrey[700],
                  ),
                ),
                Text(
                  "Note: If your authority is not available, skip this section",
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w500,
                    color: isDarkMode ? Colors.white : Colors.blueGrey[700],
                  ),
                ),
                const SizedBox(height: 4),
                FutureBuilder<List<Authority>>(
                  future:itcFirebaseLogic.getAllAuthorities(),
                  builder: (context, snapshot) {
                    if (snapshot.connectionState == ConnectionState.waiting) {
                      return CircularProgressIndicator();
                    }

                    if (snapshot.hasError || !snapshot.hasData || snapshot.data?.length == 0) {
                      return Text('No authorities available');
                    }

                    return DropdownButtonFormField<String>(
                      isExpanded: true,
                      value: _selectedAuthorityId,
                      decoration: InputDecoration(
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: BorderSide.none,
                        ),
                        filled: true,
                        fillColor: Colors.transparent,
                        contentPadding: const EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 16,
                        ),
                        prefixIcon: Icon(
                          Icons.supervisor_account,
                          color: Theme.of(context).colorScheme.primary,
                        ),
                      ),
                      hint: const Text("Select Parent Authority"),
                      items: snapshot.data!.map((authority) {
                        return DropdownMenuItem<String>(
                          value: authority.id,
                          child: Text(authority.name),
                        );
                      }).toList(),
                      onChanged: (String? newValue) {
                        setState(() {
                          _selectedAuthorityId = newValue;
                          _selectedAuthorityName = snapshot.data!
                              .firstWhere((auth) => auth.id == newValue)
                              .name;
                        });
                      },
                      validator: (value) {
                        if (_selectedAccountType == 'Government Facility' &&
                            (value == null || value.isEmpty)) {
                          return 'Please select parent authority';
                        }
                        return null;
                      },
                    );
                  },
                ),
              ],
            ),
          const SizedBox(height: 16),

          // Registration Number
          _buildFormField(
            label: "Registration Number(Autogenerated)",
            icon: Icons.badge,
            controller: _registrationNumberController,
            hintText: "Enter registration number",
            validator: (value) {
              if (value?.isEmpty ?? true) {
                return 'Please enter registration number';
              }
              return null;
            },
            isDarkMode: isDarkMode,
            enable: false,
          ),

          const SizedBox(height: 16),

          // Company Logo
          Text(
            "Company Logo",
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w500,
              color: isDarkMode ? Colors.white : Colors.blueGrey[700],
            ),
          ),
          const SizedBox(height: 8),
          _buildLogoUploadSection(isDarkMode),
        ],
      ),
    );
  }

  String _generateRegistrationNumber(String companyName, String industry) {
    final now = DateTime.now();
    final timestamp = now.millisecondsSinceEpoch.toString().substring(7, 13);

    // Get first 2 letters of company and industry
    final companyCode = companyName.trim().isNotEmpty
        ? companyName
              .trim()
              .substring(0, min(2, companyName.trim().length))
              .toUpperCase()
        : 'CO';

    final industryCode = industry.trim().isNotEmpty
        ? industry
              .trim()
              .substring(0, min(2, industry.trim().length))
              .toUpperCase()
        : 'IN';

    return '${companyCode}${industryCode}-$timestamp';
  }

  void _updateRegistrationNumber() {
    final companyName = _companyNameController.text.trim();
    final industry = _industryController.text.trim();

    if (companyName.isNotEmpty && industry.isNotEmpty) {
      final registrationNumber = _generateRegistrationNumber(
        companyName,
        industry,
      );
      _registrationNumberController.text = registrationNumber;
    } else {
      _registrationNumberController.text =
          "Enter company/Organization name and industry first";
    }
  }

  Widget _buildLocationStep(bool isDarkMode) {
    return SingleChildScrollView(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            "Location Details",
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w600,
              color: isDarkMode ? Colors.white : Colors.blueGrey[800],
            ),
          ),
          const SizedBox(height: 8),
          Text(
            "Where is your company located?",
            style: TextStyle(color: Colors.grey[600], fontSize: 14),
          ),
          const SizedBox(height: 24),

          // Address
          _buildFormField(
            label: "Address",
            icon: Icons.location_on,
            controller: _addressController,
            hintText: "Enter company/Authority address",
            validator: (value) {
              if (value?.isEmpty ?? true) {
                return 'Please enter address';
              }
              return null;
            },
            isDarkMode: isDarkMode,
          ),

          const SizedBox(height: 16),

          // State Dropdown
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                "State",
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w500,
                  color: isDarkMode ? Colors.white : Colors.blueGrey[700],
                ),
              ),
              const SizedBox(height: 4),
              Container(
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(12),
                  color: isDarkMode
                      ? Colors.grey[800]!.withOpacity(0.5)
                      : Colors.grey[50],
                ),
                child: DropdownButtonFormField<String>(
                  value: _selectedState,
                  decoration: InputDecoration(
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide.none,
                    ),
                    filled: true,
                    fillColor: Colors.transparent,
                    contentPadding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 16,
                    ),
                    prefixIcon: Icon(
                      Icons.map,
                      color: Theme.of(context).colorScheme.primary,
                    ),
                  ),
                  hint: const Text("Select State"),
                  items: _statesAndLgas.keys.map((String state) {
                    return DropdownMenuItem<String>(
                      value: state,
                      child: Text(state),
                    );
                  }).toList(),
                  onChanged: (String? newValue) {
                    setState(() {
                      _selectedState = newValue;
                      _selectedLocalGovernment = null;
                    });
                  },
                  validator: (value) {
                    if (value == null) {
                      return 'Please select a state';
                    }
                    return null;
                  },
                ),
              ),
            ],
          ),

          const SizedBox(height: 16),

          // Local Government Dropdown
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                "Local Government",
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w500,
                  color: isDarkMode ? Colors.white : Colors.blueGrey[700],
                ),
              ),
              const SizedBox(height: 4),
              Container(
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(12),
                  color: isDarkMode
                      ? Colors.grey[800]!.withOpacity(0.5)
                      : Colors.grey[50],
                ),
                child: DropdownButtonFormField<String>(
                  value: _selectedLocalGovernment,
                  decoration: InputDecoration(
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide.none,
                    ),
                    filled: true,
                    fillColor: Colors.transparent,
                    contentPadding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 16,
                    ),
                    prefixIcon: Icon(
                      Icons.location_city,
                      color: Theme.of(context).colorScheme.primary,
                    ),
                  ),
                  hint: Text(
                    _selectedState == null
                        ? "Select state first"
                        : "Select Local Government",
                  ),
                  items: _selectedState == null
                      ? null
                      : _statesAndLgas[_selectedState]!.map((String lga) {
                          return DropdownMenuItem<String>(
                            value: lga,
                            child: Text(lga),
                          );
                        }).toList(),
                  onChanged: _selectedState == null
                      ? null
                      : (String? newValue) {
                          setState(() {
                            _selectedLocalGovernment = newValue;
                          });
                        },
                  validator: (value) {
                    if (_selectedState != null && value == null) {
                      return 'Please select local government';
                    }
                    return null;
                  },
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildContactStep(bool isDarkMode) {
    return SingleChildScrollView(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            "Contact Information",
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w600,
              color: isDarkMode ? Colors.white : Colors.blueGrey[800],
            ),
          ),
          const SizedBox(height: 8),
          Text(
            "How can we reach you?",
            style: TextStyle(color: Colors.grey[600], fontSize: 14),
          ),
          const SizedBox(height: 24),

          // Contact Number
          _buildFormField(
            label: "Contact Number",
            icon: Icons.call,
            controller: _contactNumberController,
            hintText: "Enter contact number",
            keyboardType: TextInputType.phone,
            validator: (value) {
              if (value?.isEmpty ?? true) {
                return 'Please enter contact number';
              }
              if (value!.length < 10) {
                return 'Please enter a valid phone number';
              }
              return null;
            },
            isDarkMode: isDarkMode,
          ),

          const SizedBox(height: 16),

          // Email Address
          _buildFormField(
            label: "Email Address",
            icon: Icons.mail,
            controller: _emailController,
            hintText: "Enter email address",
            keyboardType: TextInputType.emailAddress,
            validator: (value) {
              if (value?.isEmpty ?? true) {
                return 'Please enter email address';
              }
              if (!value!.contains('@') || !value.contains('.')) {
                return 'Please enter a valid email';
              }
              return null;
            },
            isDarkMode: isDarkMode,
          ),
        ],
      ),
    );
  }

  Widget _buildAccountStep(bool isDarkMode) {
    return SingleChildScrollView(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            "Account Setup",
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w600,
              color: isDarkMode ? Colors.white : Colors.blueGrey[800],
            ),
          ),
          const SizedBox(height: 8),
          Text(
            "Create your login credentials",
            style: TextStyle(color: Colors.grey[600], fontSize: 14),
          ),
          const SizedBox(height: 24),

          // Password
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                "Password",
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w500,
                  color: isDarkMode ? Colors.white : Colors.blueGrey[700],
                ),
              ),
              const SizedBox(height: 4),
              TextFormField(
                controller: _passwordController,
                obscureText: !_isPasswordVisible,
                decoration: InputDecoration(
                  hintText: "Enter password",
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide.none,
                  ),
                  filled: true,
                  fillColor: isDarkMode
                      ? Colors.grey[800]!.withOpacity(0.5)
                      : Colors.grey[50],
                  contentPadding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 16,
                  ),
                  prefixIcon: Icon(
                    Icons.lock_outline,
                    color: Theme.of(context).colorScheme.primary,
                  ),
                  suffixIcon: IconButton(
                    icon: Icon(
                      _isPasswordVisible
                          ? Icons.visibility_off
                          : Icons.visibility,
                      color: Colors.grey[500],
                    ),
                    onPressed: () => setState(
                      () => _isPasswordVisible = !_isPasswordVisible,
                    ),
                  ),
                ),
                validator: (value) {
                  if (value?.isEmpty ?? true) {
                    return 'Please enter password';
                  }
                  if (value!.length < 6) {
                    return 'Password must be at least 6 characters';
                  }
                  return null;
                },
              ),
            ],
          ),

          const SizedBox(height: 16),

          // Confirm Password
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                "Confirm Password",
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w500,
                  color: isDarkMode ? Colors.white : Colors.blueGrey[700],
                ),
              ),
              const SizedBox(height: 4),
              TextFormField(
                controller: _confirmPasswordController,
                obscureText: !_isConfirmPasswordVisible,
                decoration: InputDecoration(
                  hintText: "Re-enter your password",
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide.none,
                  ),
                  filled: true,
                  fillColor: isDarkMode
                      ? Colors.grey[800]!.withOpacity(0.5)
                      : Colors.grey[50],
                  contentPadding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 16,
                  ),
                  prefixIcon: Icon(
                    Icons.lock_reset_outlined,
                    color: Theme.of(context).colorScheme.primary,
                  ),
                  suffixIcon: IconButton(
                    icon: Icon(
                      _isConfirmPasswordVisible
                          ? Icons.visibility_off
                          : Icons.visibility,
                      color: Colors.grey[500],
                    ),
                    onPressed: () => setState(
                      () => _isConfirmPasswordVisible =
                          !_isConfirmPasswordVisible,
                    ),
                  ),
                ),
                validator: (value) {
                  if (value?.isEmpty ?? true) {
                    return 'Please confirm password';
                  }
                  if (value != _passwordController.text) {
                    return 'Passwords do not match';
                  }
                  return null;
                },
              ),
            ],
          ),

          const SizedBox(height: 16),

          // Password Requirements
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: Colors.amber.withOpacity(0.05),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: Colors.amber.withOpacity(0.1)),
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(
                  Icons.security_outlined,
                  color: Colors.amber[700],
                  size: 18,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        "Password Requirements",
                        style: TextStyle(
                          color: Colors.amber[700],
                          fontWeight: FontWeight.w600,
                          fontSize: 13,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        "• At least 6 characters\n• Use letters and numbers for better security",
                        style: TextStyle(
                          color: Colors.amber[700],
                          fontSize: 12,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFormField({
    required String label,
    required IconData icon,
    required TextEditingController controller,
    required String hintText,
    required String? Function(String?) validator,
    required bool isDarkMode,
    TextInputType keyboardType = TextInputType.text,
    bool? enable = true,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w500,
            color: isDarkMode ? Colors.white : Colors.blueGrey[700],
          ),
        ),
        const SizedBox(height: 4),
        TextFormField(
          enabled: enable,
          controller: controller,
          keyboardType: keyboardType,
          decoration: InputDecoration(
            hintText: hintText,
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide.none,
            ),
            filled: true,
            fillColor: isDarkMode
                ? Colors.grey[800]!.withOpacity(0.5)
                : Colors.grey[50],
            contentPadding: const EdgeInsets.symmetric(
              horizontal: 16,
              vertical: 16,
            ),
            prefixIcon: Icon(
              icon,
              color: Theme.of(context).colorScheme.primary,
            ),
          ),
          validator: validator,
        ),
      ],
    );
  }

  Widget _buildLogoUploadSection(bool isDarkMode) {
    return GestureDetector(
      onTap: _pickCompanyLogo,
      child: Container(
        padding: const EdgeInsets.all(24),
        decoration: BoxDecoration(
          border: Border.all(color: Colors.grey[300]!, width: 2),
          borderRadius: BorderRadius.circular(12),
          color: isDarkMode
              ? Colors.grey[800]!.withOpacity(0.3)
              : Colors.grey[50],
        ),
        child: Column(
          children: [
            if (_companyLogoFile != null) ...[
              ClipRRect(
                borderRadius: BorderRadius.circular(8),
                child: Image.file(
                  _companyLogoFile!,
                  width: 100,
                  height: 100,
                  fit: BoxFit.cover,
                ),
              ),
              const SizedBox(height: 16),
              Text(
                "Tap to change logo",
                style: TextStyle(
                  color: Theme.of(context).colorScheme.primary,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ] else ...[
              Container(
                width: 80,
                height: 80,
                decoration: BoxDecoration(
                  color: isDarkMode ? Colors.grey[700] : Colors.grey[200],
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  Icons.cloud_upload,
                  size: 36,
                  color: Colors.grey[400],
                ),
              ),
              const SizedBox(height: 16),
              Text(
                "Choose a file or drag and drop here",
                style: TextStyle(
                  color: Colors.grey[600],
                  fontWeight: FontWeight.w500,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                "PNG, JPG, GIF up to 10MB",
                style: TextStyle(color: Colors.grey[500], fontSize: 12),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildLoadingStep() {
    final theme = Theme.of(context);
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          SizedBox(
            width: 80,
            height: 80,
            child: Stack(
              children: [
                Center(
                  child: Container(
                    width: 60,
                    height: 60,
                    decoration: BoxDecoration(
                      color: theme.colorScheme.primary.withOpacity(0.1),
                      shape: BoxShape.circle,
                    ),
                    child: CircularProgressIndicator(
                      valueColor: AlwaysStoppedAnimation<Color>(
                        theme.colorScheme.primary,
                      ),
                      strokeWidth: 3,
                    ),
                  ),
                ),
                Center(
                  child: Icon(
                    Icons.app_registration,
                    size: 30,
                    color: theme.colorScheme.primary,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 32),
          Text(
            "Creating your account...",
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w600,
              color: theme.colorScheme.onSurface,
            ),
          ),
          const SizedBox(height: 12),
          Text(
            "Setting up your company dashboard\nThis may take a moment",
            textAlign: TextAlign.center,
            style: TextStyle(
              color: theme.colorScheme.onSurface.withOpacity(0.6),
              fontSize: 14,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildNavigationButtons(ThemeData theme) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        if (_currentStep > 0)
          TextButton(
            onPressed: _previousStep,
            child: Row(
              children: [
                const Icon(Icons.arrow_back, size: 18),
                const SizedBox(width: 8),
                Text(
                  "Back",
                  style: TextStyle(
                    color: theme.colorScheme.primary,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
          )
        else
          const SizedBox(width: 100),

        ElevatedButton(
          onPressed: _nextStep,
          style: ElevatedButton.styleFrom(
            backgroundColor: theme.colorScheme.primary,
            foregroundColor: Colors.white,
            padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 14),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                _currentStep < 3 ? "Continue" : "Complete Registration",
                style: const TextStyle(fontWeight: FontWeight.w600),
              ),
              if (_currentStep < 3) ...[
                const SizedBox(width: 8),
                const Icon(Icons.arrow_forward, size: 18),
              ],
            ],
          ),
        ),
      ],
    );
  }

  void showRegistrationSuccessDialog(BuildContext context) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.check_circle, color: Colors.green, size: 50),
            SizedBox(height: 16),
            Text(
              'Registration Successful',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600),
            ),
            SizedBox(height: 8),
            Text(
              'Your company has been registered.',
              textAlign: TextAlign.center,
              style: TextStyle(color: Colors.grey.shade600),
            ),
            SizedBox(height: 24),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: () {
                  Navigator.of(context).pop();
                  GeneralMethods.replaceNavigationTo(context, LoginScreen());
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.blue,
                  foregroundColor: Colors.white,
                  padding: EdgeInsets.symmetric(vertical: 14),
                ),
                child: Text('Login Now'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

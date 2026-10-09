import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:image_picker/image_picker.dart';
import 'package:pdf/pdf.dart' as pdf_lib;
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart' as printing_lib;
import 'package:http/http.dart' as http;

// Importamos los modelos desde su carpeta
import '../models/user_profile.dart';
import '../models/food_item.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  List<FoodItem> _foodItems = [];
  UserProfile? _userProfile;
  int _currentStreak = 0;
  List<double> _weightHistory = [];
  int _currentIndex = 0;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    final prefs = await SharedPreferences.getInstance();
    
    final String? savedProfile = prefs.getString('user_profile_v15');
    if (savedProfile != null) _userProfile = UserProfile.fromJson(jsonDecode(savedProfile));

    final String? savedFoods = prefs.getString('saved_foods_v15');
    if (savedFoods != null) {
      final List<dynamic> decodedList = jsonDecode(savedFoods);
      _foodItems = decodedList.map((item) => FoodItem.fromJson(item)).toList();
    }

    final List<String>? savedWeights = prefs.getStringList('weight_history_v15');
    if (savedWeights != null && savedWeights.isNotEmpty) {
      _weightHistory = savedWeights.map((w) => double.tryParse(w) ?? 70.0).toList();
    } else if (_userProfile != null) {
      _weightHistory = [_userProfile!.weight];
    }

    final String todayDate = DateTime.now().toIso8601String().split('T')[0];
    final String? lastDate = prefs.getString('last_active_date_v15');
    int streak = prefs.getInt('current_streak_v15') ?? 1;

    if (lastDate != null) {
      DateTime last = DateTime.parse(lastDate);
      DateTime today = DateTime.parse(todayDate);
      int difference = today.difference(last).inDays;
      if (difference == 1) streak++; 
      else if (difference > 1) streak = 1; 
    }
    await prefs.setString('last_active_date_v15', todayDate);
    await prefs.setInt('current_streak_v15', streak);
    _currentStreak = streak;

    setState(() {});
  }

  Future<void> _saveProfile(UserProfile profile) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('user_profile_v15', jsonEncode(profile.toJson()));
    setState(() => _userProfile = profile);
  }

  Future<void> _saveFoodItems() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('saved_foods_v15', jsonEncode(_foodItems.map((item) => item.toJson()).toList()));
  }

  Future<void> _addNewWeightRecord(double newWeight) async {
    setState(() {
      _weightHistory.add(newWeight);
      if (_userProfile != null) {
        _userProfile = UserProfile(
          name: _userProfile!.name, weight: newWeight, height: _userProfile!.height,
          age: _userProfile!.age, gender: _userProfile!.gender, activityMultiplier: _userProfile!.activityMultiplier,
          goalType: _userProfile!.goalType, calorieAdjustment: _userProfile!.calorieAdjustment,
          goalCalories: _userProfile!.goalCalories, proteinTarget: _userProfile!.proteinTarget,
          carbTarget: _userProfile!.carbTarget, fatTarget: _userProfile!.fatTarget
        );
      }
    });

    final prefs = await SharedPreferences.getInstance();
    await prefs.setStringList('weight_history_v15', _weightHistory.map((w) => w.toString()).toList());
    if (_userProfile != null) {
      await prefs.setString('user_profile_v15', jsonEncode(_userProfile!.toJson()));
    }
  }

  void _deleteItem(int index) {
    setState(() => _foodItems.removeAt(index));
    _saveFoodItems();
  }

  double get _totalCalories => _foodItems.fold(0, (sum, item) => sum + item.calories);
  double get _totalProtein => _foodItems.fold(0, (sum, item) => sum + item.protein);
  double get _totalCarbs => _foodItems.fold(0, (sum, item) => sum + item.carbs);
  double get _totalFat => _foodItems.fold(0, (sum, item) => sum + item.fat);

  // EXPORTAR REPORTE CLÍNICO EN PDF
  Future<void> _exportPdfReport() async {
    final pdf = pw.Document();
    pdf.addPage(
      pw.Page(
        pageFormat: pdf_lib.PdfPageFormat.a4,
        build: (pw.Context context) {
          return pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              pw.Row(
                mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                children: [
                  pw.Text('BioMacros: Reporte Clínico Nutricional', style: pw.TextStyle(fontSize: 22, fontWeight: pw.FontWeight.bold)),
                  pw.Text('Paciente: ${_userProfile?.name ?? "Usuario"}', style: pw.TextStyle(fontSize: 14, fontWeight: pw.FontWeight.bold)),
                ],
              ),
              pw.SizedBox(height: 8),
              pw.Text('Tu biología, tus números, tus resultados', style: const pw.TextStyle(fontSize: 11, color: pdf_lib.PdfColor.fromInt(0xFF757575))),
              pw.SizedBox(height: 15), 
              pw.Divider(thickness: 2), 
              pw.SizedBox(height: 10),
              pw.Text('Objetivo: ${_userProfile?.goalType} | Peso Actual: ${_weightHistory.isNotEmpty ? _weightHistory.last : _userProfile?.weight} kg | Talla: ${_userProfile?.height} cm', style: const pw.TextStyle(fontSize: 12)),
              pw.SizedBox(height: 20), 
              pw.Text('Resumen de Ingesta:', style: pw.TextStyle(fontSize: 16, fontWeight: pw.FontWeight.bold)), 
              pw.SizedBox(height: 10),
              pw.Text('Calorías Totales: ${_totalCalories.toStringAsFixed(0)} / ${_userProfile?.goalCalories.toStringAsFixed(0)} kcal'),
              pw.Text('Proteínas: ${_totalProtein.toStringAsFixed(0)}g / ${_userProfile?.proteinTarget.toStringAsFixed(0)}g'),
              pw.Text('Carbohidratos: ${_totalCarbs.toStringAsFixed(0)}g / ${_userProfile?.carbTarget.toStringAsFixed(0)}g'),
              pw.Text('Grasas: ${_totalFat.toStringAsFixed(0)}g / ${_userProfile?.fatTarget.toStringAsFixed(0)}g'),
              pw.Spacer(), 
              pw.Divider(), 
              pw.Center(child: pw.Text('Generado automáticamente por BioMacros', style: const pw.TextStyle(fontSize: 10, color: pdf_lib.PdfColor.fromInt(0xFF757575)))),
            ],
          );
        },
      ),
    );
    await printing_lib.Printing.layoutPdf(onLayout: (pdf_lib.PdfPageFormat format) async => pdf.save());
  }

  void _showProgressAndBadgesModal() {
    double initialWeight = _weightHistory.isNotEmpty ? _weightHistory.first : 70.0;
    double currentWeight = _weightHistory.isNotEmpty ? _weightHistory.last : (_userProfile?.weight ?? 70.0);
    double weightDiff = currentWeight - initialWeight;
    String weightDiffText = weightDiff == 0 
        ? 'Sin cambios aún' 
        : (weightDiff < 0 ? '↓ ${weightDiff.abs().toStringAsFixed(1)} kg desde el inicio' : '↑ ${weightDiff.abs().toStringAsFixed(1)} kg desde el inicio');

    int totalLogs = _foodItems.length;
    double goalCompletionRate = _userProfile != null && _userProfile!.goalCalories > 0 
        ? ((_totalCalories / _userProfile!.goalCalories) * 100).clamp(0.0, 100.0) 
        : 0.0;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: const Color(0xFF131B24),
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(25))),
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setStateModal) {
            return Padding(
              padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom, left: 24, right: 24, top: 25),
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Row(
                      children: [
                        Icon(Icons.auto_graph, color: Color(0xFF00E676), size: 28),
                        SizedBox(width: 10),
                        Text('📈 Tu Progreso y Logros', style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Colors.white)),
                      ],
                    ),
                    const SizedBox(height: 20),

                    Container(
                      padding: const EdgeInsets.all(18),
                      decoration: BoxDecoration(color: const Color(0xFF0B1015), borderRadius: BorderRadius.circular(16)),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              const Text('Peso Actual en Báscula', style: TextStyle(color: Colors.grey, fontSize: 13)),
                              TextButton.icon(
                                style: TextButton.styleFrom(foregroundColor: const Color(0xFF00E676), padding: EdgeInsets.zero),
                                icon: const Icon(Icons.add_circle_outline, size: 16),
                                label: const Text('Registrar Peso', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                                onPressed: () {
                                  Navigator.pop(context);
                                  _showWeightInputDialog();
                                },
                              ),
                            ],
                          ),
                          const SizedBox(height: 4),
                          Text('$currentWeight kg', style: const TextStyle(fontSize: 32, fontWeight: FontWeight.bold, color: Colors.white)),
                          const SizedBox(height: 4),
                          Text('Tu biología, tus números, tus resultados ($weightDiffText)', style: const TextStyle(color: Color(0xFF00E676), fontSize: 11, fontWeight: FontWeight.w600)),
                          const SizedBox(height: 15),
                          
                          SizedBox(
                            height: 70,
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.spaceAround,
                              crossAxisAlignment: CrossAxisAlignment.end,
                              children: _weightHistory.length > 1
                                  ? _weightHistory.map((w) => _buildDynamicBar('${w.toStringAsFixed(1)}kg', w)).toList()
                                  : [_buildDynamicBar('$currentWeight kg', currentWeight, isHighlight: true)],
                            ),
                          )
                        ],
                      ),
                    ),
                    const SizedBox(height: 20),

                    Row(
                      children: [
                        Expanded(
                          child: Container(
                            padding: const EdgeInsets.all(16),
                            decoration: BoxDecoration(color: const Color(0xFF0B1015), borderRadius: BorderRadius.circular(16)),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Text('🔥 Racha Actual', style: TextStyle(color: Colors.grey, fontSize: 12)),
                                const SizedBox(height: 6),
                                Text('$_currentStreak días', style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: Colors.orange)),
                              ],
                            ),
                          ),
                        ),
                        const SizedBox(width: 15),
                        Expanded(
                          child: Container(
                            padding: const EdgeInsets.all(16),
                            decoration: BoxDecoration(color: const Color(0xFF0B1015), borderRadius: BorderRadius.circular(16)),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Text('🎯 Meta del Día', style: TextStyle(color: Colors.grey, fontSize: 12)),
                                const SizedBox(height: 6),
                                Text('${goalCompletionRate.toStringAsFixed(0)}%', style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: Color(0xFF00E676))),
                              ],
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 25),

                    const Text('🏆 Insignias Desbloqueadas', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.white)),
                    const SizedBox(height: 15),
                    GridView.count(
                      crossAxisCount: 2,
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      crossAxisSpacing: 12,
                      mainAxisSpacing: 12,
                      childAspectRatio: 2.5,
                      children: [
                        _buildBadgeItem('🎯', 'Primer Objetivo', true),
                        _buildBadgeItem('🔥', 'Racha de 7 Días', _currentStreak >= 7),
                        _buildBadgeItem('💪', 'Mes Constante', _currentStreak >= 30),
                        _buildBadgeItem('🥗', '100 Comidas', totalLogs >= 10),
                      ],
                    ),
                    const SizedBox(height: 25),

                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton(
                        style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF00E676), foregroundColor: Colors.black, padding: const EdgeInsets.symmetric(vertical: 14), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))),
                        onPressed: () => Navigator.pop(context),
                        child: const Text('Cerrar', style: TextStyle(fontWeight: FontWeight.bold)),
                      ),
                    ),
                    const SizedBox(height: 15),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }

  void _showWeightInputDialog() {
    final weightController = TextEditingController();
    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          backgroundColor: const Color(0xFF131B24),
          title: const Text('Registrar Nuevo Peso ⚖️', style: TextStyle(color: Colors.white)),
          content: TextField(
            controller: weightController,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            style: const TextStyle(color: Colors.white, fontSize: 18),
            decoration: const InputDecoration(
              labelText: 'Peso en kg (Ej. 74.5)',
              labelStyle: TextStyle(color: Colors.grey),
              enabledBorder: UnderlineInputBorder(borderSide: BorderSide(color: Color(0xFF00E676))),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancelar', style: TextStyle(color: Colors.grey)),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF00E676), foregroundColor: Colors.black),
              onPressed: () {
                final val = double.tryParse(weightController.text);
                if (val != null && val > 0) {
                  _addNewWeightRecord(val);
                  Navigator.pop(context);
                  ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('⚖️ ¡Peso actualizado con éxito!'), backgroundColor: Color(0xFF00E676)));
                }
              },
              child: const Text('Guardar', style: TextStyle(fontWeight: FontWeight.bold)),
            ),
          ],
        );
      },
    );
  }

  Widget _buildDynamicBar(String label, double weightValue, {bool isHighlight = false}) {
    return Column(
      mainAxisAlignment: MainAxisAlignment.end,
      children: [
        Container(
          width: 28,
          height: 40,
          decoration: BoxDecoration(
            color: isHighlight ? const Color(0xFF00E676) : Colors.white24,
            borderRadius: BorderRadius.circular(6),
          ),
          child: Center(
            child: Text(weightValue.toStringAsFixed(0), style: const TextStyle(fontSize: 10, color: Colors.black, fontWeight: FontWeight.bold)),
          ),
        ),
        const SizedBox(height: 4),
        Text(label, style: const TextStyle(color: Colors.grey, fontSize: 10)),
      ],
    );
  }

  Widget _buildBadgeItem(String emoji, String title, bool isUnlocked) {
    return Container(
      padding: const EdgeInsets.all(8),
      decoration: BoxDecoration(
        color: isUnlocked ? const Color(0xFF0B1015) : Colors.white.withOpacity(0.02),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: isUnlocked ? const Color(0xFF00E676).withOpacity(0.4) : Colors.white10),
      ),
      child: Row(
        children: [
          Text(emoji, style: TextStyle(fontSize: 22, color: isUnlocked ? Colors.white : Colors.grey.withOpacity(0.3))),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              title,
              style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: isUnlocked ? Colors.white : Colors.grey),
            ),
          ),
        ],
      ),
    );
  }

  void _showProfileModal() {
    final nameController = TextEditingController(text: _userProfile?.name ?? '');
    final weightController = TextEditingController(text: _userProfile?.weight.toString() ?? '');
    final heightController = TextEditingController(text: _userProfile?.height.toString() ?? '');
    final ageController = TextEditingController(text: _userProfile?.age.toString() ?? '');
    String gender = _userProfile?.gender ?? 'Masculino';
    double activity = _userProfile?.activityMultiplier ?? 1.2;
    String goalType = _userProfile?.goalType ?? 'Dieta Keto';

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: const Color(0xFF131B24),
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(25))),
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setStateModal) {
            return Padding(
              padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom, left: 20, right: 20, top: 25),
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Row(
                      children: [
                        Icon(Icons.health_and_safety, color: Color(0xFF00E676), size: 28),
                        SizedBox(width: 10),
                        Expanded(child: Text('Configuración de Perfil Clínico', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.white))),
                      ],
                    ),
                    const SizedBox(height: 15),
                    TextField(controller: nameController, style: const TextStyle(color: Colors.white), decoration: const InputDecoration(labelText: 'Tu Nombre', labelStyle: TextStyle(color: Colors.grey), prefixIcon: Icon(Icons.person, color: Color(0xFF00E676)), enabledBorder: UnderlineInputBorder(borderSide: BorderSide(color: Colors.white24)))),
                    const SizedBox(height: 12),
                    TextField(controller: ageController, keyboardType: TextInputType.number, style: const TextStyle(color: Colors.white), decoration: const InputDecoration(labelText: 'Edad', labelStyle: TextStyle(color: Colors.grey), prefixIcon: Icon(Icons.cake, color: Color(0xFF00E676)), enabledBorder: UnderlineInputBorder(borderSide: BorderSide(color: Colors.white24)))),
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        Expanded(child: TextField(controller: weightController, keyboardType: TextInputType.number, style: const TextStyle(color: Colors.white), decoration: const InputDecoration(labelText: 'Peso (kg)', labelStyle: TextStyle(color: Colors.grey), prefixIcon: Icon(Icons.monitor_weight, color: Color(0xFF00E676)), enabledBorder: UnderlineInputBorder(borderSide: BorderSide(color: Colors.white24))))),
                        const SizedBox(width: 12),
                        Expanded(child: TextField(controller: heightController, keyboardType: TextInputType.number, style: const TextStyle(color: Colors.white), decoration: const InputDecoration(labelText: 'Talla (cm)', labelStyle: TextStyle(color: Colors.grey), prefixIcon: Icon(Icons.height, color: Color(0xFF00E676)), enabledBorder: UnderlineInputBorder(borderSide: BorderSide(color: Colors.white24))))),
                      ],
                    ),
                    const SizedBox(height: 15),
                    DropdownButtonFormField<double>(
                      value: activity, isExpanded: true, dropdownColor: const Color(0xFF0B1015), style: const TextStyle(color: Colors.white),
                      items: const [
                        DropdownMenuItem(value: 1.2, child: Text('Sedentario')),
                        DropdownMenuItem(value: 1.375, child: Text('Ligero')),
                        DropdownMenuItem(value: 1.55, child: Text('Moderado')),
                        DropdownMenuItem(value: 1.725, child: Text('Intenso')),
                      ],
                      onChanged: (val) => setStateModal(() => activity = val!),
                      decoration: const InputDecoration(labelText: 'Actividad Física', labelStyle: TextStyle(color: Colors.grey), prefixIcon: Icon(Icons.fitness_center, color: Color(0xFF00E676)), enabledBorder: UnderlineInputBorder(borderSide: BorderSide(color: Colors.white24))),
                    ),
                    const SizedBox(height: 15),
                    DropdownButtonFormField<String>(
                      value: goalType, isExpanded: true, dropdownColor: const Color(0xFF0B1015), style: const TextStyle(color: Colors.white),
                      items: const [
                        DropdownMenuItem(value: 'Dieta Keto', child: Text('Dieta Keto')),
                        DropdownMenuItem(value: 'Perder Peso', child: Text('Perder Peso')),
                        DropdownMenuItem(value: 'Mantener Peso', child: Text('Mantener Peso')),
                        DropdownMenuItem(value: 'Ganar Músculo', child: Text('Ganar Músculo')),
                      ],
                      onChanged: (val) => setStateModal(() => goalType = val!),
                      decoration: const InputDecoration(labelText: 'Objetivo Nutricional', labelStyle: TextStyle(color: Colors.grey), prefixIcon: Icon(Icons.flag, color: Colors.orange), enabledBorder: UnderlineInputBorder(borderSide: BorderSide(color: Colors.white24))),
                    ),
                    const SizedBox(height: 25),
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton(
                        style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF00E676), foregroundColor: Colors.black, padding: const EdgeInsets.symmetric(vertical: 14), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))),
                        onPressed: () {
                          final name = nameController.text.trim().isEmpty ? 'Usuario' : nameController.text.trim();
                          final age = int.tryParse(ageController.text) ?? 20;
                          final weight = double.tryParse(weightController.text) ?? 70;
                          final height = double.tryParse(heightController.text) ?? 170;

                          double bmr = (10 * weight) + (6.25 * height) - (5 * age);
                          bmr += (gender == 'Masculino' ? 5 : -161);
                          double maintenanceCalories = bmr * activity;
                          
                          double calorieAdjustment = 0;
                          if (goalType == 'Dieta Keto') calorieAdjustment = -800;
                          if (goalType == 'Perder Peso') calorieAdjustment = -500;
                          if (goalType == 'Mantener Peso') calorieAdjustment = 0;
                          if (goalType == 'Ganar Músculo') calorieAdjustment = 300;

                          double targetCalories = maintenanceCalories + calorieAdjustment;
                          double proteinTarget;
                          double fatTarget;
                          double carbTarget;

                          if (goalType == 'Dieta Keto') {
                            proteinTarget = weight * 2.2;
                            carbTarget = 30; 
                            fatTarget = (targetCalories - ((proteinTarget * 4) + (carbTarget * 4))) / 9;
                            if (fatTarget < 45) fatTarget = 45;
                          } else {
                            proteinTarget = weight * 2.2;
                            fatTarget = (targetCalories * 0.30) / 9;
                            carbTarget = (targetCalories - ((proteinTarget * 4) + (fatTarget * 9))) / 4;
                            if (carbTarget < 50) carbTarget = 50;
                          }

                          _saveProfile(UserProfile(name: name, weight: weight, height: height, age: age, gender: gender, activityMultiplier: activity, goalType: goalType, calorieAdjustment: calorieAdjustment, goalCalories: targetCalories, proteinTarget: proteinTarget, carbTarget: carbTarget, fatTarget: fatTarget));
                          Navigator.pop(context);
                        },
                        child: const Text('Actualizar y Recalcular', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                      ),
                    ),
                    const SizedBox(height: 20),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }

  void _showAddFoodModal() {
    bool isAnalyzing = false;
    final ImagePicker picker = ImagePicker();
    final textController = TextEditingController();
    bool showTextInput = false;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: const Color(0xFF131B24),
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(25))),
      builder: (context) {
        return StatefulBuilder(
          builder: (BuildContext context, StateSetter setStateModal) {
            
            void _calculateWithGeminiAI({XFile? image, String? text}) async {
              setStateModal(() => isAnalyzing = true);

              try {
                String? imageBase64;
                if (image != null) {
                  final bytes = await image.readAsBytes();
                  imageBase64 = base64Encode(bytes);
                }

                final response = await http.post(
                  Uri.parse('http://localhost:8888/api/analyzeFood'),
                  headers: {'Content-Type': 'application/json'},
                  body: jsonEncode({'text': text ?? '', 'image': imageBase64}),
                );

                if (response.statusCode != 200) throw Exception('Error del servidor');

                final responseData = jsonDecode(response.body);
                String rawResult = responseData['result'] ?? '';

                String cleanedJson = rawResult;
                if (cleanedJson.contains('```json')) cleanedJson = cleanedJson.split('```json')[1].split('```')[0].trim();
                else if (cleanedJson.contains('```')) cleanedJson = cleanedJson.split('```')[1].split('```')[0].trim();
                
                int startIndex = cleanedJson.indexOf('{');
                int endIndex = cleanedJson.lastIndexOf('}');
                if (startIndex != -1 && endIndex != -1) cleanedJson = cleanedJson.substring(startIndex, endIndex + 1);

                final Map<String, dynamic> parsedData = jsonDecode(cleanedJson);

                setState(() {
                  _foodItems.add(FoodItem(
                    name: parsedData['name'] ?? 'Alimento analizado',
                    calories: (parsedData['calories'] ?? 0).toDouble(),
                    protein: (parsedData['protein'] ?? 0).toDouble(),
                    carbs: (parsedData['carbs'] ?? 0).toDouble(),
                    fat: (parsedData['fat'] ?? 0).toDouble(),
                    category: 'Registro IA',
                  ));
                });
                _saveFoodItems();

                Navigator.pop(context);
                ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('✨ ¡Registro añadido con éxito!'), backgroundColor: Color(0xFF00E676)));

              } catch (e) {
                setStateModal(() => isAnalyzing = false);
                ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error al analizar: $e'), backgroundColor: Colors.red));
              }
            }

            return Padding(
              padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom, left: 24, right: 24, top: 30),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('¿Qué comiste?', style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: Colors.white)),
                  const SizedBox(height: 8),
                  const Text('Deja que BioMacros calcule todo por ti.', style: TextStyle(color: Colors.grey, fontSize: 14)),
                  const SizedBox(height: 25),

                  if (isAnalyzing)
                    const Padding(
                      padding: EdgeInsets.symmetric(vertical: 40),
                      child: Center(
                        child: Column(
                          children: [
                            CircularProgressIndicator(color: Color(0xFF00E676)),
                            SizedBox(height: 15),
                            Text('Analizando alimento...', style: TextStyle(color: Color(0xFF00E676), fontWeight: FontWeight.bold))
                          ],
                        ),
                      ),
                    )
                  else if (showTextInput) ...[
                    TextField(
                      controller: textController, autofocus: true, maxLines: 3, style: const TextStyle(color: Colors.white),
                      decoration: InputDecoration(hintText: 'Ej. Comí 3 huevos, 2 tortillas...', hintStyle: const TextStyle(color: Colors.white24), filled: true, fillColor: const Color(0xFF0B1015), border: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: BorderSide.none)),
                    ),
                    const SizedBox(height: 15),
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton(
                        style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF00E676), foregroundColor: Colors.black, padding: const EdgeInsets.symmetric(vertical: 14), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))),
                        onPressed: () {
                          if (textController.text.trim().isNotEmpty) _calculateWithGeminiAI(text: textController.text.trim());
                        },
                        child: const Text('Analizar y Registrar', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                      ),
                    ),
                    TextButton(onPressed: () => setStateModal(() => showTextInput = false), child: const Center(child: Text('Volver', style: TextStyle(color: Colors.grey))))
                  ]
                  else ...[
                    _buildAIActionCard(icon: '📸', title: 'Tomar foto', subtitle: 'La IA estimará las porciones y macros', color: const Color(0xFF00E676), onTap: () async {
                      final XFile? image = await picker.pickImage(source: ImageSource.gallery);
                      if (image != null) _calculateWithGeminiAI(image: image);
                    }),
                    const SizedBox(height: 15),
                    _buildAIActionCard(icon: '🎙️', title: 'Describir o dictar', subtitle: 'Ej. "Comí 3 huevos y medio aguacate"', color: const Color(0xFFFF9100), onTap: () => setStateModal(() => showTextInput = true)),
                  ],
                  const SizedBox(height: 25),
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(color: Colors.white.withOpacity(0.05), borderRadius: BorderRadius.circular(10)),
                    child: const Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Icon(Icons.info_outline, color: Colors.grey, size: 16),
                        SizedBox(width: 8),
                        Expanded(child: Text('BioMacros es una herramienta de orientación y seguimiento nutricional. No sustituye la valoración de un médico. Las cantidades por foto son estimaciones.', style: TextStyle(color: Colors.grey, fontSize: 11, height: 1.4))),
                      ],
                    ),
                  ),
                  const SizedBox(height: 30),
                ],
              ),
            );
          },
        );
      },
    );
  }

  Widget _buildAIActionCard({required String icon, required String title, required String subtitle, required Color color, required VoidCallback onTap}) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(16),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(color: const Color(0xFF0B1015), borderRadius: BorderRadius.circular(16), border: Border.all(color: color.withOpacity(0.3), width: 1.5)),
        child: Row(
          children: [
            Text(icon, style: const TextStyle(fontSize: 32)),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.white)),
                  const SizedBox(height: 4),
                  Text(subtitle, style: const TextStyle(fontSize: 12, color: Colors.grey)),
                ],
              ),
            ),
            Icon(Icons.arrow_forward_ios, color: color, size: 16),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_userProfile == null) return const Scaffold(body: Center(child: CircularProgressIndicator(color: Color(0xFF00E676))));

    final goalCalories = _userProfile!.goalCalories;
    double remaining = goalCalories - _totalCalories;
    if (remaining < 0) remaining = 0;

    return Scaffold(
      backgroundColor: const Color(0xFF0B1015), 
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 20.0, vertical: 10),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Row(
                    children: [
                      const Icon(Icons.bolt, color: Color(0xFF00E676), size: 36),
                      const SizedBox(width: 8),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text('BioMacros', style: TextStyle(color: Colors.white, fontSize: 24, fontWeight: FontWeight.bold)),
                          Text('Tu biología, tus números, tus resultados.', style: TextStyle(color: Colors.grey, fontSize: 12)),
                        ],
                      ),
                    ],
                  ),
                  Row(
                    children: [
                      IconButton(icon: const Icon(Icons.picture_as_pdf, color: Color(0xFF00E676)), onPressed: _exportPdfReport),
                      GestureDetector(
                        onTap: _showProfileModal,
                        child: const CircleAvatar(backgroundColor: Color(0xFF131B24), child: Icon(Icons.person, color: Color(0xFF00E676))),
                      )
                    ],
                  )
                ],
              ),
              const SizedBox(height: 25),

              Row(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  Expanded(
                    flex: 5, 
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('¡Hola, ${_userProfile!.name}! 👋', style: const TextStyle(fontSize: 32, fontWeight: FontWeight.bold, color: Colors.white)),
                        const SizedBox(height: 6),
                        const Text('Cada comida te acerca a tu mejor versión.', style: TextStyle(color: Colors.grey, fontSize: 14)),
                        const SizedBox(height: 15),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                          decoration: BoxDecoration(color: const Color(0xFF00E676).withOpacity(0.1), borderRadius: BorderRadius.circular(20), border: Border.all(color: const Color(0xFF00E676).withOpacity(0.5))),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              const Icon(Icons.track_changes, color: Color(0xFF00E676), size: 16),
                              const SizedBox(width: 6),
                              Text('Objetivo: ${_userProfile!.goalType} >', style: const TextStyle(color: Color(0xFF00E676), fontWeight: FontWeight.bold, fontSize: 13)),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                  Expanded(
                    flex: 4, 
                    child: Center(
                      child: Container(
                        width: 160, 
                        height: 160,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          boxShadow: [
                            BoxShadow(
                              color: const Color(0xFF00E676).withOpacity(0.25), 
                              blurRadius: 35,
                              spreadRadius: 8,
                            ),
                          ],
                          image: const DecorationImage(
                            image: NetworkImage('https://images.unsplash.com/photo-1546069901-ba9599a7e63c?q=80&w=400&auto=format&fit=crop'),
                            fit: BoxFit.cover,
                          ),
                          border: Border.all(color: const Color(0xFF131B24), width: 4),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 30),

              Container(
                padding: const EdgeInsets.all(18),
                decoration: BoxDecoration(
                  color: const Color(0xFF131B24), 
                  borderRadius: BorderRadius.circular(24), 
                  boxShadow: [BoxShadow(color: const Color(0xFF00E676).withOpacity(0.05), blurRadius: 20, spreadRadius: 2)]
                ),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    SizedBox(
                      height: 130, width: 130, 
                      child: Stack(
                        fit: StackFit.expand,
                        children: [
                          CircularProgressIndicator(
                            value: (_totalCalories / goalCalories).clamp(0.0, 1.0), 
                            strokeWidth: 8, 
                            backgroundColor: Colors.white10, 
                            valueColor: const AlwaysStoppedAnimation<Color>(Color(0xFF00E676))
                          ),
                          Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              const Icon(Icons.local_fire_department, color: Color(0xFF00E676), size: 22),
                              const SizedBox(height: 2),
                              Text('${_totalCalories.toStringAsFixed(0)}', style: const TextStyle(fontSize: 26, fontWeight: FontWeight.bold, color: Colors.white, height: 1.1)),
                              const Text('kcal', style: TextStyle(color: Color(0xFF00E676), fontSize: 13, fontWeight: FontWeight.bold)),
                              Text('de ${goalCalories.toStringAsFixed(0)}', style: const TextStyle(color: Colors.grey, fontSize: 11)),
                            ],
                          )
                        ],
                      ),
                    ),
                    const SizedBox(width: 15),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text('${remaining.toStringAsFixed(0)} kcal restantes', style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 15)),
                              const Icon(Icons.arrow_forward_ios, color: Color(0xFF00E676), size: 12),
                            ],
                          ),
                          const SizedBox(height: 10),
                          const Divider(color: Colors.white10, thickness: 1, height: 1),
                          const SizedBox(height: 12),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              _buildMiniMacroBarVertical('Proteína', Icons.fitness_center, _totalProtein, _userProfile!.proteinTarget, const Color(0xFF00E676)),
                              const SizedBox(width: 6),
                              _buildMiniMacroBarVertical('Carbohidratos', Icons.grass, _totalCarbs, _userProfile!.carbTarget, Colors.amber),
                              const SizedBox(width: 6),
                              _buildMiniMacroBarVertical('Grasas', Icons.water_drop, _totalFat, _userProfile!.fatTarget, Colors.purpleAccent),
                            ],
                          ),
                        ],
                      ),
                    )
                  ],
                ),
              ),
              const SizedBox(height: 25),

              Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(color: const Color(0xFF131B24), borderRadius: BorderRadius.circular(24)),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Row(
                          children: [
                            Icon(Icons.auto_awesome, color: Color(0xFF00E676), size: 20),
                            SizedBox(width: 8),
                            Text('Registra tu comida con IA', style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold)),
                          ],
                        ),
                        Container(padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4), decoration: BoxDecoration(color: const Color(0xFF00E676).withOpacity(0.1), borderRadius: BorderRadius.circular(10)), child: const Text('¡Rápido y preciso!', style: TextStyle(color: Color(0xFF00E676), fontSize: 10, fontWeight: FontWeight.bold)))
                      ],
                    ),
                    const SizedBox(height: 4),
                    const Text('Foto o voz, y nosotros lo calculamos por ti.', style: TextStyle(color: Colors.grey, fontSize: 12)),
                    const SizedBox(height: 20),
                    Row(
                      children: [
                        Expanded(child: _buildModernActionButton(Icons.camera_alt, 'Tomar foto', 'IA visual', const Color(0xFF00E676), _showAddFoodModal)),
                        const SizedBox(width: 15),
                        Expanded(child: _buildModernActionButton(Icons.mic, 'Hablar', '"Comí 2 huevos..."', const Color(0xFF00B0FF), _showAddFoodModal)),
                      ],
                    )
                  ],
                ),
              ),
              const SizedBox(height: 25),

              GestureDetector(
                onTap: _showProgressAndBadgesModal,
                child: Container(
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(colors: [Color(0xFF00E676), Color(0xFF00A355)]),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.emoji_events, color: Colors.black, size: 40),
                      const SizedBox(width: 15),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text('Tu esfuerzo da resultados', style: TextStyle(color: Colors.black, fontWeight: FontWeight.bold, fontSize: 16)),
                            Text('Llevas $_currentStreak días consecutivos. ¡Sigue así!', style: const TextStyle(color: Colors.black87, fontSize: 12)),
                          ],
                        ),
                      ),
                      Container(padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6), decoration: BoxDecoration(color: Colors.black, borderRadius: BorderRadius.circular(12)), child: const Text('Ver progreso >', style: TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.bold)))
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 25),

              const Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text('Comidas recientes', style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold)),
                  Text('Ver todas >', style: TextStyle(color: Color(0xFF00E676), fontSize: 13)),
                ],
              ),
              const SizedBox(height: 15),
              
              _foodItems.isEmpty
                  ? const Center(child: Padding(padding: EdgeInsets.all(20.0), child: Text('No hay alimentos registrados hoy.', style: TextStyle(color: Colors.grey))))
                  : ListView.builder(
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      itemCount: _foodItems.length,
                      itemBuilder: (context, index) {
                        final item = _foodItems[index];
                        return Container(
                          margin: const EdgeInsets.only(bottom: 12),
                          padding: const EdgeInsets.all(16),
                          decoration: BoxDecoration(color: const Color(0xFF131B24), borderRadius: BorderRadius.circular(16)),
                          child: Row(
                            children: [
                              Container(padding: const EdgeInsets.all(12), decoration: BoxDecoration(color: const Color(0xFF0B1015), borderRadius: BorderRadius.circular(12)), child: const Text('🍽️', style: TextStyle(fontSize: 24))),
                              const SizedBox(width: 15),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(item.name, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: Colors.white)),
                                    const SizedBox(height: 4),
                                    Text('${item.calories.toStringAsFixed(0)} kcal', style: const TextStyle(color: Color(0xFF00E676), fontWeight: FontWeight.bold, fontSize: 13)),
                                    const SizedBox(height: 4),
                                    Text('P: ${item.protein.toStringAsFixed(0)}g | C: ${item.carbs.toStringAsFixed(0)}g | G: ${item.fat.toStringAsFixed(0)}g', style: const TextStyle(fontSize: 11, color: Colors.grey)),
                                  ],
                                ),
                              ),
                              IconButton(icon: const Icon(Icons.delete_outline, color: Colors.redAccent), onPressed: () => _deleteItem(index)),
                            ],
                          ),
                        );
                      },
                    ),
              const SizedBox(height: 100),
            ],
          ),
        ),
      ),
      
      bottomNavigationBar: BottomNavigationBar(
        backgroundColor: const Color(0xFF0B1015),
        selectedItemColor: const Color(0xFF00E676),
        unselectedItemColor: Colors.grey,
        currentIndex: _currentIndex,
        type: BottomNavigationBarType.fixed,
        onTap: (index) {
          setState(() => _currentIndex = index);
          if (index == 2) _showAddFoodModal();
          if (index == 3) _showProgressAndBadgesModal();
          if (index == 4) _showProfileModal();
        },
        items: const [
          BottomNavigationBarItem(icon: Icon(Icons.home), label: 'Inicio'),
          BottomNavigationBarItem(icon: Icon(Icons.restaurant_menu), label: 'Comida'),
          BottomNavigationBarItem(icon: Icon(Icons.add_circle, size: 40, color: Color(0xFF00E676)), label: ''),
          BottomNavigationBarItem(icon: Icon(Icons.bar_chart), label: 'Progreso'),
          BottomNavigationBarItem(icon: Icon(Icons.person_outline), label: 'Perfil'),
        ],
      ),
    );
  }

  Widget _buildMiniMacroBarVertical(String title, IconData icon, double current, double target, Color color) {
    double progress = target > 0 ? (current / target).clamp(0.0, 1.0) : 0;
    int percentage = (progress * 100).toInt();

    return Expanded(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, color: color, size: 14),
              const SizedBox(width: 4),
              Expanded(child: Text(title, style: const TextStyle(color: Colors.white70, fontSize: 10), overflow: TextOverflow.ellipsis)),
            ],
          ),
          const SizedBox(height: 6),
          RichText(
            text: TextSpan(
              children: [
                TextSpan(text: '${current.toStringAsFixed(0)}', style: const TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.bold)),
                TextSpan(text: '/${target.toStringAsFixed(0)}g', style: const TextStyle(color: Colors.white70, fontSize: 10)),
              ],
            ),
            overflow: TextOverflow.ellipsis,
          ),
          const SizedBox(height: 4),
          Text('$percentage%', style: TextStyle(color: color, fontSize: 11, fontWeight: FontWeight.bold)),
          const SizedBox(height: 4),
          LinearProgressIndicator(
            value: progress,
            backgroundColor: Colors.white10,
            color: color,
            minHeight: 4,
            borderRadius: BorderRadius.circular(2),
          ),
        ],
      ),
    );
  }

  Widget _buildModernActionButton(IconData icon, String title, String subtitle, Color color, VoidCallback onTap) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(color: color.withOpacity(0.1), borderRadius: BorderRadius.circular(16), border: Border.all(color: color.withOpacity(0.3))),
        child: Row(
          children: [
            Container(padding: const EdgeInsets.all(8), decoration: BoxDecoration(color: color, shape: BoxShape.circle), child: Icon(icon, color: Colors.black, size: 20)),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 13)),
                  Text(subtitle, style: const TextStyle(color: Colors.grey, fontSize: 9)),
                ],
              ),
            ),
            Icon(Icons.arrow_forward_ios, color: color, size: 12)
          ],
        ),
      ),
    );
  }
}
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/user_profile.dart'; // Importamos tu modelo recién separado
import 'home_screen.dart'; // ¡Este es el que marcará error rojo temporalmente!

class OnboardingScreen extends StatefulWidget {
  const OnboardingScreen({super.key});

  @override
  State<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends State<OnboardingScreen> {
  final PageController _pageController = PageController();
  int _currentPage = 0;

  final _nameController = TextEditingController();
  final _ageController = TextEditingController();
  final _weightController = TextEditingController();
  final _heightController = TextEditingController();
  String _gender = 'Masculino';
  String _goalType = 'Dieta Keto';
  double _activityLevel = 1.2;

  void _nextPage() {
    if (_currentPage == 0) {
      if (_nameController.text.isEmpty || _ageController.text.isEmpty || _weightController.text.isEmpty || _heightController.text.isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Por favor, llena todos los campos', style: TextStyle(color: Colors.white)), backgroundColor: Colors.redAccent));
        return;
      }
    }
    
    if (_currentPage < 3) {
      _pageController.nextPage(duration: const Duration(milliseconds: 300), curve: Curves.easeIn);
    } else {
      _finishOnboarding();
    }
  }

  void _finishOnboarding() async {
    final name = _nameController.text.trim();
    final age = int.tryParse(_ageController.text) ?? 20;
    final weight = double.tryParse(_weightController.text) ?? 70;
    final height = double.tryParse(_heightController.text) ?? 170;

    double bmr = (10 * weight) + (6.25 * height) - (5 * age);
    bmr += (_gender == 'Masculino' ? 5 : -161);
    double maintenanceCalories = bmr * _activityLevel;
    
    double calorieAdjustment = 0;
    if (_goalType == 'Dieta Keto') calorieAdjustment = -800;
    if (_goalType == 'Perder Peso') calorieAdjustment = -500;
    if (_goalType == 'Mantener Peso') calorieAdjustment = 0;
    if (_goalType == 'Ganar Músculo') calorieAdjustment = 300;

    double targetCalories = maintenanceCalories + calorieAdjustment;
    double proteinTarget;
    double fatTarget;
    double carbTarget;

    if (_goalType == 'Dieta Keto') {
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

    final profile = UserProfile(
      name: name, weight: weight, height: height, age: age, gender: _gender,
      activityMultiplier: _activityLevel, goalType: _goalType,
      calorieAdjustment: calorieAdjustment, goalCalories: targetCalories,
      proteinTarget: proteinTarget, carbTarget: carbTarget, fatTarget: fatTarget
    );

    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('user_profile_v15', jsonEncode(profile.toJson()));
    await prefs.setInt('current_streak_v15', 1);
    await prefs.setString('last_active_date_v15', DateTime.now().toIso8601String().split('T')[0]);
    await prefs.setStringList('weight_history_v15', [weight.toString()]);

    if (mounted) {
      Navigator.pushReplacement(context, MaterialPageRoute(builder: (context) => const HomeScreen()));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0B1015),
      body: SafeArea(
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 30, vertical: 20),
              child: Row(
                children: List.generate(4, (index) => Expanded(
                  child: Container(
                    margin: const EdgeInsets.symmetric(horizontal: 4),
                    height: 6,
                    decoration: BoxDecoration(color: index <= _currentPage ? const Color(0xFF00E676) : Colors.white10, borderRadius: BorderRadius.circular(3)),
                  )
                )),
              ),
            ),
            Expanded(
              child: PageView(
                controller: _pageController,
                physics: const NeverScrollableScrollPhysics(),
                onPageChanged: (val) => setState(() => _currentPage = val),
                children: [_buildStep1(), _buildStep2(), _buildStep3(), _buildStep4()],
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(30.0),
              child: SizedBox(
                width: double.infinity,
                height: 55,
                child: ElevatedButton(
                  style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF00E676), foregroundColor: Colors.black, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16))),
                  onPressed: _nextPage,
                  child: Text(_currentPage == 3 ? 'Comenzar mi transformación' : 'Continuar', style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                ),
              ),
            )
          ],
        ),
      ),
    );
  }

  Widget _buildStep1() {
    return SingleChildScrollView(
      padding: const EdgeInsets.symmetric(horizontal: 30),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SizedBox(height: 20),
          const Text('Cuéntame sobre ti', style: TextStyle(fontSize: 32, fontWeight: FontWeight.bold, color: Colors.white)),
          const SizedBox(height: 10),
          const Text('Necesitamos estos datos para calcular tu biología exacta.', style: TextStyle(color: Colors.grey, fontSize: 16)),
          const SizedBox(height: 40),
          _buildInput('👤', 'Tu nombre', _nameController, TextInputType.name),
          const SizedBox(height: 20),
          _buildInput('🎂', 'Edad', _ageController, TextInputType.number),
          const SizedBox(height: 20),
          Row(
            children: [
              Expanded(child: _buildInput('⚖️', 'Peso (kg)', _weightController, TextInputType.number)),
              const SizedBox(width: 15),
              Expanded(child: _buildInput('📏', 'Altura (cm)', _heightController, TextInputType.number)),
            ],
          ),
          const SizedBox(height: 25),
          const Text('Género biológico', style: TextStyle(color: Colors.grey, fontSize: 14)),
          const SizedBox(height: 10),
          Row(
            children: [
              Expanded(child: _buildOptionButton('Masculino', _gender == 'Masculino', () => setState(() => _gender = 'Masculino'))),
              const SizedBox(width: 15),
              Expanded(child: _buildOptionButton('Femenino', _gender == 'Femenino', () => setState(() => _gender = 'Femenino'))),
            ],
          )
        ],
      ),
    );
  }

  Widget _buildStep2() {
    return SingleChildScrollView(
      padding: const EdgeInsets.symmetric(horizontal: 30),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SizedBox(height: 20),
          const Text('¿Qué quieres conseguir?', style: TextStyle(fontSize: 32, fontWeight: FontWeight.bold, color: Colors.white)),
          const SizedBox(height: 30),
          _buildSelectableCard('🥑', 'Dieta Keto', 'Déficit estricto y profundo (-800 kcal)', _goalType == 'Dieta Keto', () => setState(() => _goalType = 'Dieta Keto')),
          const SizedBox(height: 12),
          _buildSelectableCard('🔥', 'Perder Peso', 'Déficit moderado (-500 kcal)', _goalType == 'Perder Peso', () => setState(() => _goalType = 'Perder Peso')),
          const SizedBox(height: 12),
          _buildSelectableCard('⚖️', 'Mantener Peso', 'Normocalórica para recomposición', _goalType == 'Mantener Peso', () => setState(() => _goalType = 'Mantener Peso')),
          const SizedBox(height: 12),
          _buildSelectableCard('💪', 'Ganar Músculo', 'Superávit calórico para hipertrofia (+300 kcal)', _goalType == 'Ganar Músculo', () => setState(() => _goalType = 'Ganar Músculo')),
        ],
      ),
    );
  }

  Widget _buildStep3() {
    return SingleChildScrollView(
      padding: const EdgeInsets.symmetric(horizontal: 30),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SizedBox(height: 20),
          const Text('¿Cómo entrenas?', style: TextStyle(fontSize: 32, fontWeight: FontWeight.bold, color: Colors.white)),
          const SizedBox(height: 30),
          _buildSelectableCard('🛋️', 'Sedentario', 'Poco o ningún ejercicio', _activityLevel == 1.2, () => setState(() => _activityLevel = 1.2)),
          const SizedBox(height: 12),
          _buildSelectableCard('🚶', 'Ligero', 'Ejercicio 1 a 3 días por semana', _activityLevel == 1.375, () => setState(() => _activityLevel = 1.375)),
          const SizedBox(height: 12),
          _buildSelectableCard('🏃', 'Moderado', 'Ejercicio 3 a 5 días por semana', _activityLevel == 1.55, () => setState(() => _activityLevel = 1.55)),
          const SizedBox(height: 12),
          _buildSelectableCard('🏋️', 'Intenso', 'Ejercicio duro 6 a 7 días', _activityLevel == 1.725, () => setState(() => _activityLevel = 1.725)),
        ],
      ),
    );
  }

  Widget _buildStep4() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 30),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Container(padding: const EdgeInsets.all(20), decoration: BoxDecoration(shape: BoxShape.circle, color: const Color(0xFF00E676).withOpacity(0.2)), child: const Icon(Icons.check_circle, color: Color(0xFF00E676), size: 80)),
          const SizedBox(height: 30),
          const Text('¡Todo listo, tu perfil ha sido creado!', textAlign: TextAlign.center, style: TextStyle(fontSize: 28, fontWeight: FontWeight.bold, color: Colors.white)),
          const SizedBox(height: 15),
          const Text('Hemos calculado tus requerimientos metabólicos con base científica. Tu transformación comienza hoy.', textAlign: TextAlign.center, style: TextStyle(color: Colors.grey, fontSize: 16, height: 1.5)),
        ],
      ),
    );
  }

  Widget _buildInput(String emoji, String hint, TextEditingController controller, TextInputType type) {
    return TextField(
      controller: controller, keyboardType: type, style: const TextStyle(color: Colors.white, fontSize: 18),
      decoration: InputDecoration(prefixIcon: Padding(padding: const EdgeInsets.all(15.0), child: Text(emoji, style: const TextStyle(fontSize: 20))), labelText: hint, labelStyle: const TextStyle(color: Colors.grey), filled: true, fillColor: const Color(0xFF131B24), border: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: BorderSide.none)),
    );
  }

  Widget _buildOptionButton(String text, bool isSelected, VoidCallback onTap) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 16),
        decoration: BoxDecoration(color: isSelected ? const Color(0xFF00E676).withOpacity(0.2) : const Color(0xFF131B24), border: Border.all(color: isSelected ? const Color(0xFF00E676) : Colors.transparent, width: 2), borderRadius: BorderRadius.circular(16)),
        child: Center(child: Text(text, style: TextStyle(color: isSelected ? const Color(0xFF00E676) : Colors.white, fontWeight: FontWeight.bold))),
      ),
    );
  }

  Widget _buildSelectableCard(String emoji, String title, String subtitle, bool isSelected, VoidCallback onTap) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(18),
        decoration: BoxDecoration(color: isSelected ? const Color(0xFF00E676).withOpacity(0.1) : const Color(0xFF131B24), border: Border.all(color: isSelected ? const Color(0xFF00E676) : Colors.transparent, width: 2), borderRadius: BorderRadius.circular(16)),
        child: Row(
          children: [
            Text(emoji, style: const TextStyle(fontSize: 26)),
            const SizedBox(width: 15),
            Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text(title, style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: isSelected ? const Color(0xFF00E676) : Colors.white)), const SizedBox(height: 4), Text(subtitle, style: const TextStyle(fontSize: 12, color: Colors.grey))])),
            if (isSelected) const Icon(Icons.check_circle, color: Color(0xFF00E676))
          ],
        ),
      ),
    );
  }
}
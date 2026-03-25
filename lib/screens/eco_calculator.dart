import 'package:flutter/material.dart';
import 'package:confetti/confetti.dart';
import 'package:eco_tourism/widgets/app_navigation_drawer.dart';
import 'package:eco_tourism/widgets/custom_app_bar.dart';

class EcoCalculator extends StatefulWidget {
  const EcoCalculator({super.key});

  @override
  State<EcoCalculator> createState() => _EcoCalculatorState();
}

class _EcoCalculatorState extends State<EcoCalculator> {
  // Input Controllers
  final TextEditingController distanceController = TextEditingController();
  final TextEditingController nightsController = TextEditingController();
  final TextEditingController wasteController = TextEditingController();
  final TextEditingController treesController = TextEditingController();

  late ConfettiController _confettiController;

  // State Variables
  String selectedTravel = 'Car';
  String selectedStay = 'Hotel';
  String selectedActivity = 'Easy';
  double totalResult = 0;

  // Emission Factors
  final Map<String, double> travelFactors = {
    'Car': 0.12,
    'Bus': 0.05,
    'Bike': 0.02,
    'Trekking': 0.0,
  };

  final Map<String, IconData> travelIcons = {
    'Car': Icons.directions_car_filled_outlined,
    'Bus': Icons.directions_bus_outlined,
    'Bike': Icons.directions_bike_outlined,
    'Trekking': Icons.directions_walk_outlined,
  };

  final Map<String, double> stayFactors = {
    'Hotel': 22.5,
    'Homestay': 7.5,
    'Camping': 3.5,
  };

  final Map<String, double> activityLevels = {
    'Easy': 1.0,
    'Moderate': 2.0,
    'Hard': 3.0,
  };

  @override
  void initState() {
    super.initState();
    _confettiController = ConfettiController(duration: const Duration(seconds: 3));
  }

  @override
  void dispose() {
    _confettiController.dispose();
    distanceController.dispose();
    nightsController.dispose();
    wasteController.dispose();
    treesController.dispose();
    super.dispose();
  }

  void calculateFootprint() {
    double dist = double.tryParse(distanceController.text) ?? 0;
    double cTravel = dist * (travelFactors[selectedTravel] ?? 0);

    double nights = double.tryParse(nightsController.text) ?? 0;
    double cStay = nights * (stayFactors[selectedStay] ?? 0);

    double cActivity = (activityLevels[selectedActivity] ?? 1) * 2.0;

    double waste = double.tryParse(wasteController.text) ?? 0;
    double cWaste = waste * 2.5;

    double trees = double.tryParse(treesController.text) ?? 0;
    double cOffset = trees * 20;

    setState(() {
      totalResult = (cTravel + cStay + cActivity + cWaste) - cOffset;
      if (totalResult < 0) totalResult = 0;
    });

    _showResultPopup();
  }

  void _showResultPopup() {
    bool isLowImpact = totalResult < 10;
    if (isLowImpact) _confettiController.play();

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: const Color(0xFF1A1F23),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Text(
          isLowImpact ? "🎉 Great Job!" : "⚠️ Impact Warning",
          style: TextStyle(color: isLowImpact ? Colors.greenAccent : Colors.orangeAccent),
          textAlign: TextAlign.center,
        ),
        content: Text(
          isLowImpact 
            ? "Your carbon footprint is impressively low! Keep up the eco-friendly trekking." 
            : "Your footprint is a bit high. Consider trekking more or planting trees!",
          textAlign: TextAlign.center,
          style: const TextStyle(color: Colors.white70),
        ),
        actions: [
          Center(
            child: TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text("OK", style: TextStyle(color: Colors.greenAccent, fontWeight: FontWeight.bold)),
            ),
          )
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      drawer: const AppNavigationDrawer(),
      body: Column(
        children: [
          CustomAppBar(
            title: 'ECO CALC',
            onMenuTap: () => Scaffold.of(context).openDrawer(),
          ),
          Expanded(
            child: Stack(
              alignment: Alignment.topCenter,
              children: [
                SingleChildScrollView(
                  padding: const EdgeInsets.fromLTRB(20, 20, 20, 40),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: const [
                          Icon(Icons.eco, color: Colors.greenAccent, size: 18),
                          SizedBox(width: 8),
                          Text(
                            "ECO CALCULATOR",
                            style: TextStyle(
                              color: Colors.greenAccent,
                              fontSize: 12,
                              fontWeight: FontWeight.w700,
                              letterSpacing: 2,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      RichText(
                        text: const TextSpan(
                          children: [
                            TextSpan(
                              text: "Footprint\n",
                              style: TextStyle(
                                color: Colors.white,
                                fontSize: 34,
                                fontWeight: FontWeight.bold,
                                height: 1.1,
                              ),
                            ),
                            TextSpan(
                              text: "Calculator",
                              style: TextStyle(
                                color: Colors.greenAccent,
                                fontSize: 34,
                                fontWeight: FontWeight.bold,
                                height: 1.1,
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 12),
                      const Text("Measure the environmental impact of your travel to the trailhead.", 
                        style: TextStyle(color: Colors.white54, fontSize: 14)),
                      
                      const SizedBox(height: 30),
                      _buildSectionHeader("TRANSPORT MODE"),
                      _buildTransportSelector(),

                      const SizedBox(height: 20),
                      _buildSectionHeader("ONE WAY DISTANCE (KM)"),
                      _buildTextField(distanceController, "Distance to trailhead"),

                      const SizedBox(height: 20),
                _buildSectionHeader("ACCOMMODATION"),
                _buildDropdown(stayFactors.keys.toList(), selectedStay, (val) => setState(() => selectedStay = val!)),
                _buildTextField(nightsController, "Number of Nights"),

                const SizedBox(height: 20),
                _buildSectionHeader("TRAIL DIFFICULTY"),
                _buildDropdown(activityLevels.keys.toList(), selectedActivity, (val) => setState(() => selectedActivity = val!)),

                const SizedBox(height: 20),
                _buildSectionHeader("WASTE (KG) & OFFSET (TREES)"),
                Row(
                  children: [
                    Expanded(child: _buildTextField(wasteController, "Waste kg")),
                    const SizedBox(width: 10),
                    Expanded(child: _buildTextField(treesController, "Trees")),
                  ],
                ),

                const SizedBox(height: 30),
                ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.greenAccent,
                    minimumSize: const Size.fromHeight(55),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(30)),
                  ),
                  onPressed: calculateFootprint,
                  child: const Text("CALCULATE IMPACT", 
                    style: TextStyle(color: Colors.black, fontWeight: FontWeight.bold)),
                ),

                const SizedBox(height: 30),
                _buildResultCard(),
              ],
            ),
          ),
          ConfettiWidget(
            confettiController: _confettiController,
            blastDirectionality: BlastDirectionality.explosive,
            shouldLoop: false,
            colors: const [Colors.green, Colors.blue, Colors.yellow, Colors.white],
          ),
                ],
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildResultCard() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: const Color(0xFF1A1F23),
        borderRadius: BorderRadius.circular(24),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            "Total Impact",
            style: TextStyle(color: Colors.white54, fontSize: 16),
          ),
          const SizedBox(height: 12),
          Text(
            "${totalResult.toStringAsFixed(2)} kg CO2",
            style: const TextStyle(
              color: Colors.greenAccent, 
              fontSize: 36,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 12),
          Text(
            "Equivalent to planting ${(totalResult * 5).toStringAsFixed(1)} trees",
            style: const TextStyle(color: Colors.white70, fontSize: 16),
          ),
        ],
      ),
    );
  }

  Widget _buildTransportSelector() {
    return Container(
      padding: const EdgeInsets.all(6),
      decoration: BoxDecoration(color: Colors.white.withOpacity(0.08), borderRadius: BorderRadius.circular(20)),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: travelIcons.keys.map((mode) {
          bool isSelected = selectedTravel == mode;
          return Expanded(
            child: GestureDetector(
              onTap: () => setState(() => selectedTravel = mode),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                padding: const EdgeInsets.symmetric(vertical: 12),
                decoration: BoxDecoration(
                  color: isSelected ? Colors.greenAccent.withOpacity(0.1) : Colors.transparent,
                  borderRadius: BorderRadius.circular(15),
                ),
                child: Column(
                  children: [
                    Icon(travelIcons[mode], color: isSelected ? Colors.greenAccent : Colors.white30, size: 26),
                    const SizedBox(height: 4),
                    Text(mode.toUpperCase(), style: TextStyle(color: isSelected ? Colors.greenAccent : Colors.white30, fontSize: 9, fontWeight: FontWeight.bold)),
                  ],
                ),
              ),
            ),
          );
        }).toList(),
      ),
    );
  }

  // CHANGED: Title Color here affects all box headings
  Widget _buildSectionHeader(String title) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8, left: 4),
      child: Text(
        title, 
        style: const TextStyle(
          color: Colors.greenAccent, // Changed from white38 to greenAccent
          fontSize: 11, 
          fontWeight: FontWeight.bold, 
          letterSpacing: 1.2
        ),
      ),
    );
  }

  Widget _buildDropdown(List<String> items, String currentVal, ValueChanged<String?> onChanged) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.symmetric(horizontal: 16),
      decoration: BoxDecoration(color: Colors.white10, borderRadius: BorderRadius.circular(15)),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<String>(
          value: currentVal,
          isExpanded: true,
          dropdownColor: Colors.grey[900],
          style: const TextStyle(color: Colors.white),
          items: items.map((e) => DropdownMenuItem(value: e, child: Text(e))).toList(),
          onChanged: onChanged,
        ),
      ),
    );
  }

  Widget _buildTextField(TextEditingController controller, String hint) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      child: TextField(
        controller: controller,
        keyboardType: TextInputType.number,
        style: const TextStyle(color: Colors.white),
        decoration: InputDecoration(
          hintText: hint,
          hintStyle: const TextStyle(color: Colors.white24, fontSize: 14),
          filled: true,
          fillColor: Colors.white10,
          border: OutlineInputBorder(borderRadius: BorderRadius.circular(15), borderSide: BorderSide.none),
          contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
        ),
      ),
    );
  }
}
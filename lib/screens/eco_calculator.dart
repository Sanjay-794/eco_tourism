import 'package:flutter/material.dart';

class EcoCalculator extends StatefulWidget {
  const EcoCalculator({super.key});

  @override
  State<EcoCalculator> createState() =>
      _EcoCalculatorState();
}

class _EcoCalculatorState
    extends State<EcoCalculator> {

  int selectedMode = 0;

  final TextEditingController distance =
      TextEditingController();

  double result = 0;

  /// emission factors (demo values)
  final factors = [0.21, 0.1, 0.02]; 
  // car, bus, bike

  void calculate() {
    double d =
        double.tryParse(distance.text) ?? 0;

    setState(() {
      result = d * factors[selectedMode];
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: SafeArea(
        child: Padding(
          padding:
              const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment:
                CrossAxisAlignment.start,
            children: [

              const Text(
                "Footprint Calculator",
                style: TextStyle(
                  color: Colors.greenAccent,
                  fontSize: 28,
                  fontWeight:
                      FontWeight.bold,
                ),
              ),

              const SizedBox(height: 8),

              const Text(
                "Measure environmental impact",
                style: TextStyle(
                    color: Colors.white54),
              ),

              const SizedBox(height: 20),

              /// MODE SELECT
              Container(
                decoration:
                    BoxDecoration(
                  color: Colors.blueGrey
                      .withOpacity(0.2),
                  borderRadius:
                      BorderRadius.circular(
                          30),
                ),
                child: Row(
                  mainAxisAlignment:
                      MainAxisAlignment
                          .spaceAround,
                  children: [
                    _modeButton(
                        0, "CAR"),
                    _modeButton(
                        1, "BUS"),
                    _modeButton(
                        2, "BIKE"),
                  ],
                ),
              ),

              const SizedBox(height: 20),

              /// DISTANCE
              TextField(
                controller: distance,
                keyboardType:
                    TextInputType.number,
                style: const TextStyle(
                    color: Colors.white),
                decoration:
                    InputDecoration(
                  hintText:
                      "Distance KM",
                  hintStyle:
                      const TextStyle(
                          color:
                              Colors.white54),
                  filled: true,
                  fillColor: Colors
                      .blueGrey
                      .withOpacity(0.2),
                  border:
                      OutlineInputBorder(
                    borderRadius:
                        BorderRadius
                            .circular(20),
                  ),
                ),
              ),

              const SizedBox(height: 20),

              /// BUTTON
              ElevatedButton(
                style:
                    ElevatedButton
                        .styleFrom(
                  backgroundColor:
                      Colors.greenAccent,
                  minimumSize:
                      const Size
                          .fromHeight(50),
                ),
                onPressed: calculate,
                child: const Text(
                  "CALCULATE",
                  style: TextStyle(
                      color: Colors.black),
                ),
              ),

              const SizedBox(height: 20),

              /// RESULT CARD
              Container(
                padding:
                    const EdgeInsets.all(
                        16),
                decoration:
                    BoxDecoration(
                  color: Colors
                      .blueGrey
                      .withOpacity(0.2),
                  borderRadius:
                      BorderRadius
                          .circular(20),
                ),
                child: Column(
                  crossAxisAlignment:
                      CrossAxisAlignment
                          .start,
                  children: [

                    const Text(
                      "Total Impact",
                      style: TextStyle(
                          color:
                              Colors.white54),
                    ),

                    const SizedBox(
                        height: 6),

                    Text(
                      "${result.toStringAsFixed(2)} kg CO2",
                      style:
                          const TextStyle(
                        color: Colors
                            .greenAccent,
                        fontSize: 22,
                        fontWeight:
                            FontWeight
                                .bold,
                      ),
                    ),

                    const SizedBox(
                        height: 6),

                    Text(
                      "Equivalent to planting ${(result * 5).toStringAsFixed(1)} trees",
                      style:
                          const TextStyle(
                        color:
                            Colors.white70,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _modeButton(
      int index, String text) {
    bool selected =
        selectedMode == index;

    return GestureDetector(
      onTap: () {
        setState(() {
          selectedMode = index;
        });
      },
      child: Container(
        padding:
            const EdgeInsets.symmetric(
                horizontal: 20,
                vertical: 12),
        decoration: BoxDecoration(
          color: selected
              ? Colors.green
              : Colors.transparent,
          borderRadius:
              BorderRadius.circular(
                  30),
        ),
        child: Text(
          text,
          style: TextStyle(
            color: selected
                ? Colors.black
                : Colors.white,
          ),
        ),
      ),
    );
  }
}
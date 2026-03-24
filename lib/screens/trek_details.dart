import 'package:flutter/material.dart';

class TrekDetails extends StatelessWidget {
  const TrekDetails({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: SingleChildScrollView(
        child: Column(
          children: [

            /// IMAGE HEADER
            Stack(
              children: [

                Image.asset(
                  "assets/waterfall.jpg",
                  height: 320,
                  width: double.infinity,
                  fit: BoxFit.cover,
                ),

                Container(
                  height: 320,
                  color: Colors.black.withOpacity(0.4),
                ),

                Positioned(
                  bottom: 20,
                  left: 16,
                  right: 16,
                  child: Column(
                    crossAxisAlignment:
                        CrossAxisAlignment.start,
                    children: [

                      /// SAFE BADGE
                      Container(
                        padding:
                            const EdgeInsets.symmetric(
                                horizontal: 12,
                                vertical: 6),
                        decoration: BoxDecoration(
                          color: Colors.green
                              .withOpacity(0.2),
                          borderRadius:
                              BorderRadius.circular(
                                  20),
                        ),
                        child: const Text(
                          "SAFE",
                          style: TextStyle(
                              color: Colors.green),
                        ),
                      ),

                      const SizedBox(height: 8),

                      const Text(
                        "Hidden Waterfall Trail",
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 26,
                          fontWeight:
                              FontWeight.bold,
                        ),
                      ),

                      const SizedBox(height: 6),

                      const Text(
                        "Olympic National Park • 3.4 miles • 2h 15m",
                        style: TextStyle(
                            color: Colors.white70),
                      ),
                    ],
                  ),
                )
              ],
            ),

            const SizedBox(height: 16),

            /// CONDITIONS CARD
            _card(
              child: Row(
                mainAxisAlignment:
                    MainAxisAlignment.spaceBetween,
                children: const [

                  Column(
                    crossAxisAlignment:
                        CrossAxisAlignment.start,
                    children: [
                      Text(
                        "24°C",
                        style: TextStyle(
                            color: Colors.white,
                            fontSize: 24),
                      ),
                      Text(
                        "Sunny",
                        style: TextStyle(
                            color:
                                Colors.greenAccent),
                      )
                    ],
                  ),

                  Icon(
                    Icons.wb_sunny,
                    color: Colors.yellow,
                    size: 40,
                  )
                ],
              ),
            ),

            /// CROWD CARD
            _card(
              child: Column(
                crossAxisAlignment:
                    CrossAxisAlignment.start,
                children: [

                  const Text(
                    "Low Activity",
                    style: TextStyle(
                        color: Colors.white),
                  ),

                  const SizedBox(height: 8),

                  LinearProgressIndicator(
                    value: 0.3,
                    color: Colors.greenAccent,
                    backgroundColor:
                        Colors.white24,
                  )
                ],
              ),
            ),

            /// ABOUT
            Padding(
              padding:
                  const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment:
                    CrossAxisAlignment.start,
                children: const [

                  Text(
                    "About this trail",
                    style: TextStyle(
                        color: Colors.white,
                        fontSize: 18),
                  ),

                  SizedBox(height: 8),

                  Text(
                    "A moderate trek through ancient cedar groves leading to a secluded waterfall.",
                    style: TextStyle(
                        color: Colors.white70),
                  )
                ],
              ),
            ),

            /// CHECK IN
            Padding(
              padding:
                  const EdgeInsets.symmetric(
                      horizontal: 16),
              child: ElevatedButton(
                style:
                    ElevatedButton.styleFrom(
                  backgroundColor:
                      Colors.greenAccent,
                  minimumSize:
                      const Size.fromHeight(
                          50),
                ),
                onPressed: () {},
                child: const Text(
                  "CHECK-IN",
                  style: TextStyle(
                      color: Colors.black),
                ),
              ),
            ),

            const SizedBox(height: 10),

            /// EMERGENCY BUTTON
            OutlinedButton(
              onPressed: () {},
              child:
                  const Text("VIEW EMERGENCY INFO"),
            ),

            const SizedBox(height: 20),

            /// RADAR CARD
            _card(
              child: const Center(
                child: Text(
                  "EXPAND LIVE RADAR",
                  style: TextStyle(
                      color: Colors.white),
                ),
              ),
            ),

            const SizedBox(height: 30),
          ],
        ),
      ),
    );
  }

  Widget _card({required Widget child}) {
    return Container(
      margin:
          const EdgeInsets.symmetric(
              horizontal: 16,
              vertical: 8),
      padding:
          const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.blueGrey
            .withOpacity(0.2),
        borderRadius:
            BorderRadius.circular(20),
      ),
      child: child,
    );
  }
}
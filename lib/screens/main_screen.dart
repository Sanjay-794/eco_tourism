import 'package:flutter/material.dart';

class MainScreen extends StatelessWidget {
  const MainScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: SafeArea(
        child: SingleChildScrollView(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment:
                  CrossAxisAlignment.start,
              children: [

                /// TITLE
                const Text(
                  "EMERGENCY HUB",
                  style: TextStyle(
                    color: Colors.redAccent,
                    fontSize: 26,
                    fontWeight: FontWeight.bold,
                  ),
                ),

                const SizedBox(height: 6),

                const Text(
                  "Immediate assistance and critical survival protocols.",
                  style: TextStyle(
                    color: Colors.white54,
                  ),
                ),

                const SizedBox(height: 20),

                /// SOS CARD
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(
                      colors: [
                        Colors.red,
                        Colors.redAccent
                      ],
                    ),
                    borderRadius:
                        BorderRadius.circular(20),
                  ),
                  child: Column(
                    crossAxisAlignment:
                        CrossAxisAlignment.start,
                    children: [

                      const Text(
                        "Broadcast SOS Signal",
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 18,
                          fontWeight:
                              FontWeight.bold,
                        ),
                      ),

                      const SizedBox(height: 6),

                      const Text(
                        "Sends GPS location to nearest rescue team",
                        style: TextStyle(
                          color: Colors.white70,
                        ),
                      ),

                      const SizedBox(height: 12),

                      ElevatedButton(
                        style:
                            ElevatedButton.styleFrom(
                          backgroundColor:
                              Colors.white,
                          foregroundColor:
                              Colors.red,
                        ),
                        onPressed: () {},
                        child: const Text(
                            "ACTIVATE NOW"),
                      )
                    ],
                  ),
                ),

                const SizedBox(height: 20),

                /// CONTACT CARDS
                _contactCard(
                  "Police",
                  "Law Enforcement",
                ),

                _contactCard(
                  "Ambulance",
                  "Medical Response",
                ),

                _contactCard(
                  "Mountain Rescue",
                  "Search & Rescue",
                ),

                const SizedBox(height: 20),

                /// SECTION TITLE
                Row(
                  mainAxisAlignment:
                      MainAxisAlignment
                          .spaceBetween,
                  children: const [

                    Text(
                      "Safety Protocols",
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 20,
                        fontWeight:
                            FontWeight.bold,
                      ),
                    ),

                    Text(
                      "VIEW ALL",
                      style: TextStyle(
                        color:
                            Colors.greenAccent,
                      ),
                    )
                  ],
                ),

                const SizedBox(height: 12),

                /// PROTOCOL CARD
                Container(
                  padding:
                      const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Colors.blueGrey
                        .withOpacity(0.3),
                    borderRadius:
                        BorderRadius.circular(
                            20),
                  ),
                  child: Column(
                    crossAxisAlignment:
                        CrossAxisAlignment
                            .start,
                    children: const [

                      Text(
                        "Hypothermia Prevention",
                        style: TextStyle(
                          color:
                              Colors.white,
                          fontSize: 18,
                          fontWeight:
                              FontWeight.bold,
                        ),
                      ),

                      SizedBox(height: 6),

                      Text(
                        "Learn early symptoms and proper layering",
                        style: TextStyle(
                          color:
                              Colors.white54,
                        ),
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 12),

                _guideCard(
                    "Trail Navigation"),
                _guideCard(
                    "First Aid Basics"),
                _guideCard(
                    "Emergency Signaling"),

                const SizedBox(height: 20),
              ],
            ),
          ),
        ),
      ),
    );
  }

  /// CONTACT CARD
  Widget _contactCard(
      String title, String subtitle) {
    return Container(
      margin:
          const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.blueGrey
            .withOpacity(0.2),
        borderRadius:
            BorderRadius.circular(20),
      ),
      child: Column(
        crossAxisAlignment:
            CrossAxisAlignment.start,
        children: [

          Text(
            title,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 18,
              fontWeight:
                  FontWeight.bold,
            ),
          ),

          Text(
            subtitle,
            style: const TextStyle(
              color: Colors.white54,
            ),
          ),

          const SizedBox(height: 10),

          OutlinedButton(
            onPressed: () {},
            child:
                const Text("CALL 911"),
          )
        ],
      ),
    );
  }

  /// GUIDE CARD
  Widget _guideCard(String title) {
    return Container(
      margin:
          const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.blueGrey
            .withOpacity(0.2),
        borderRadius:
            BorderRadius.circular(20),
      ),
      child: Column(
        crossAxisAlignment:
            CrossAxisAlignment.start,
        children: [

          Text(
            title,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 16,
              fontWeight:
                  FontWeight.bold,
            ),
          ),

          const SizedBox(height: 6),

          const Text(
            "Expand Guide",
            style: TextStyle(
              color: Colors.greenAccent,
            ),
          ),
        ],
      ),
    );
  }
}
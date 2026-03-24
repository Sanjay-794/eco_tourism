import 'package:flutter/material.dart';

class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        children: [

          /// BACKGROUND
          Positioned.fill(
            child: Image.asset(
              "assets/bg.jpg",
              fit: BoxFit.cover,
            ),
          ),

          Positioned.fill(
            child: Container(
              color: Colors.black.withOpacity(0.6),
            ),
          ),

          SafeArea(
            child: Column(
              children: [

                /// TOP BAR
                Padding(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 16, vertical: 10),
                  child: Row(
                    mainAxisAlignment:
                        MainAxisAlignment.spaceBetween,
                    children: [

                      const Icon(
                        Icons.menu,
                        color: Colors.greenAccent,
                      ),

                      const Text(
                        "TRAILSAFE",
                        style: TextStyle(
                          color: Colors.greenAccent,
                          fontWeight: FontWeight.bold,
                          letterSpacing: 2,
                        ),
                      ),

                      const CircleAvatar(
                        backgroundImage:
                            NetworkImage(
                          "https://i.pravatar.cc/100",
                        ),
                      )
                    ],
                  ),
                ),

                /// SEARCH
                Padding(
                  padding: const EdgeInsets.all(16),
                  child: Container(
                    padding:
                        const EdgeInsets.symmetric(
                            horizontal: 12),
                    decoration: BoxDecoration(
                      color: Colors.black54,
                      borderRadius:
                          BorderRadius.circular(30),
                    ),
                    child: const TextField(
                      style: TextStyle(
                          color: Colors.white),
                      decoration: InputDecoration(
                        icon: Icon(
                          Icons.search,
                          color: Colors.white54,
                        ),
                        hintText:
                            "Search trails...",
                        hintStyle:
                            TextStyle(
                                color:
                                    Colors.white54),
                        border:
                            InputBorder.none,
                      ),
                    ),
                  ),
                ),

                const Spacer(),

                /// BOTTOM CARD
                Container(
                  margin:
                      const EdgeInsets.all(16),
                  padding:
                      const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Colors.black87,
                    borderRadius:
                        BorderRadius.circular(
                            20),
                  ),
                  child: Column(
                    crossAxisAlignment:
                        CrossAxisAlignment
                            .start,
                    children: [

                      const Text(
                        "Hidden Waterfall Trail",
                        style: TextStyle(
                          color:
                              Colors.white,
                          fontSize: 18,
                          fontWeight:
                              FontWeight.bold,
                        ),
                      ),

                      const SizedBox(
                          height: 6),

                      Row(
                        mainAxisAlignment:
                            MainAxisAlignment
                                .spaceBetween,
                        children: const [

                          Text(
                            "SAFE STATUS",
                            style:
                                TextStyle(
                              color: Colors
                                  .greenAccent,
                            ),
                          ),

                          Text(
                            "4.2 mi",
                            style:
                                TextStyle(
                              color: Colors
                                  .greenAccent,
                              fontWeight:
                                  FontWeight
                                      .bold,
                            ),
                          ),
                        ],
                      ),

                      const SizedBox(
                          height: 12),

                      Row(
                        mainAxisAlignment:
                            MainAxisAlignment
                                .spaceBetween,
                        children: [
                          _chip("68°F"),
                          _chip("Difficulty"),
                          _chip(
                              "Cell Service"),
                        ],
                      ),

                      const SizedBox(
                          height: 12),

                      ElevatedButton(
                        style:
                            ElevatedButton
                                .styleFrom(
                          backgroundColor:
                              Colors
                                  .greenAccent,
                          minimumSize:
                              const Size
                                  .fromHeight(
                                      45),
                        ),
                        onPressed: () {},
                        child:
                            const Text(
                          "CHECK-IN",
                          style:
                              TextStyle(
                            color:
                                Colors
                                    .black,
                          ),
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

  Widget _chip(String text) {
    return Container(
      padding:
          const EdgeInsets.symmetric(
              horizontal: 10,
              vertical: 6),
      decoration: BoxDecoration(
        color: Colors.black54,
        borderRadius:
            BorderRadius.circular(
                12),
      ),
      child: Text(
        text,
        style: const TextStyle(
            color: Colors.white),
      ),
    );
  }
}
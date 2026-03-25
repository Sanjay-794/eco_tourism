import 'package:flutter/material.dart';
import 'package:eco_tourism/services/checkin_service.dart';

class MyActivityScreen extends StatefulWidget {
  const MyActivityScreen({super.key});

  @override
  State<MyActivityScreen> createState() => _MyActivityScreenState();
}

class _MyActivityScreenState extends State<MyActivityScreen> {
  late Future<List<Map<String, dynamic>>> _historyFuture;

  @override
  void initState() {
    super.initState();
    _historyFuture = CheckInService.getCheckInHistory();
  }

  Future<void> _refreshHistory() async {
    setState(() {
      _historyFuture = CheckInService.getCheckInHistory();
    });
    await _historyFuture;
  }

  Future<void> _undoCheckIn(Map<String, dynamic> item) async {
    final trailId = (item['trailId'] ?? '').toString();
    if (trailId.isEmpty) return;

    final result = await CheckInService.undoCheckIn(trailId);
    if (!mounted) return;

    if (result == UndoCheckInResult.success) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Check-in undone. You can check in another trek now.')),
      );
      await _refreshHistory();
      return;
    }

    if (result == UndoCheckInResult.notCheckedIn) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('This trek is not currently active for this device.')),
      );
      return;
    }

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Unable to undo check-in right now.')),
    );
  }

  String _formatTime(String? rawIso) {
    final dt = DateTime.tryParse(rawIso ?? '');
    if (dt == null) return '--';
    return '${dt.day}/${dt.month}/${dt.year} ${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')}';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black,
        foregroundColor: Colors.greenAccent,
        title: const Text('My Activity'),
      ),
      body: FutureBuilder<List<Map<String, dynamic>>>(
        future: _historyFuture,
        builder: (context, snapshot) {
          if (!snapshot.hasData) {
            return const Center(child: CircularProgressIndicator());
          }

          final history = snapshot.data!;
          if (history.isEmpty) {
            return const Center(
              child: Text(
                'No check-ins yet.',
                style: TextStyle(color: Colors.white70),
              ),
            );
          }

          return RefreshIndicator(
            onRefresh: _refreshHistory,
            child: ListView.builder(
              padding: const EdgeInsets.all(16),
              itemCount: history.length,
              itemBuilder: (context, index) {
                final item = history[index];
                final isActive = item['isActive'] == true;
                final trailName = (item['trailName'] ?? 'Unknown Trail').toString();
                final checkedAt = _formatTime(item['checkedInAt']?.toString());
                final undoneAt = _formatTime(item['undoneAt']?.toString());

                return Container(
                  margin: const EdgeInsets.only(bottom: 12),
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: const Color(0xFF101827),
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(
                      color: isActive ? Colors.cyanAccent : Colors.white24,
                    ),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: Text(
                              trailName,
                              style: const TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.bold,
                                fontSize: 16,
                              ),
                            ),
                          ),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                            decoration: BoxDecoration(
                              color: isActive
                                  ? Colors.cyanAccent.withValues(alpha: 0.2)
                                  : Colors.white10,
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Text(
                              isActive ? 'ACTIVE' : 'UNDONE',
                              style: TextStyle(
                                color: isActive ? Colors.cyanAccent : Colors.white70,
                                fontSize: 11,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'Checked in: $checkedAt',
                        style: const TextStyle(color: Colors.white70),
                      ),
                      if (!isActive)
                        Text(
                          'Undone: $undoneAt',
                          style: const TextStyle(color: Colors.white60),
                        ),
                      if (isActive) ...[
                        const SizedBox(height: 10),
                        OutlinedButton(
                          onPressed: () => _undoCheckIn(item),
                          style: OutlinedButton.styleFrom(
                            minimumSize: const Size.fromHeight(40),
                            side: const BorderSide(color: Colors.orangeAccent),
                          ),
                          child: const Text(
                            'UNDO CHECK-IN',
                            style: TextStyle(color: Colors.orangeAccent),
                          ),
                        ),
                      ],
                    ],
                  ),
                );
              },
            ),
          );
        },
      ),
    );
  }
}

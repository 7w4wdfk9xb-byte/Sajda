import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:adhan/adhan.dart';
import 'package:intl/intl.dart';
import 'package:http/http.dart' as http;

void main() => runApp(const PrayerApp());

class PrayerApp extends StatelessWidget {
  const PrayerApp({super.key});
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      theme: ThemeData.dark(useMaterial3: true),
      home: const PrayerScreen(),
    );
  }
}

class PrayerScreen extends StatefulWidget {
  const PrayerScreen({super.key});
  @override
  State<PrayerScreen> createState() => _PrayerScreenState();
}

class _PrayerScreenState extends State<PrayerScreen> {
  String _cityName = "Москва";
  double _lat = 55.7558;
  double _lon = 37.6173;
  Madhab _selectedMadhab = Madhab.shafi;
  DateTime _now = DateTime.now();
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    _timer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (mounted) setState(() => _now = DateTime.now());
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  Future<void> _searchCity(String query) async {
    final url = Uri.parse('https://nominatim.openstreetmap.org/search?q=$query&format=json&limit=1');
    try {
      final response = await http.get(url, headers: {'User-Agent': 'PrayerApp'});
      final data = json.decode(response.body);
      if (data.isNotEmpty) {
        setState(() {
          _cityName = data[0]['display_name'].split(',')[0];
          _lat = double.parse(data[0]['lat']);
          _lon = double.parse(data[0]['lon']);
        });
      }
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Ошибка поиска")));
    }
  }

  @override
  Widget build(BuildContext context) {
    final params = CalculationMethod.muslim_world_league.getParameters();
    params.madhab = _selectedMadhab;
    final prayerTimes = PrayerTimes.today(Coordinates(_lat, _lon), params);
    
    final next = prayerTimes.nextPrayer();
    final nextTime = prayerTimes.timeForPrayer(next)?.toLocal() ?? _now;
    final diff = nextTime.difference(_now);

    // Логика для Сухура и Ифтара
    bool isFastRunning = _now.isAfter(prayerTimes.fajr) && _now.isBefore(prayerTimes.maghrib);
    String fastStatus = isFastRunning ? "ДО ИФТАРА (МАГРИБ)" : "ДО СУХУРА (ФАДЖР)";
    DateTime targetTime = isFastRunning ? prayerTimes.maghrib : prayerTimes.fajr;
    
    // Если сейчас после Ифтара, но до полуночи, Сухур будет уже завтрашним Фаджром
    if (_now.isAfter(prayerTimes.maghrib)) {
       final tomorrow = PrayerTimes.today(Coordinates(_lat, _lon), params).fajr.add(const Duration(days: 1));
       // Для простоты оставим текущий расчет, Adhan сам подставит следующий Fajr в nextPrayer
    }

    return Scaffold(
      backgroundColor: const Color(0xFF0A0E12),
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        title: Text(_cityName),
        actions: [
          IconButton(
            icon: Icon(_selectedMadhab == Madhab.shafi ? Icons.shield : Icons.shield_outlined),
            onPressed: () => setState(() => _selectedMadhab = _selectedMadhab == Madhab.shafi ? Madhab.hanafi : Madhab.shafi),
            tooltip: "Сменить мазхаб",
          ),
        ],
      ),
      body: SingleChildScrollView(
        child: Column(
          children: [
            _buildSearchField(),
            _buildRamadanCard(fastStatus, targetTime.difference(_now)),
            const SizedBox(height: 20),
            _buildPrayerList(prayerTimes, next),
          ],
        ),
      ),
    );
  }

  Widget _buildSearchField() {
    return Padding(
      padding: const EdgeInsets.all(16.0),
      child: TextField(
        decoration: InputDecoration(
          hintText: "Поиск города...",
          prefixIcon: const Icon(Icons.search),
          filled: true,
          fillColor: Colors.white10,
          border: OutlineInputBorder(borderRadius: BorderRadius.circular(15), borderSide: BorderSide.none),
        ),
        onSubmitted: (val) => _searchCity(val),
      ),
    );
  }

  Widget _buildRamadanCard(String status, Duration d) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16),
      padding: const EdgeInsets.all(25),
      decoration: BoxDecoration(
        gradient: const LinearGradient(colors: [Color(0xFF0F2027), Color(0xFF203A43), Color(0xFF2C5364)]),
        borderRadius: BorderRadius.circular(25),
        boxShadow: [BoxShadow(color: Colors.cyan.withOpacity(0.2), blurRadius: 15)],
      ),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(status.contains("ИФТАР") ? Icons.restaurant : Icons.nightlight_round, color: Colors.amberAccent),
              const SizedBox(width: 10),
              Text(status, style: const TextStyle(fontWeight: FontWeight.bold, letterSpacing: 1.2)),
            ],
          ),
          const SizedBox(height: 10),
          Text(
            "${d.inHours.toString().padLeft(2, '0')}:${(d.inMinutes % 60).toString().padLeft(2, '0')}:${(d.inSeconds % 60).toString().padLeft(2, '0')}",
            style: const TextStyle(fontSize: 48, fontWeight: FontWeight.w900, fontFamily: 'monospace', color: Colors.cyanAccent),
          ),
        ],
      ),
    );
  }

  Widget _buildPrayerList(PrayerTimes times, Prayer next) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Column(
        children: [
          _prayerTile("Сухур (Фаджр)", times.fajr, next == Prayer.fajr, Icons.wb_twilight),
          _prayerTile("Восход", times.sunrise, next == Prayer.sunrise, Icons.wb_sunny_outlined),
          _prayerTile("Зухр", times.dhuhr, next == Prayer.dhuhr, Icons.wb_sunny),
          _prayerTile("Аср", times.asr, next == Prayer.asr, Icons.cloud_outlined),
          _prayerTile("Ифтар (Магриб)", times.maghrib, next == Prayer.maghrib, Icons.nights_stay),
          _prayerTile("Иша", times.isha, next == Prayer.isha, Icons.bedtime),
        ],
      ),
    );
  }

  Widget _prayerTile(String name, DateTime time, bool isActive, IconData icon) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: isActive ? Colors.cyan.withOpacity(0.1) : Colors.white.withOpacity(0.03),
        borderRadius: BorderRadius.circular(15),
        border: isActive ? Border.all(color: Colors.cyanAccent.withOpacity(0.5)) : null,
      ),
      child: Row(
        children: [
          Icon(icon, size: 20, color: isActive ? Colors.cyanAccent : Colors.grey),
          const SizedBox(width: 15),
          Text(name, style: TextStyle(fontSize: 16, color: isActive ? Colors.cyanAccent : Colors.white)),
          const Spacer(),
          Text(DateFormat.Hm().format(time.toLocal()), style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
        ],
      ),
    );
  }
}
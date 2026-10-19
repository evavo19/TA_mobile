import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:geolocator/geolocator.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:latlong2/latlong.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class LbsScreen extends StatefulWidget {
  const LbsScreen({super.key});

  @override
  State<LbsScreen> createState() => _LbsScreenState();
}

class _LbsScreenState extends State<LbsScreen> {
  final MapController _mapController = MapController();

  // GPS Device Location
  LatLng _userLocation = const LatLng(-7.7926, 110.3658); // Default Malioboro
  String _currentLocationName = 'Mendapatkan lokasi GPS...';
  bool _isLoading = true;

  // Filter Radius Jarak
  String _selectedRadius = 'Semua';
  final List<String> _radiusOptions = ['< 5 km', '< 10 km', '< 20 km', 'Semua'];

  // Data Wisata dari Supabase Database
  List<Map<String, dynamic>> _allWisata = [];

  @override
  void initState() {
    super.initState();
    _fetchLocationAndWisata();
  }

  // Hitung Jarak Haversine (km)
  double _calculateDistance(double lat1, double lon1, double lat2, double lon2) {
    var p = 0.017453292519943295;
    var c = cos;
    var a = 0.5 -
        c((lat2 - lat1) * p) / 2 +
        c(lat1 * p) * c(lat2 * p) * (1 - c((lon2 - lon1) * p)) / 2;
    return 12742 * asin(sqrt(a));
  }

  Future<void> _fetchLocationAndWisata() async {
    setState(() => _isLoading = true);

    try {
      // 1. Ambil Koordinat Native GPS HP User
      bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (serviceEnabled) {
        LocationPermission permission = await Geolocator.checkPermission();
        if (permission == LocationPermission.denied) {
          permission = await Geolocator.requestPermission();
        }
        if (permission == LocationPermission.whileInUse ||
            permission == LocationPermission.always) {
          Position position = await Geolocator.getCurrentPosition(
            desiredAccuracy: LocationAccuracy.high,
          );
          _userLocation = LatLng(position.latitude, position.longitude);
          _currentLocationName = 'Lokasi GPS Presisi Anda';
        }
      }
    } catch (_) {
      _currentLocationName = 'Malioboro (Lokasi Default)';
    }

    try {
      // 2. Fetch Data dari Tabel 'wisata' Supabase
      final response = await Supabase.instance.client
          .from('wisata')
          .select();

      final List<dynamic> data = response;

      // 3. Olah & Hitung Jarak tiap Wisata dari GPS User
      List<Map<String, dynamic>> loadedWisata = data.map((item) {
        double itemLat = (item['latitude'] as num).toDouble();
        double itemLng = (item['longitude'] as num).toDouble();
        double distance = _calculateDistance(
          _userLocation.latitude,
          _userLocation.longitude,
          itemLat,
          itemLng,
        );

        return {
          'id': item['id'],
          'nama': item['nama'] ?? 'Wisata Jogja',
          'kategori': item['kategori'] ?? 'Umum',
          'rating': (item['rating'] as num?)?.toDouble() ?? 4.5,
          'harga': item['harga_weekday'] ?? 0,
          'jarak': double.parse(distance.toStringAsFixed(1)),
          'location': LatLng(itemLat, itemLng),
          'foto_url': item['foto_url'] ?? '',
          'deskripsi': item['deskripsi'] ?? '',
        };
      }).toList();

      // Urutkan dari yang terdekat
      loadedWisata.sort((a, b) => (a['jarak'] as double).compareTo(b['jarak'] as double));

      setState(() {
        _allWisata = loadedWisata;
        _isLoading = false;
      });

      _mapController.move(_userLocation, 12.0);
    } catch (e) {
      setState(() => _isLoading = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Gagal mengambil data dari Supabase: $e')),
        );
      }
    }
  }

  List<Map<String, dynamic>> get _filteredWisata {
    if (_selectedRadius == '< 5 km') {
      return _allWisata.where((w) => (w['jarak'] as double) <= 5.0).toList();
    } else if (_selectedRadius == '< 10 km') {
      return _allWisata.where((w) => (w['jarak'] as double) <= 10.0).toList();
    } else if (_selectedRadius == '< 20 km') {
      return _allWisata.where((w) => (w['jarak'] as double) <= 20.0).toList();
    }
    return _allWisata;
  }

  @override
  Widget build(BuildContext context) {
    const primaryColor = Color(0xFF1550B6);

    return Scaffold(
      backgroundColor: const Color(0xFFF6F8FB),
      appBar: AppBar(
        title: Text(
          'Wisata Terdekat (LBS)',
          style: GoogleFonts.poppins(
            fontWeight: FontWeight.bold,
            color: Colors.white,
            fontSize: 18,
          ),
        ),
        backgroundColor: primaryColor,
        elevation: 0,
        centerTitle: true,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new, color: Colors.white),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator(color: primaryColor))
          : Column(
              children: [
                // 1. TAMPILAN PETA OPENSTREETMAP (OSM)
                SizedBox(
                  height: 260,
                  width: double.infinity,
                  child: Stack(
                    children: [
                      FlutterMap(
                        mapController: _mapController,
                        options: MapOptions(
                          initialCenter: _userLocation,
                          initialZoom: 12.0,
                        ),
                        children: [
                          TileLayer(
                            urlTemplate:
                                'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                            userAgentPackageName: 'com.example.lelunganjogja',
                          ),
                          MarkerLayer(
                            markers: [
                              // Marker Posisi Pengguna (Biru)
                              Marker(
                                point: _userLocation,
                                width: 40,
                                height: 40,
                                child: const Icon(
                                  Icons.my_location,
                                  color: Colors.blueAccent,
                                  size: 36,
                                ),
                              ),

                              // Marker Lokasi Wisata Supabase (Merah)
                              ..._filteredWisata.map((w) {
                                return Marker(
                                  point: w['location'] as LatLng,
                                  width: 40,
                                  height: 40,
                                  child: IconButton(
                                    icon: const Icon(
                                      Icons.location_on,
                                      color: Colors.redAccent,
                                      size: 36,
                                    ),
                                    onPressed: () {
                                      ScaffoldMessenger.of(context).showSnackBar(
                                        SnackBar(
                                          content: Text(
                                            '${w['nama']} (${w['jarak']} km)',
                                            style: GoogleFonts.poppins(),
                                          ),
                                          backgroundColor: primaryColor,
                                        ),
                                      );
                                    },
                                  ),
                                );
                              }),
                            ],
                          ),
                        ],
                      ),
                      Positioned(
                        top: 12,
                        right: 12,
                        child: FloatingActionButton.small(
                          backgroundColor: Colors.white,
                          onPressed: _fetchLocationAndWisata,
                          child: const Icon(Icons.gps_fixed, color: primaryColor),
                        ),
                      ),
                    ],
                  ),
                ),

                // Info Bar Lokasi GPS
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
                  child: Row(
                    children: [
                      const Icon(Icons.location_on, color: primaryColor, size: 20),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          _currentLocationName,
                          style: GoogleFonts.poppins(
                            fontSize: 13,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),

                // 2. FILTER RADIUS JARAK
                Padding(
                  padding: const EdgeInsets.all(12.0),
                  child: Row(
                    children: [
                      Text(
                        'Radius:',
                        style: GoogleFonts.poppins(
                          fontSize: 13,
                          fontWeight: FontWeight.bold,
                          color: Colors.grey.shade700,
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: SingleChildScrollView(
                          scrollDirection: Axis.horizontal,
                          child: Row(
                            children: _radiusOptions.map((radius) {
                              bool isSelected = _selectedRadius == radius;
                              return Padding(
                                padding: const EdgeInsets.only(right: 8.0),
                                child: ChoiceChip(
                                  label: Text(
                                    radius,
                                    style: GoogleFonts.poppins(
                                      fontSize: 12,
                                      color: isSelected
                                          ? Colors.white
                                          : primaryColor,
                                    ),
                                  ),
                                  selected: isSelected,
                                  selectedColor: primaryColor,
                                  backgroundColor: Colors.white,
                                  onSelected: (selected) {
                                    if (selected) {
                                      setState(() {
                                        _selectedRadius = radius;
                                      });
                                    }
                                  },
                                ),
                              );
                            }).toList(),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),

                // 3. LIST CARD WISATA TERDEKAT DARI SUPABASE
                Expanded(
                  child: _filteredWisata.isEmpty
                      ? Center(
                          child: Text(
                            'Tidak ada destinasi dalam radius ini.',
                            style: GoogleFonts.poppins(color: Colors.grey),
                          ),
                        )
                      : ListView.builder(
                          padding: const EdgeInsets.symmetric(horizontal: 16),
                          itemCount: _filteredWisata.length,
                          itemBuilder: (context, index) {
                            final item = _filteredWisata[index];
                            return Card(
                              margin: const EdgeInsets.only(bottom: 12),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(16),
                              ),
                              child: ListTile(
                                contentPadding: const EdgeInsets.all(8),
                                leading: ClipRRect(
                                  borderRadius: BorderRadius.circular(12),
                                  child: Image.network(
                                    item['foto_url'],
                                    width: 70,
                                    height: 70,
                                    fit: BoxFit.cover,
                                    errorBuilder:
                                        (context, error, stackTrace) =>
                                            Container(
                                      width: 70,
                                      height: 70,
                                      color: Colors.grey.shade300,
                                      child: const Icon(Icons.landscape),
                                    ),
                                  ),
                                ),
                                title: Text(
                                  item['nama'],
                                  style: GoogleFonts.poppins(
                                    fontWeight: FontWeight.bold,
                                    fontSize: 14,
                                  ),
                                ),
                                subtitle: Text(
                                  'Jarak: ${item['jarak']} km • Rp ${item['harga']}',
                                  style: GoogleFonts.poppins(
                                    fontSize: 12,
                                    color: Colors.grey.shade600,
                                  ),
                                ),
                                trailing: IconButton(
                                  icon: const Icon(
                                    Icons.navigation_outlined,
                                    color: primaryColor,
                                  ),
                                  onPressed: () {
                                    _mapController.move(
                                        item['location'] as LatLng, 14.0);
                                  },
                                ),
                              ),
                            );
                          },
                        ),
                ),
              ],
            ),
    );
  }
}
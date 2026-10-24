import 'dart:math';

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:flutter_map_cancellable_tile_provider/flutter_map_cancellable_tile_provider.dart';
import 'package:geolocator/geolocator.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:latlong2/latlong.dart';
import 'package:url_launcher/url_launcher.dart';

// SESUAIKAN path ini dengan lokasi wisata_service.dart di projectmu.
// Kalau file ini ada di lib/services/ (satu folder), cukup seperti di bawah.
import 'wisata_service.dart';

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

  // Destinasi terpilih untuk garis rute (Polyline)
  LatLng? _selectedDestination;
  String? _selectedDestinationName;

  // Filter radius jarak
  String _selectedRadius = 'Semua';
  final List<String> _radiusOptions = ['< 5 km', '< 10 km', '< 20 km', 'Semua'];

  // Data wisata (Supabase kalau online, SQLite kalau offline)
  List<Map<String, dynamic>> _allWisata = [];

  @override
  void initState() {
    super.initState();
    _fetchLocationAndWisata();
  }

  // Hitung jarak Haversine (km)
  double _calculateDistance(
    double lat1,
    double lon1,
    double lat2,
    double lon2,
  ) {
    const p = 0.017453292519943295;
    final c = cos;
    final a = 0.5 -
        c((lat2 - lat1) * p) / 2 +
        c(lat1 * p) * c(lat2 * p) * (1 - c((lon2 - lon1) * p)) / 2;
    return 12742 * asin(sqrt(a));
  }

  // Buka Google Maps aplikasi eksternal
  Future<void> _openGoogleMaps(double lat, double lng) async {
    final Uri googleMapsUrl = Uri.parse(
      'https://www.google.com/maps/search/?api=1&query=$lat,$lng',
    );
    if (await canLaunchUrl(googleMapsUrl)) {
      await launchUrl(googleMapsUrl, mode: LaunchMode.externalApplication);
    } else {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Tidak dapat membuka aplikasi Google Maps'),
          ),
        );
      }
    }
  }

  Future<void> _fetchLocationAndWisata() async {
    setState(() => _isLoading = true);

    // 1. Ambil koordinat GPS HP
    try {
      final serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (serviceEnabled) {
        LocationPermission permission = await Geolocator.checkPermission();
        if (permission == LocationPermission.denied) {
          permission = await Geolocator.requestPermission();
        }
        if (permission == LocationPermission.whileInUse ||
            permission == LocationPermission.always) {
          final position = await Geolocator.getCurrentPosition(
            // DIUBAH: desiredAccuracy sudah deprecated
            locationSettings: const LocationSettings(
              accuracy: LocationAccuracy.high,
            ),
          );
          _userLocation = LatLng(position.latitude, position.longitude);
          _currentLocationName = 'Lokasi GPS Presisi Anda';
        } else {
          _currentLocationName = 'Malioboro (Lokasi Default)';
        }
      } else {
        _currentLocationName = 'Malioboro (Lokasi Default)';
      }
    } catch (_) {
      _currentLocationName = 'Malioboro (Lokasi Default)';
    }

    // 2. Ambil data wisata
    List<dynamic> data;
    try {
      // DIUBAH: lewat WisataService -> Supabase kalau online, SQLite kalau offline
      data = await WisataService().getWisataList();
    } catch (e) {
      if (!mounted) return;
      setState(() => _isLoading = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Gagal memuat data wisata: $e')),
      );
      return;
    }

    // 3. Olah & hitung jarak tiap wisata dari posisi user
    final List<Map<String, dynamic>> loadedWisata = [];
    for (final item in data) {
      final lat = (item['latitude'] as num?)?.toDouble();
      final lng = (item['longitude'] as num?)?.toDouble();
      if (lat == null || lng == null) continue; // lewati data tanpa koordinat

      final distance = _calculateDistance(
        _userLocation.latitude,
        _userLocation.longitude,
        lat,
        lng,
      );

      loadedWisata.add({
        'id': item['id'],
        'nama': item['nama'] ?? 'Wisata Jogja',
        'kategori': item['kategori'] ?? 'Umum',
        'rating': (item['rating'] as num?)?.toDouble() ?? 4.5,
        'harga': item['harga_weekday'] ?? 0,
        'jarak': double.parse(distance.toStringAsFixed(1)),
        'location': LatLng(lat, lng),
        'foto_url': item['foto_url'] ?? '',
        'deskripsi': item['deskripsi'] ?? '',
      });
    }

    // Urutkan dari yang terdekat
    loadedWisata.sort(
      (a, b) => (a['jarak'] as double).compareTo(b['jarak'] as double),
    );

    if (!mounted) return;
    setState(() {
      _allWisata = loadedWisata;
      _isLoading = false;
    });

    // DIUBAH: tunggu peta selesai dibangun dulu, baru geser kamera.
    // (Sebelumnya move() dipanggil sebelum FlutterMap ada -> LateInitializationError)
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        _mapController.move(_userLocation, 12.0);
      }
    });
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

  void _selectDestination(LatLng targetLocation, String name) {
    setState(() {
      _selectedDestination = targetLocation;
      _selectedDestinationName = name;
    });

    // Geser kamera peta ke lokasi tujuan
    _mapController.move(targetLocation, 14.0);

    ScaffoldMessenger.of(context).hideCurrentSnackBar();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          'Rute menuju $name ditampilkan di peta.',
          style: GoogleFonts.poppins(),
        ),
        backgroundColor: const Color(0xFF1550B6),
        action: SnackBarAction(
          label: 'BUKA MAPS',
          textColor: Colors.amber,
          onPressed: () {
            _openGoogleMaps(targetLocation.latitude, targetLocation.longitude);
          },
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    const primaryColor = Color(0xFF1550B6);
    final wisataTampil = _filteredWisata;

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
                // 1. PETA OPENSTREETMAP
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
                            tileProvider: CancellableNetworkTileProvider(),
                          ),

                          // Garis rute jika ada lokasi terpilih
                          if (_selectedDestination != null)
                            PolylineLayer(
                              polylines: [
                                Polyline(
                                  points: [
                                    _userLocation,
                                    _selectedDestination!,
                                  ],
                                  strokeWidth: 4.0,
                                  color: Colors.blueAccent,
                                ),
                              ],
                            ),

                          MarkerLayer(
                            markers: [
                              // Posisi pengguna (biru)
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

                              // Lokasi wisata (merah)
                              ...wisataTampil.map((w) {
                                return Marker(
                                  point: w['location'] as LatLng,
                                  width: 40,
                                  height: 40,
                                  child: IconButton(
                                    padding: EdgeInsets.zero,
                                    icon: const Icon(
                                      Icons.location_on,
                                      color: Colors.redAccent,
                                      size: 36,
                                    ),
                                    onPressed: () {
                                      _selectDestination(
                                        w['location'] as LatLng,
                                        w['nama'],
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
                          child: const Icon(
                            Icons.gps_fixed,
                            color: primaryColor,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),

                // Info bar lokasi GPS
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
                  child: Row(
                    children: [
                      const Icon(
                        Icons.location_on,
                        color: primaryColor,
                        size: 20,
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          _selectedDestinationName != null
                              ? 'Rute ke: $_selectedDestinationName'
                              : _currentLocationName,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: GoogleFonts.poppins(
                            fontSize: 13,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ),
                      if (_selectedDestination != null)
                        TextButton(
                          onPressed: () {
                            setState(() {
                              _selectedDestination = null;
                              _selectedDestinationName = null;
                            });
                          },
                          child: Text(
                            'Hapus Rute',
                            style: GoogleFonts.poppins(
                              fontSize: 12,
                              color: Colors.red,
                            ),
                          ),
                        ),
                    ],
                  ),
                ),

                // 2. FILTER RADIUS
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
                              final isSelected = _selectedRadius == radius;
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
                                      setState(() => _selectedRadius = radius);
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

                // 3. DAFTAR WISATA TERDEKAT
                Expanded(
                  child: wisataTampil.isEmpty
                      ? Center(
                          child: Text(
                            'Tidak ada destinasi dalam radius ini.',
                            style: GoogleFonts.poppins(color: Colors.grey),
                          ),
                        )
                      : ListView.builder(
                          padding: const EdgeInsets.symmetric(horizontal: 16),
                          itemCount: wisataTampil.length,
                          itemBuilder: (context, index) {
                            final item = wisataTampil[index];
                            final targetLoc = item['location'] as LatLng;

                            return Card(
                              margin: const EdgeInsets.only(bottom: 12),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(16),
                              ),
                              child: ListTile(
                                contentPadding: const EdgeInsets.all(8),
                                leading: ClipRRect(
                                  borderRadius: BorderRadius.circular(12),
                                  // DIUBAH: CachedNetworkImage, tetap tampil saat offline
                                  child: CachedNetworkImage(
                                    imageUrl: item['foto_url'],
                                    width: 70,
                                    height: 70,
                                    fit: BoxFit.cover,
                                    memCacheWidth: 200,
                                    placeholder: (context, url) => Container(
                                      width: 70,
                                      height: 70,
                                      color: Colors.grey.shade200,
                                    ),
                                    errorWidget: (context, url, error) =>
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
                                onTap: () {
                                  _selectDestination(targetLoc, item['nama']);
                                },
                                trailing: IconButton(
                                  icon: const Icon(
                                    Icons.navigation_outlined,
                                    color: primaryColor,
                                  ),
                                  onPressed: () {
                                    _openGoogleMaps(
                                      targetLoc.latitude,
                                      targetLoc.longitude,
                                    );
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
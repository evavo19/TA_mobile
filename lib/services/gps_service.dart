import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:latlong2/latlong.dart';

class LbsScreen extends StatefulWidget {
  const LbsScreen({super.key});

  @override
  State<LbsScreen> createState() => _LbsScreenState();
}

class _LbsScreenState extends State<LbsScreen> {
  final MapController _mapController = MapController();

  // 1. Native Device GPS Position (Simulasi Lokasi Pengguna)
  String _currentLocationName = 'Jl. Malioboro, Yogyakarta';
  LatLng _userLocation = const LatLng(-7.7926, 110.3658);

  // Filter Radius
  String _selectedRadius = 'Semua';
  final List<String> _radiusOptions = ['< 5 km', '< 10 km', '< 20 km', 'Semua'];

  // 2. Data Wisata (Mewakili Data dari Supabase REST API / Dataset CSV)
  final List<Map<String, dynamic>> _allWisata = [
    {
      'id': 1,
      'nama': 'Taman Tempuran Cikal',
      'kategori': 'Alam',
      'rating': 4.4,
      'harga': 5000,
      'jarak': 6.5,
      'location': const LatLng(-7.840562, 110.449455),
      'foto_url': 'https://res.cloudinary.com/dfciqrwpe/image/upload/v1749301634/Taman_Tempuran_Cikal_y9ongb.jpg',
      'deskripsi': 'Taman alam di Piyungan dengan wahana kano, speed boat, & area outbound.',
    },
    {
      'id': 2,
      'nama': 'Selopamioro Adventure Park',
      'kategori': 'Alam',
      'rating': 4.5,
      'harga': 30000,
      'jarak': 18.2,
      'location': const LatLng(-7.945377, 110.426671),
      'foto_url': 'https://res.cloudinary.com/dfciqrwpe/image/upload/v1749368364/selopamioro-adventure_qhctxz.jpg',
      'deskripsi': 'Aktivitas outbound & permainan air di tepi sungai Imogiri yang sejuk.',
    },
    {
      'id': 3,
      'nama': 'Tebing Gunung Gajah',
      'kategori': 'Alam',
      'rating': 4.5,
      'harga': 5000,
      'jarak': 25.0,
      'location': const LatLng(-7.776247, 110.106137),
      'foto_url': 'https://res.cloudinary.com/dfciqrwpe/image/upload/v1748937502/Tebing-Gunung-Gajah_wuodco.jpg',
      'deskripsi':
          'Pemandangan perbukitan Menoreh & Waduk Sermo dari ketinggian.',
    },
  ];

  List<Map<String, dynamic>> get _filteredWisata {
    if (_selectedRadius == '< 5 km') {
      return _allWisata.where((w) => w['jarak'] <= 5.0).toList();
    } else if (_selectedRadius == '< 10 km') {
      return _allWisata.where((w) => w['jarak'] <= 10.0).toList();
    } else if (_selectedRadius == '< 20 km') {
      return _allWisata.where((w) => w['jarak'] <= 20.0).toList();
    }
    return _allWisata;
  }

  void _changeLocation(String name, LatLng location) {
    setState(() {
      _currentLocationName = name;
      _userLocation = location;
    });
    _mapController.move(location, 13.0);
    Navigator.pop(context);
  }

  void _showChangeLocationDialog() {
    showDialog(
      context: context,
      builder: (context) {
        return SimpleDialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          title: Text(
            'Simulasi Lokasi GPS Device',
            style: GoogleFonts.poppins(
              fontWeight: FontWeight.bold,
              fontSize: 16,
            ),
          ),
          children: [
            _buildLocationOption(
              'Jl. Malioboro, Yogyakarta',
              const LatLng(-7.7926, 110.3658),
            ),
            _buildLocationOption(
              'Tugu Jogja, Sleman',
              const LatLng(-7.7829, 110.3671),
            ),
            _buildLocationOption(
              'Imogiri, Bantul',
              const LatLng(-7.9181, 110.3925),
            ),
          ],
        );
      },
    );
  }

  Widget _buildLocationOption(String name, LatLng location) {
    return SimpleDialogOption(
      onPressed: () => _changeLocation(name, location),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 8.0),
        child: Row(
          children: [
            const Icon(Icons.location_on, color: Color(0xFF1550B6), size: 20),
            const SizedBox(width: 10),
            Expanded(
              child: Text(name, style: GoogleFonts.poppins(fontSize: 14)),
            ),
          ],
        ),
      ),
    );
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
      body: Column(
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
                    // Layer Peta OpenStreetMap (OSM) Tile API
                    TileLayer(
                      urlTemplate:
                          'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                      userAgentPackageName: 'com.example.lelunganjogja',
                    ),

                    // Layer Marker Lokasi (User GPS & Marker Wisata)
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

                        // Marker Lokasi Wisata (Merah)
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

                // Button Simulasi GPS di Atas Peta
                Positioned(
                  top: 12,
                  right: 12,
                  child: FloatingActionButton.small(
                    backgroundColor: Colors.white,
                    onPressed: _showChangeLocationDialog,
                    child: const Icon(Icons.gps_fixed, color: primaryColor),
                  ),
                ),
              ],
            ),
          ),

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
                                color: isSelected ? Colors.white : primaryColor,
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

          // 3. LIST CARD WISATA TERDEKAT
          Expanded(
            child: ListView.builder(
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
                        errorBuilder: (context, error, stackTrace) => Container(
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
                        // Geser peta tepat ke lokasi wisata tersebut
                        _mapController.move(item['location'] as LatLng, 14.0);
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

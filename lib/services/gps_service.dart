import 'dart:math';

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:flutter_map_cancellable_tile_provider/flutter_map_cancellable_tile_provider.dart';
import 'package:geolocator/geolocator.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:latlong2/latlong.dart';
import 'package:url_launcher/url_launcher.dart';
import 'wisata_service.dart';

class LbsScreen extends StatefulWidget {
  const LbsScreen({super.key});

  @override
  State<LbsScreen> createState() => _LbsScreenState();
}

class _LbsScreenState extends State<LbsScreen> {
  final MapController _mapController = MapController();

  static const LatLng _defaultLocation = LatLng(-7.7790, 110.4140);
  static const String _defaultLocationName =
      'UPN Kampus 2 Babarsari (Lokasi Default)';

  LatLng _userLocation = _defaultLocation;
  String _currentLocationName = 'Mendapatkan lokasi GPS...';
  bool _isLoading = true;

  LatLng? _selectedDestination;
  String? _selectedDestinationName;

  String _selectedRadius = 'Semua';
  final List<String> _radiusOptions = ['< 5 km', '< 10 km', '< 20 km', 'Semua'];

  List<Map<String, dynamic>> _allWisata = [];

  @override
  void initState() {
    super.initState();
    _fetchLocationAndWisata();
  }

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

  String _toUtm(double lat, double lon) {
    const a = 6378137.0;
    const f = 1 / 298.257223563;
    const k0 = 0.9996;
    const e2 = f * (2 - f);
    const ep2 = e2 / (1 - e2);

    final zone = ((lon + 180) / 6).floor() + 1;
    final lon0 = ((zone - 1) * 6 - 180 + 3) * pi / 180;
    final phi = lat * pi / 180;
    final lam = lon * pi / 180;

    final sinP = sin(phi);
    final cosP = cos(phi);
    final tanP = tan(phi);

    final n = a / sqrt(1 - e2 * sinP * sinP);
    final t = tanP * tanP;
    final c = ep2 * cosP * cosP;
    final aa = cosP * (lam - lon0);

    final m = a *
        ((1 - e2 / 4 - 3 * e2 * e2 / 64 - 5 * e2 * e2 * e2 / 256) * phi -
            (3 * e2 / 8 + 3 * e2 * e2 / 32 + 45 * e2 * e2 * e2 / 1024) *
                sin(2 * phi) +
            (15 * e2 * e2 / 256 + 45 * e2 * e2 * e2 / 1024) * sin(4 * phi) -
            (35 * e2 * e2 * e2 / 3072) * sin(6 * phi));

    final easting = k0 *
            n *
            (aa +
                (1 - t + c) * pow(aa, 3) / 6 +
                (5 - 18 * t + t * t + 72 * c - 58 * ep2) * pow(aa, 5) / 120) +
        500000.0;

    var northing = k0 *
        (m +
            n *
                tanP *
                (aa * aa / 2 +
                    (5 - t + 9 * c + 4 * c * c) * pow(aa, 4) / 24 +
                    (61 - 58 * t + t * t + 600 * c - 330 * ep2) *
                        pow(aa, 6) /
                        720));
    if (lat < 0) northing += 10000000.0;

    const letters = 'CDEFGHJKLMNPQRSTUVWX';
    final band = letters[((lat + 80) / 8).floor().clamp(0, 19)];

    return '$zone$band ${easting.toStringAsFixed(0)} mE '
        '${northing.toStringAsFixed(0)} mN';
  }

  String _thumb(String url) {
    if (url.contains('res.cloudinary.com') && url.contains('/upload/')) {
      return url.replaceFirst(
        '/upload/',
        '/upload/w_200,h_200,c_fill,f_jpg,q_auto/',
      );
    }
    return url;
  }

  Widget _coordRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(top: 6),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 78,
            child: Text(
              label,
              style: GoogleFonts.poppins(
                fontSize: 11,
                fontWeight: FontWeight.w600,
                color: Colors.grey.shade600,
              ),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: GoogleFonts.poppins(
                fontSize: 12,
                fontWeight: FontWeight.w500,
                color: Colors.black87,
              ),
            ),
          ),
        ],
      ),
    );
  }

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
            
            locationSettings: const LocationSettings(
              accuracy: LocationAccuracy.high,
            ),
          );
          _userLocation = LatLng(position.latitude, position.longitude);
          _currentLocationName = 'Lokasi GPS Presisi Anda';
        } else {
          _userLocation = _defaultLocation;
          _currentLocationName = _defaultLocationName;
        }
      } else {
        _userLocation = _defaultLocation;
        _currentLocationName = _defaultLocationName;
      }
    } catch (_) {
      _userLocation = _defaultLocation;
      _currentLocationName = _defaultLocationName;
    }

    List<dynamic> data;
    try {
     
      data = await WisataService().getWisataList();
    } catch (e) {
      if (!mounted) return;
      setState(() => _isLoading = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Gagal memuat data wisata: $e')),
      );
      return;
    }

    final List<Map<String, dynamic>> loadedWisata = [];
    for (final item in data) {
      final lat = (item['latitude'] as num?)?.toDouble();
      final lng = (item['longitude'] as num?)?.toDouble();
      if (lat == null || lng == null) continue; 

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

    loadedWisata.sort(
      (a, b) => (a['jarak'] as double).compareTo(b['jarak'] as double),
    );

    if (!mounted) return;
    setState(() {
      _allWisata = loadedWisata;
      _isLoading = false;
    });

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

    final infoPoint = _selectedDestination ?? _userLocation;

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

                // Info bar lokasi GPS + koordinat (Lat/Long dan UTM)
                Container(
                  width: double.infinity,
                  margin: const EdgeInsets.fromLTRB(16, 12, 16, 0),
                  padding: const EdgeInsets.fromLTRB(12, 10, 12, 12),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(color: Colors.grey.shade200),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
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
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                          if (_selectedDestination != null)
                            TextButton(
                              style: TextButton.styleFrom(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 6,
                                ),
                                minimumSize: Size.zero,
                                tapTargetSize:
                                    MaterialTapTargetSize.shrinkWrap,
                              ),
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
                      const SizedBox(height: 8),
                      Divider(height: 1, color: Colors.grey.shade200),
                      _coordRow(
                        'Lat/Long',
                        '${infoPoint.latitude.toStringAsFixed(5)}, '
                            '${infoPoint.longitude.toStringAsFixed(5)}',
                      ),
                      _coordRow(
                        'UTM',
                        _toUtm(infoPoint.latitude, infoPoint.longitude),
                      ),
                    ],
                  ),
                ),

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
                                  child: (item['foto_url'] as String)
                                          .trim()
                                          .isEmpty
                                      ? Container(
                                          width: 70,
                                          height: 70,
                                          color: Colors.grey.shade300,
                                          child: const Icon(Icons.landscape),
                                        )
                                      : CachedNetworkImage(
                                          imageUrl: _thumb(item['foto_url']),
                                          width: 70,
                                          height: 70,
                                          fit: BoxFit.cover,
                                          memCacheWidth: 200,
                                          placeholder: (context, url) =>
                                              Container(
                                            width: 70,
                                            height: 70,
                                            color: Colors.grey.shade200,
                                          ),
                                          errorWidget: (context, url, error) {
                                            debugPrint(
                                              'Gagal load gambar: "$url" -> $error',
                                            );
                                            return Container(
                                              width: 70,
                                              height: 70,
                                              color: Colors.grey.shade300,
                                              child: const Icon(
                                                Icons.landscape,
                                              ),
                                            );
                                          },
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
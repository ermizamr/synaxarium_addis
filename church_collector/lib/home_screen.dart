import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'login_screen.dart';
import 'supabase_service.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  static const String _draftNameKey = 'draft_church_name';
  static const String _draftLatitudeKey = 'draft_church_latitude';
  static const String _draftLongitudeKey = 'draft_church_longitude';
  static const String _pendingSubmissionKey = 'pending_church_submission';

  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _latitudeController = TextEditingController();
  final _longitudeController = TextEditingController();

  bool _isFetchingLocation = false;
  bool _isSubmitting = false;
  bool _isRetryingPending = false;
  bool _hasPendingSubmission = false;

  bool _isValidLatitude(double value) => value >= -90 && value <= 90;

  bool _isValidLongitude(double value) => value >= -180 && value <= 180;

  bool _isPlaceholderCoordinate(double latitude, double longitude) =>
      latitude == 0 && longitude == 0;

  bool _looksLikeTransientFailure(String message) {
    final lower = message.toLowerCase();
    return lower.contains('timeout') ||
        lower.contains('network') ||
        lower.contains('socket') ||
        lower.contains('connection') ||
        lower.contains('failed host lookup');
  }

  @override
  void initState() {
    super.initState();
    _nameController.addListener(_persistDraft);
    _latitudeController.addListener(_persistDraft);
    _longitudeController.addListener(_persistDraft);
    _loadCachedState();
  }

  @override
  void dispose() {
    _nameController.removeListener(_persistDraft);
    _latitudeController.removeListener(_persistDraft);
    _longitudeController.removeListener(_persistDraft);
    _nameController.dispose();
    _latitudeController.dispose();
    _longitudeController.dispose();
    super.dispose();
  }

  Future<void> _loadCachedState() async {
    final prefs = await SharedPreferences.getInstance();

    final draftName = prefs.getString(_draftNameKey) ?? '';
    final draftLatitude = prefs.getString(_draftLatitudeKey) ?? '';
    final draftLongitude = prefs.getString(_draftLongitudeKey) ?? '';
    final pendingJson = prefs.getString(_pendingSubmissionKey);

    if (!mounted) return;
    setState(() {
      if (_nameController.text.isEmpty) {
        _nameController.text = draftName;
      }
      if (_latitudeController.text.isEmpty) {
        _latitudeController.text = draftLatitude;
      }
      if (_longitudeController.text.isEmpty) {
        _longitudeController.text = draftLongitude;
      }
      _hasPendingSubmission = pendingJson != null && pendingJson.isNotEmpty;
    });
  }

  Future<void> _persistDraft() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_draftNameKey, _nameController.text);
    await prefs.setString(_draftLatitudeKey, _latitudeController.text);
    await prefs.setString(_draftLongitudeKey, _longitudeController.text);
  }

  Future<void> _clearDraft() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_draftNameKey);
    await prefs.remove(_draftLatitudeKey);
    await prefs.remove(_draftLongitudeKey);
  }

  Future<void> _cachePendingSubmission({
    required String name,
    required double latitude,
    required double longitude,
  }) async {
    final payload = jsonEncode({
      'name': name,
      'latitude': latitude,
      'longitude': longitude,
      'cached_at': DateTime.now().toIso8601String(),
    });
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_pendingSubmissionKey, payload);
    if (!mounted) return;
    setState(() {
      _hasPendingSubmission = true;
    });
  }

  Future<void> _clearPendingSubmission() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_pendingSubmissionKey);
    if (!mounted) return;
    setState(() {
      _hasPendingSubmission = false;
    });
  }

  Future<void> _retryPendingSubmission() async {
    if (_isSubmitting || _isFetchingLocation || _isRetryingPending) return;

    final prefs = await SharedPreferences.getInstance();
    final pendingRaw = prefs.getString(_pendingSubmissionKey);
    if (pendingRaw == null || pendingRaw.isEmpty) {
      if (!mounted) return;
      setState(() {
        _hasPendingSubmission = false;
      });
      return;
    }

    Map<String, dynamic> pendingData;
    try {
      pendingData = jsonDecode(pendingRaw) as Map<String, dynamic>;
    } catch (_) {
      await _clearPendingSubmission();
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Cached data was invalid and was cleared.'),
        ),
      );
      return;
    }

    final name = (pendingData['name'] ?? '').toString().trim();
    final latitude = (pendingData['latitude'] as num?)?.toDouble();
    final longitude = (pendingData['longitude'] as num?)?.toDouble();

    if (name.isEmpty || latitude == null || longitude == null) {
      await _clearPendingSubmission();
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Cached data was incomplete and was cleared.'),
        ),
      );
      return;
    }

    setState(() {
      _isRetryingPending = true;
    });

    try {
      final message = await SupabaseService.instance.upsertChurchByCoordinates(
        name: name,
        latitude: latitude,
        longitude: longitude,
      );

      await _clearPendingSubmission();
      await _clearDraft();

      _nameController.clear();
      _latitudeController.clear();
      _longitudeController.clear();

      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Cached data sent. $message')));
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Retry failed: $error')));
    } finally {
      if (mounted) {
        setState(() {
          _isRetryingPending = false;
        });
      }
    }
  }

  Future<void> _signOut() async {
    await Supabase.instance.client.auth.signOut();
    if (!mounted) return;
    Navigator.of(context).pushAndRemoveUntil(
      MaterialPageRoute(builder: (_) => const LoginScreen()),
      (route) => false,
    );
  }

  Future<void> _getCurrentLocation() async {
    if (_isFetchingLocation || _isSubmitting) return;

    setState(() {
      _isFetchingLocation = true;
    });

    try {
      final serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) {
        throw Exception(
          'Location services are disabled. Please enable GPS and try again.',
        );
      }

      var permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
      }

      if (permission == LocationPermission.denied) {
        throw Exception('Location permission denied.');
      }

      if (permission == LocationPermission.deniedForever) {
        throw Exception(
          'Location permission denied forever. Enable it from app settings.',
        );
      }

      final position = await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.best,
          timeLimit: Duration(seconds: 20),
        ),
      );

      _latitudeController.text = position.latitude.toStringAsFixed(8);
      _longitudeController.text = position.longitude.toStringAsFixed(8);
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Failed to get location: $error')));
    } finally {
      if (mounted) {
        setState(() {
          _isFetchingLocation = false;
        });
      }
    }
  }

  Future<void> _submitChurch() async {
    if (_isSubmitting || _isFetchingLocation) return;
    if (!_formKey.currentState!.validate()) return;

    final latitude = double.tryParse(_latitudeController.text.trim());
    final longitude = double.tryParse(_longitudeController.text.trim());

    if (latitude == null || longitude == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Latitude and longitude must be valid numbers.'),
        ),
      );
      return;
    }

    if (!_isValidLatitude(latitude) || !_isValidLongitude(longitude)) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Use real coordinates: latitude must be between -90 and 90, longitude between -180 and 180.',
          ),
        ),
      );
      return;
    }

    if (_isPlaceholderCoordinate(latitude, longitude)) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            '0,0 is not a valid church location. Please use a real coordinate.',
          ),
        ),
      );
      return;
    }

    setState(() {
      _isSubmitting = true;
    });

    try {
      final message = await SupabaseService.instance.upsertChurchByCoordinates(
        name: _nameController.text.trim(),
        latitude: latitude,
        longitude: longitude,
      );

      _nameController.clear();
      _latitudeController.clear();
      _longitudeController.clear();
      await _clearDraft();
      await _clearPendingSubmission();

      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(message)));
    } catch (error) {
      final errorMessage = error.toString();
      if (_looksLikeTransientFailure(errorMessage)) {
        await _cachePendingSubmission(
          name: _nameController.text.trim(),
          latitude: latitude,
          longitude: longitude,
        );
      }

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            _looksLikeTransientFailure(errorMessage)
                ? 'Network unstable. Data cached locally. Use Retry Cached Submit when online.'
                : 'Submit failed: $error',
          ),
        ),
      );
    } finally {
      if (mounted) {
        setState(() {
          _isSubmitting = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Church Collector'),
        actions: [
          TextButton(
            onPressed: (_isSubmitting || _isFetchingLocation) ? null : _signOut,
            child: const Text('Logout'),
          ),
        ],
      ),
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 520),
              child: Card(
                elevation: 2,
                child: Padding(
                  padding: const EdgeInsets.all(20),
                  child: Form(
                    key: _formKey,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Text(
                          'Church Submission',
                          style: Theme.of(context).textTheme.headlineSmall,
                        ),
                        const SizedBox(height: 16),
                        TextFormField(
                          controller: _nameController,
                          textInputAction: TextInputAction.next,
                          decoration: const InputDecoration(
                            labelText: 'Church Name',
                            border: OutlineInputBorder(),
                          ),
                          validator: (value) {
                            if ((value ?? '').trim().isEmpty) {
                              return 'Church name is required';
                            }
                            return null;
                          },
                        ),
                        const SizedBox(height: 12),
                        SizedBox(
                          height: 46,
                          child: OutlinedButton.icon(
                            onPressed: (_isFetchingLocation || _isSubmitting)
                                ? null
                                : _getCurrentLocation,
                            icon: _isFetchingLocation
                                ? const SizedBox(
                                    width: 16,
                                    height: 16,
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2,
                                    ),
                                  )
                                : const Icon(Icons.my_location),
                            label: Text(
                              _isFetchingLocation
                                  ? 'Fetching location...'
                                  : 'Get Current Location',
                            ),
                          ),
                        ),
                        const SizedBox(height: 12),
                        if (_hasPendingSubmission) ...[
                          SizedBox(
                            height: 46,
                            child: OutlinedButton.icon(
                              onPressed:
                                  (_isRetryingPending ||
                                      _isSubmitting ||
                                      _isFetchingLocation)
                                  ? null
                                  : _retryPendingSubmission,
                              icon: _isRetryingPending
                                  ? const SizedBox(
                                      width: 16,
                                      height: 16,
                                      child: CircularProgressIndicator(
                                        strokeWidth: 2,
                                      ),
                                    )
                                  : const Icon(Icons.cloud_upload),
                              label: Text(
                                _isRetryingPending
                                    ? 'Retrying cached submit...'
                                    : 'Retry Cached Submit',
                              ),
                            ),
                          ),
                          const SizedBox(height: 12),
                        ],
                        TextFormField(
                          controller: _latitudeController,
                          keyboardType: const TextInputType.numberWithOptions(
                            decimal: true,
                            signed: true,
                          ),
                          decoration: const InputDecoration(
                            labelText: 'Latitude',
                            border: OutlineInputBorder(),
                          ),
                          validator: (value) {
                            if ((value ?? '').trim().isEmpty) {
                              return 'Latitude is required';
                            }
                            final parsed = double.tryParse(
                              (value ?? '').trim(),
                            );
                            if (parsed == null) {
                              return 'Enter a valid latitude';
                            }
                            if (!_isValidLatitude(parsed)) {
                              return 'Latitude must be between -90 and 90';
                            }
                            return null;
                          },
                        ),
                        const SizedBox(height: 12),
                        TextFormField(
                          controller: _longitudeController,
                          keyboardType: const TextInputType.numberWithOptions(
                            decimal: true,
                            signed: true,
                          ),
                          decoration: const InputDecoration(
                            labelText: 'Longitude',
                            border: OutlineInputBorder(),
                          ),
                          validator: (value) {
                            if ((value ?? '').trim().isEmpty) {
                              return 'Longitude is required';
                            }
                            final parsed = double.tryParse(
                              (value ?? '').trim(),
                            );
                            if (parsed == null) {
                              return 'Enter a valid longitude';
                            }
                            if (!_isValidLongitude(parsed)) {
                              return 'Longitude must be between -180 and 180';
                            }
                            return null;
                          },
                        ),
                        const SizedBox(height: 16),
                        SizedBox(
                          height: 48,
                          child: FilledButton(
                            onPressed: (_isSubmitting || _isFetchingLocation)
                                ? null
                                : _submitChurch,
                            child: _isSubmitting
                                ? const SizedBox(
                                    width: 20,
                                    height: 20,
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2,
                                    ),
                                  )
                                : const Text('Submit'),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

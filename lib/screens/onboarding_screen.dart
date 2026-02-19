import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';
import 'package:supabase_flutter/supabase_flutter.dart' as supa;

import 'package:synaxarium_addis/data/subscription_controller.dart';
import 'package:synaxarium_addis/models/user.dart';
import 'package:synaxarium_addis/screens/about_screen.dart' as about;
import 'package:synaxarium_addis/screens/access_blocked_screen.dart';
import 'package:synaxarium_addis/screens/pending_screen.dart';
import 'package:synaxarium_addis/screens/home_screen.dart';
import '../data/subscription_state.dart';

class OnboardingScreen extends ConsumerStatefulWidget {
  const OnboardingScreen({super.key});

  static const routeName = '/onboarding';

  @override
  ConsumerState<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends ConsumerState<OnboardingScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _phoneController = TextEditingController();
  final _promoCodeController = TextEditingController();

  UserTier _selectedTier = UserTier.normal;
  File? _paymentScreenshot;
  bool _showPaymentInfo = false;
  bool _isSubmitting = false;
  bool _isLoggingIn = false;
  String? _errorMessage;

  final ImagePicker _picker = ImagePicker();

  String _resolveGenericError(Object error, String fallback) {
    final normalized = error.toString().toLowerCase();

    if (normalized.contains('failed host lookup') ||
        normalized.contains('socketexception') ||
        normalized.contains('no address associated with hostname') ||
        normalized.contains('network') ||
        normalized.contains('connection') ||
        normalized.contains('timed out') ||
        normalized.contains('timeout')) {
      return 'የኢንተርኔት ግንኙነት ችግር አለ። ኔትወርክዎን ወይም DNS ይፈትሹ እና እንደገና ይሞክሩ።';
    }

    if (error is PhoneRecoveryFailed) {
      return error.message;
    }

    if (error is PhoneAlreadyRegistered) {
      return error.message;
    }

    if (error is ActiveSubscriptionExists) {
      return error.message;
    }

    if (error is InactiveSubscriptionExists) {
      return 'የእርስዎ ደንበኝነት አይሰራም ( ${error.status} ). ድጋፍ ያግኙ ለመደገፍ.';
    }

    if (error is supa.PostgrestException) {
      final message = (error.message).toLowerCase();
      if (error.code == '23505' || message.contains('duplicate')) {
        return 'ይህ ስልክ ቁጥር በሌላ መለያ ተያይዟል። የስልክ ቁጥር መግቢያን ይጠቀሙ ወይም ድጋፍ ያግኙ።';
      }
      if (message.contains('jwt') || message.contains('auth')) {
        return 'የመግቢያ ክፍለ ጊዜ አልተገኘም። እባክዎ እንደገና ይሞክሩ።';
      }
      if (message.contains('network') || message.contains('timeout')) {
        return 'የኢንተርኔት ግንኙነት ችግር አለ። ኔትወርክዎን ይፈትሹ እና እንደገና ይሞክሩ።';
      }
      return error.message.isNotEmpty ? error.message : fallback;
    }

    return fallback;
  }

  @override
  void dispose() {
    _nameController.dispose();
    _phoneController.dispose();
    _promoCodeController.dispose();
    super.dispose();
  }

  Future<void> _pickImage() async {
    try {
      final XFile? image = await _picker.pickImage(
        source: ImageSource.gallery,
        maxWidth: 1920,
        maxHeight: 1920,
        imageQuality: 85,
      );

      if (image != null) {
        final fileSize = await image.length();
        if (fileSize > 5 * 1024 * 1024) {
          setState(() {
            _errorMessage = 'ፋይሉ ከ5MB በላይ ነው';
          });
        } else {
          setState(() {
            _paymentScreenshot = File(image.path);
            _errorMessage = null;
          });
        }
      }
    } catch (e) {
      setState(() {
        _errorMessage = 'አልተሳካም እንደገና ይሞክሩ';
      });
    }
  }

  Future<void> _handleSubmit() async {
    setState(() {
      _errorMessage = null;
    });

    if (!_formKey.currentState!.validate()) {
      return;
    }

    if (_paymentScreenshot == null) {
      setState(() {
        _errorMessage = 'እባክዎ የደንበኝነት ማረጋገጫ ማስረጃ ይላኩ (ስክሪንሾት ወይም ሌላ ማረጋገጫ)';
      });
      return;
    }

    setState(() {
      _isSubmitting = true;
    });

    try {
      // Persist submission and move to pending without opening the app.
      await ref.read(subscriptionProvider.notifier).submit(
            name: _nameController.text.trim(),
            phone: _phoneController.text.trim(),
            promoCode: _promoCodeController.text.trim(),
            tier: _selectedTier,
            screenshotPath: _paymentScreenshot!.path,
          );

      if (mounted) {
        setState(() {
          _isSubmitting = false;
        });

        final session = ref.read(subscriptionProvider).valueOrNull;
        if (session?.status == SubscriptionStatus.active &&
            session?.accessAllowed == true) {
          Navigator.of(context).pushReplacement(
            MaterialPageRoute(builder: (_) => const HomeScreen()),
          );
        } else if (session?.status == SubscriptionStatus.pending ||
            session?.status == SubscriptionStatus.submission) {
          Navigator.of(context).pushReplacement(
            MaterialPageRoute(builder: (_) => const PendingScreen()),
          );
        } else if (session?.status == SubscriptionStatus.active &&
            session?.accessAllowed == false) {
          Navigator.of(context).pushReplacement(
            MaterialPageRoute(builder: (_) => const AccessBlockedScreen()),
          );
        } else {
          Navigator.of(context).pushReplacement(
            MaterialPageRoute(builder: (_) => const PendingScreen()),
          );
        }
      }
    } on ActiveSubscriptionExists catch (e) {
      if (!mounted) return;
      setState(() {
        _isSubmitting = false;
        _errorMessage = e.message;
      });
    } on InactiveSubscriptionExists catch (e) {
      if (!mounted) return;
      setState(() {
        _isSubmitting = false;
        _errorMessage = 'የእርስዎ ደንበኝነት አይሰራም ( ${e.status} ). ድጋፍ ያግኙ ለመደገፍ.';
      });
    } on PhoneAlreadyRegistered catch (e) {
      if (!mounted) return;
      setState(() {
        _isSubmitting = false;
        _errorMessage = e.message;
      });
    } on PhoneRecoveryFailed catch (e) {
      if (!mounted) return;
      setState(() {
        _isSubmitting = false;
        _errorMessage = e.message;
      });
    } catch (e, st) {
      debugPrint('Onboarding submit failed: $e');
      debugPrintStack(stackTrace: st);
      if (!mounted) return;
      setState(() {
        _isSubmitting = false;
        _errorMessage = _resolveGenericError(
          e,
          'አልተሳካም እንደገና ይሞክሩ',
        );
      });
    }
  }

  Future<void> _handleLoginWithPhone() async {
    setState(() {
      _errorMessage = null;
    });

    final phone = _phoneController.text.trim();
    if (phone.isEmpty || phone.length < 10) {
      setState(() {
        _errorMessage = 'እባክዎ ትክክለኛ ስልክ ቁጥር ያስገቡ';
      });
      return;
    }

    setState(() {
      _isLoggingIn = true;
    });

    try {
      await ref
          .read(subscriptionProvider.notifier)
          .loginWithPhone(phone: phone);

      if (mounted) {
        setState(() {
          _isLoggingIn = false;
        });

        final session = ref.read(subscriptionProvider).valueOrNull;
        if (session?.status == SubscriptionStatus.active &&
            session?.accessAllowed == true) {
          Navigator.of(context).pushReplacement(
            MaterialPageRoute(builder: (_) => const HomeScreen()),
          );
        } else if (session?.status == SubscriptionStatus.pending ||
            session?.status == SubscriptionStatus.submission) {
          Navigator.of(context).pushReplacement(
            MaterialPageRoute(builder: (_) => const PendingScreen()),
          );
        } else if (session?.status == SubscriptionStatus.active &&
            session?.accessAllowed == false) {
          Navigator.of(context).pushReplacement(
            MaterialPageRoute(builder: (_) => const AccessBlockedScreen()),
          );
        } else {
          setState(() {
            _errorMessage =
                'መለያውን ማስመለስ አልተሳካም። የስልክ ቁጥሩን ይፈትሹ ወይም እንደ አዲስ ይመዝገቡ።';
          });
        }
      }
    } on PhoneRecoveryFailed catch (e) {
      if (!mounted) return;
      setState(() {
        _isLoggingIn = false;
        _errorMessage = e.message;
      });
    } on PhoneAlreadyRegistered catch (e) {
      if (!mounted) return;
      setState(() {
        _isLoggingIn = false;
        _errorMessage = e.message;
      });
    } catch (e, st) {
      debugPrint('Phone login failed: $e');
      debugPrintStack(stackTrace: st);
      if (!mounted) return;
      setState(() {
        _isLoggingIn = false;
        _errorMessage = _resolveGenericError(
          e,
          'መግባት አልተሳካም። እንደገና ይሞክሩ',
        );
      });
    }
  }

  Future<void> _handleDemoAccess() async {
    setState(() {
      _errorMessage = null;
    });

    try {
      await ref.read(subscriptionProvider.notifier).activateDemo();

      if (!mounted) return;
      Navigator.of(context).pushReplacement(
        MaterialPageRoute(builder: (_) => const HomeScreen()),
      );
    } on DemoNotAllowed catch (e) {
      if (!mounted) return;
      setState(() {
        _errorMessage = e.message;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _errorMessage = 'ሙከራ መክፈት አልተሳካም።';
      });
    }
  }

  Future<void> _handleRefresh() async {
    final updated =
        await ref.read(subscriptionProvider.notifier).refreshProfileAndStatus();

    if (!mounted) return;

    if (updated.status == SubscriptionStatus.active && updated.accessAllowed) {
      Navigator.of(context).pushReplacement(
        MaterialPageRoute(builder: (_) => const HomeScreen()),
      );
      return;
    }

    if (updated.status == SubscriptionStatus.pending ||
        updated.status == SubscriptionStatus.submission) {
      Navigator.of(context).pushReplacement(
        MaterialPageRoute(builder: (_) => const PendingScreen()),
      );
      return;
    }

    if (updated.blockReason != AccessBlockReason.none &&
        updated.status == SubscriptionStatus.active) {
      Navigator.of(context).pushReplacement(
        MaterialPageRoute(builder: (_) => const AccessBlockedScreen()),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: RefreshIndicator(
          onRefresh: _handleRefresh,
          child: Container(
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [Color(0xFFF5F3FF), Colors.white],
              ),
            ),
            child: SingleChildScrollView(
              physics: const AlwaysScrollableScrollPhysics(),
              padding: const EdgeInsets.all(24),
              child: Form(
                key: _formKey,
                child: Column(
                  children: [
                    const SizedBox(height: 32),
                    // Header
                    Container(
                      width: 64,
                      height: 64,
                      decoration: BoxDecoration(
                        gradient: const LinearGradient(
                          colors: [Color(0xFF7C3AED), Color(0xFFEC4899)],
                        ),
                        borderRadius: BorderRadius.circular(16),
                        boxShadow: [
                          BoxShadow(
                            color:
                                const Color(0xFF7C3AED).withValues(alpha: 0.3),
                            blurRadius: 12,
                            offset: const Offset(0, 4),
                          ),
                        ],
                      ),
                      child: const Icon(
                        Icons.auto_awesome,
                        color: Colors.white,
                        size: 32,
                      ),
                    ),
                    const SizedBox(height: 16),
                    const Text(
                      'እንኳን ደህና መጡ',
                      style:
                          TextStyle(fontSize: 24, fontWeight: FontWeight.w500),
                    ),
                    const SizedBox(height: 16),
                    // About button
                    OutlinedButton.icon(
                      onPressed: () {
                        Navigator.of(context).push(
                          MaterialPageRoute(
                            builder: (_) => const about.AboutView(
                              previousRoute: OnboardingScreen.routeName,
                            ),
                          ),
                        );
                      },
                      icon: const Icon(Icons.info, size: 16),
                      label: const Text('ስለ መተግበሪያው'),
                      style: OutlinedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 8,
                        ),
                      ),
                    ),
                    const SizedBox(height: 24),
                    // Action buttons
                    Row(
                      children: [
                        Expanded(
                          child: OutlinedButton.icon(
                            onPressed: () {
                              setState(() {
                                _showPaymentInfo = !_showPaymentInfo;
                              });
                            },
                            icon: const Icon(Icons.help_outline),
                            label: const Text('እንዴት ደንበኛ መሆን እችላለሁ?'),
                            style: OutlinedButton.styleFrom(
                              backgroundColor: const Color(0xFFDCEEFE),
                              foregroundColor: const Color(0xFF1E40AF),
                              side: BorderSide.none,
                            ),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: OutlinedButton.icon(
                            onPressed: _handleDemoAccess,
                            icon: const Icon(Icons.flash_on),
                            label: const Text('ሙከራ'),
                            style: OutlinedButton.styleFrom(
                              backgroundColor: const Color(0xFFF3F4F6),
                              foregroundColor: const Color(0xFF374151),
                              side: BorderSide.none,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 24),
                    // Subtitle
                    const Text(
                      'አስፈላጊውን መረጃ ያስገቡ',
                      style: TextStyle(fontSize: 16, color: Color(0xFF6B7280)),
                    ),
                    const SizedBox(height: 24),
                    // Payment info panel
                    if (_showPaymentInfo) ...[
                      _buildPaymentInfoPanel(),
                      const SizedBox(height: 24),
                    ],
                    // Form fields
                    _buildTextField(
                      controller: _nameController,
                      label: 'ሙሉ ስም',
                      hint: 'ስምዎን ያስገቡ',
                      validator: (value) {
                        if (value == null || value.isEmpty) {
                          return 'እባክዎ ስምዎን ያስገቡ';
                        }
                        return null;
                      },
                    ),
                    const SizedBox(height: 20),
                    _buildTextField(
                      controller: _phoneController,
                      label: 'ስልክ ቁጥር',
                      hint: '+251 9_ _ _ _ _ _ _ _ ',
                      keyboardType: TextInputType.phone,
                      validator: (value) {
                        if (value == null ||
                            value.isEmpty ||
                            value.length < 10) {
                          return 'እባክዎ ትክክለኛ ስልክ ቁጥር ያስገቡ';
                        }
                        return null;
                      },
                    ),
                    const SizedBox(height: 12),
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: const Color(0xFFEFF6FF),
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(color: const Color(0xFFBFDBFE)),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'ከዚህ በፊት የጸደቀ አካውንት ካለዎት ስልክ ቁጥርዎን ብቻ በመጠቀም ይግቡ።',
                            style: TextStyle(
                              fontSize: 13,
                              color: Color(0xFF1E3A8A),
                            ),
                          ),
                          const SizedBox(height: 8),
                          Align(
                            alignment: Alignment.centerLeft,
                            child: OutlinedButton.icon(
                              onPressed: (_isSubmitting || _isLoggingIn)
                                  ? null
                                  : _handleLoginWithPhone,
                              icon: _isLoggingIn
                                  ? const SizedBox(
                                      width: 14,
                                      height: 14,
                                      child: CircularProgressIndicator(
                                          strokeWidth: 2),
                                    )
                                  : const Icon(Icons.login),
                              label:
                                  Text(_isLoggingIn ? 'እየገባ ነው...' : 'በስልክ ግባ'),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 20),
                    _buildTextField(
                      controller: _promoCodeController,
                      label: 'የማስተዋወቂያ ኮድ',
                      hint: 'ኮድ ካለዎት ያስገቡ',
                      helperText: '(አማራጭ)',
                    ),
                    const SizedBox(height: 20),
                    // Tier selection
                    _buildTierSelector(),
                    const SizedBox(height: 20),
                    // Image upload
                    _buildImageUpload(),
                    const SizedBox(height: 20),
                    // Error message
                    if (_errorMessage != null) ...[
                      Container(
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: const Color(0xFFFEE2E2),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: const Color(0xFFEF4444)),
                        ),
                        child: Row(
                          children: [
                            const Icon(Icons.error, color: Color(0xFFEF4444)),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Text(
                                _errorMessage!,
                                style:
                                    const TextStyle(color: Color(0xFFDC2626)),
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 20),
                    ],
                    // Submit button
                    SizedBox(
                      width: double.infinity,
                      child: FilledButton(
                        onPressed: _isSubmitting ? null : _handleSubmit,
                        style: FilledButton.styleFrom(
                          backgroundColor: const Color(0xFF7C3AED),
                          padding: const EdgeInsets.symmetric(vertical: 16),
                        ),
                        child: _isSubmitting
                            ? const Row(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  SizedBox(
                                    width: 20,
                                    height: 20,
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2,
                                      valueColor: AlwaysStoppedAnimation<Color>(
                                        Colors.white,
                                      ),
                                    ),
                                  ),
                                  SizedBox(width: 12),
                                  Text('እየላከ ነው...'),
                                ],
                              )
                            : const Text('መዝግብ'),
                      ),
                    ),
                    const SizedBox(height: 32),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildTextField({
    required TextEditingController controller,
    required String label,
    required String hint,
    String? helperText,
    TextInputType? keyboardType,
    String? Function(String?)? validator,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Text(
              label,
              style: const TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w500,
                color: Color(0xFF374151),
              ),
            ),
            if (helperText != null) ...[
              const SizedBox(width: 4),
              Text(
                helperText,
                style: const TextStyle(fontSize: 14, color: Color(0xFF9CA3AF)),
              ),
            ],
          ],
        ),
        const SizedBox(height: 8),
        TextFormField(
          controller: controller,
          decoration: InputDecoration(hintText: hint),
          keyboardType: keyboardType,
          validator: validator,
        ),
      ],
    );
  }

  Widget _buildTierSelector() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'የደንበኝነት ደረጃ',
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w500,
            color: Color(0xFF374151),
          ),
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            Expanded(
              child: _buildTierOption(
                tier: UserTier.normal,
                label: 'መደበኛ',
                subtitle: 'REGULAR',
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _buildTierOption(
                tier: UserTier.familiar,
                label: 'ወዳጃዊ',
                subtitle: 'FAMILIAR',
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildTierOption({
    required UserTier tier,
    required String label,
    required String subtitle,
  }) {
    final isSelected = _selectedTier == tier;
    return InkWell(
      onTap: () {
        setState(() {
          _selectedTier = tier;
        });
        ref.read(subscriptionProvider.notifier).selectTier(tier);
      },
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: isSelected ? const Color(0xFFF5F3FF) : Colors.white,
          border: Border.all(
            color:
                isSelected ? const Color(0xFF7C3AED) : const Color(0xFFE5E7EB),
            width: isSelected ? 2 : 1,
          ),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Column(
          children: [
            Text(
              label,
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w500,
                color: isSelected
                    ? const Color(0xFF7C3AED)
                    : const Color(0xFF374151),
              ),
            ),
            const SizedBox(height: 4),
            Text(
              subtitle,
              style: TextStyle(
                fontSize: 14,
                color: isSelected
                    ? const Color(0xFF7C3AED)
                    : const Color(0xFF6B7280),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildImageUpload() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'የደንበኝነት ማረጋገጫ /ስክሪንሾት ወይም ሌላ ማረጋገጫ',
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w500,
            color: Color(0xFF374151),
          ),
        ),
        const SizedBox(height: 8),
        InkWell(
          onTap: _pickImage,
          borderRadius: BorderRadius.circular(12),
          child: Container(
            width: double.infinity,
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              color: _paymentScreenshot != null
                  ? const Color(0xFFECFDF5)
                  : Colors.white,
              border: Border.all(
                color: _paymentScreenshot != null
                    ? const Color(0xFF10B981)
                    : const Color(0xFFD1D5DB),
                width: 2,
                style: _paymentScreenshot != null
                    ? BorderStyle.solid
                    : BorderStyle.solid,
              ),
              borderRadius: BorderRadius.circular(12),
            ),
            child: _paymentScreenshot != null
                ? Column(
                    children: [
                      const Icon(
                        Icons.check_circle,
                        size: 32,
                        color: Color(0xFF10B981),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        _paymentScreenshot!.path.split('/').last,
                        style: const TextStyle(
                          color: Color(0xFF059669),
                          fontWeight: FontWeight.w500,
                        ),
                        textAlign: TextAlign.center,
                      ),
                    ],
                  )
                : const Column(
                    children: [
                      Icon(
                        Icons.upload_file,
                        size: 32,
                        color: Color(0xFF9CA3AF),
                      ),
                      SizedBox(height: 8),
                      Text(
                        'ፋይል ለመስቀል ይንኩ',
                        style: TextStyle(color: Color(0xFF6B7280)),
                      ),
                      SizedBox(height: 4),
                      Text(
                        'PNG, JPG (ከ5MB በታች)',
                        style: TextStyle(
                          fontSize: 12,
                          color: Color(0xFF9CA3AF),
                        ),
                      ),
                    ],
                  ),
          ),
        ),
      ],
    );
  }

  Widget _buildPaymentInfoPanel() {
    return Container(
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFFDCEEFE), Color(0xFFCFFAFE)],
        ),
        border: Border.all(color: const Color(0xFF93C5FD), width: 2),
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF3B82F6).withValues(alpha: 0.1),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Row(
            children: [
              Icon(Icons.help_outline, color: Color(0xFF1E40AF)),
              SizedBox(width: 8),
              Text(
                'የመመዝገቢያ መመሪያዎች',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w500,
                  color: Color(0xFF1E3A8A),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          const Text(
            '1. ከዚህ በታች ወደተጠቀሱት አድራሻዎች ክፍያ ይፈጽሙ:',
            style: TextStyle(
              fontWeight: FontWeight.w500,
              color: Color(0xFF1E40AF),
            ),
          ),
          const SizedBox(height: 8),
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(8),
            ),
            child: Column(
              children: [
                _buildPaymentRow('የንግድ ባንክ:', '0912-345-678'),
                const SizedBox(height: 8),
                _buildPaymentRow('ቴሌ ብር:', '0911-234-567'),
              ],
            ),
          ),
          const SizedBox(height: 16),
          const Text(
            '2. የክፍያ መጠን:',
            style: TextStyle(
              fontWeight: FontWeight.w500,
              color: Color(0xFF1E40AF),
            ),
          ),
          const SizedBox(height: 8),
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(8),
            ),
            child: Column(
              children: [
                _buildPaymentRow('REGULAR:', '200 ብር/ወር'),
                const SizedBox(height: 8),
                _buildPaymentRow('FAMILIAR:', '500 ብር/ወር'),
              ],
            ),
          ),
          const SizedBox(height: 16),
          const Text(
            '3. ማረጋገጫ:',
            style: TextStyle(
              fontWeight: FontWeight.w500,
              color: Color(0xFF1E40AF),
            ),
          ),
          const SizedBox(height: 4),
          const Text(
            'ከከፈሉ በኋላ የደንበኝነት ማረጋገጫ ያስቀምጡ እና ከላይ ባለው ቅጽ ይስቀሉ።',
            style: TextStyle(fontSize: 14, color: Color(0xFF1E40AF)),
          ),
          const SizedBox(height: 12),
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: const Color(0xFFFEF3C7),
              border: Border.all(color: const Color(0xFFFCD34D)),
              borderRadius: BorderRadius.circular(8),
            ),
            child: const Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('💡', style: TextStyle(fontSize: 16)),
                SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'ማስታወሻ: ማረጋገጫ ከተላከ በኋላ በ24 ሰዓት ውስጥ መተግበሪያው ሥራ ይጀምራል።',
                    style: TextStyle(fontSize: 12, color: Color(0xFF78350F)),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPaymentRow(String label, String value) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(label, style: const TextStyle(color: Color(0xFF6B7280))),
        Text(
          value,
          style: const TextStyle(
            fontWeight: FontWeight.w500,
            color: Color(0xFF111827),
          ),
        ),
      ],
    );
  }
}

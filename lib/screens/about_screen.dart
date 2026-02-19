import 'package:flutter/material.dart';

class AboutView extends StatelessWidget {
  final String previousRoute;

  const AboutView({super.key, required this.previousRoute});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Container(
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [Color(0xFFF5F3FF), Colors.white],
            ),
          ),
          child: Column(
            children: [
              // Header
              Container(
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: const BorderRadius.only(
                    bottomLeft: Radius.circular(24),
                    bottomRight: Radius.circular(24),
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.05),
                      blurRadius: 10,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                padding: const EdgeInsets.all(24),
                child: Column(
                  children: [
                    Row(
                      children: [
                        IconButton(
                          onPressed: () => Navigator.of(context).pop(),
                          icon: const Icon(Icons.arrow_back),
                          padding: EdgeInsets.zero,
                          constraints: const BoxConstraints(),
                        ),
                        const SizedBox(width: 8),
                        const Text('ወደኋላ', style: TextStyle(fontSize: 16)),
                      ],
                    ),
                    const SizedBox(height: 16),
                    Container(
                      width: 64,
                      height: 64,
                      decoration: BoxDecoration(
                        color: const Color(0xFFF5F3FF),
                        borderRadius: BorderRadius.circular(16),
                      ),
                      child: const Icon(
                        Icons.auto_awesome,
                        size: 40,
                        color: Color(0xFF7C3AED),
                      ),
                    ),
                    const SizedBox(height: 12),
                    const Text(
                      'ስንክሳር አዲስ',
                      style: TextStyle(
                        fontSize: 24,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    const SizedBox(height: 4),
                    const Text(
                      'Synaxarium Addis',
                      style: TextStyle(fontSize: 16, color: Color(0xFF6B7280)),
                    ),
                  ],
                ),
              ),
              // Content
              Expanded(
                child: ListView(
                  padding: const EdgeInsets.all(24),
                  children: [
                    _buildAboutAppCard(),
                    const SizedBox(height: 24),
                    _buildFeaturesCard(),
                    const SizedBox(height: 24),
                    _buildTiersCard(),
                    const SizedBox(height: 24),
                    _buildContactCard(),
                    const SizedBox(height: 24),
                    // Version footer
                    const Center(
                      child: Column(
                        children: [
                          Text(
                            'ስሪት 1.0.0',
                            style: TextStyle(
                              fontSize: 14,
                              color: Color(0xFF6B7280),
                            ),
                          ),
                          SizedBox(height: 4),
                          Text(
                            '© 2026 ስንክሳር አዲስ. መብቱ በህግ የተጠበቀ ነው።',
                            style: TextStyle(
                              fontSize: 14,
                              color: Color(0xFF6B7280),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 24),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildAboutAppCard() {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.1),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.all(16),
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                colors: [Color(0xFF3B82F6), Color(0xFF8B5CF6)],
              ),
              borderRadius: BorderRadius.only(
                topLeft: Radius.circular(16),
                topRight: Radius.circular(16),
              ),
            ),
            child: const Row(
              children: [
                Text(
                  'ስለ መተግበሪያው',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w500,
                    color: Colors.white,
                  ),
                ),
              ],
            ),
          ),
          const Padding(
            padding: EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'ስንክሳር አዲስ የኢትዮጵያ ኦርቶዶክስ ተዋሕዶ ቤተክርስቲያን በዓላትና አቅራቢያዎ ያሉ ቤተክርስቲያናትን ለማግኘት የሚያስችል ዘመናዊ መተግበሪያ ነው።',
                  style: TextStyle(
                    fontSize: 16,
                    color: Color(0xFF374151),
                    height: 1.5,
                  ),
                ),
                SizedBox(height: 16),
                Text(
                  'የቀን በዓላትን፣ በዓሉ የሚከበርበትን ቤተክርስቲያን፣ እና ከእርስዎ በ3 ኪሎሜትር ራዲየስ ውስጥ ያሉ ቤተክርስቲያናትን በቀላሉ ማግኘት ይችላሉ።',
                  style: TextStyle(
                    fontSize: 16,
                    color: Color(0xFF374151),
                    height: 1.5,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFeaturesCard() {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.1),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.all(16),
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                colors: [Color(0xFF10B981), Color(0xFF14B8A6)],
              ),
              borderRadius: BorderRadius.only(
                topLeft: Radius.circular(16),
                topRight: Radius.circular(16),
              ),
            ),
            child: const Row(
              children: [
                Text(
                  'አገልግሎቶች',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w500,
                    color: Colors.white,
                  ),
                ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              children: [
                _buildFeatureRow(
                  icon: Icons.calendar_today,
                  color: const Color(0xFF3B82F6),
                  title: 'የቀን በዓላት',
                  description: 'በየቀኑ የሚከበሩ በዓላትን እና ስለ በዓሉ መረጃ ያቀርባል',
                ),
                const SizedBox(height: 16),
                _buildFeatureRow(
                  icon: Icons.church,
                  color: const Color(0xFF10B981),
                  title: 'አቅራቢያዎ ያሉ አብያተ ክርስትያናት',
                  description: 'ከእርስዎ በ3 ኪሎሜትር ውስጥ ያሉ ቤተክርስቲያናትን ያሳውቃል',
                ),
                const SizedBox(height: 16),
                _buildFeatureRow(
                  icon: Icons.map,
                  color: const Color(0xFF7C3AED),
                  title: 'የጉግል ካርታ ውህደት',
                  description: 'ወደ ቤተክርስቲያን የሚወስደውን መንገድ በቀላሉ ይጠቁማል',
                ),
                const SizedBox(height: 16),
                _buildFeatureRow(
                  icon: Icons.lock,
                  color: const Color(0xFFF97316),
                  title: 'የደንበኝነት ደረጃዎች',
                  description: 'መደበኛ እና ወዳጃዊ ደረጃዎች ከተጨማሪ ጥቅሞች ጋር',
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFeatureRow({
    required IconData icon,
    required Color color,
    required String title,
    required String description,
  }) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          width: 40,
          height: 40,
          decoration: BoxDecoration(
            color: color.withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Icon(icon, size: 20, color: color),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w500,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                description,
                style: const TextStyle(fontSize: 14, color: Color(0xFF6B7280)),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildTiersCard() {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.1),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.all(16),
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                colors: [Color(0xFFF97316), Color(0xFFEF4444)],
              ),
              borderRadius: BorderRadius.only(
                topLeft: Radius.circular(16),
                topRight: Radius.circular(16),
              ),
            ),
            child: const Row(
              children: [
                Text(
                  'የደንበኝነት ደረጃዎች',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w500,
                    color: Colors.white,
                  ),
                ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              children: [
                _buildTierRow(
                  gradient: const [Color(0xFF9CA3AF), Color(0xFF6B7280)],
                  tier: 'DEMO',
                  description: 'የተወሰነ መረጃ፣ መሰረታዊ ባህሪያት',
                  backgroundColor: const Color(0xFFF3F4F6),
                ),
                const SizedBox(height: 12),
                _buildTierRow(
                  gradient: const [Color(0xFF3B82F6), Color(0xFF8B5CF6)],
                  tier: 'REGULAR',
                  description:
                      'ሙሉ የበዓላት መረጃ እና ሁሉም ባህሪያት። መደበኛ ተጠቃሚዎች የአንድ ስልክ እና አንድ ጊዜ መግቢያ ይጠቀማሉ።',
                  backgroundColor: const Color(0xFFEFF6FF),
                  borderColor: const Color(0xFF8B5CF6),
                ),
                const SizedBox(height: 12),
                _buildTierRow(
                  gradient: const [Color(0xFFFBBF24), Color(0xFFF97316)],
                  tier: 'FAMILIAR',
                  description:
                      'ሙሉ የበዓላት መረጃ እና ሁሉም ባህሪያት።ወዳጃዊ ተጠቃሚዎች በሁለት ስልክ እንዲሁም በእያንዳንዱ ስልክ ሦስት ሦስት ጊዜ መግባት ይችላሉ።',
                  backgroundColor: const Color(0xFFFEF3C7),
                  borderColor: const Color(0xFFF97316),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTierRow({
    required List<Color> gradient,
    required String tier,
    required String description,
    required Color backgroundColor,
    Color? borderColor,
  }) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: backgroundColor,
        borderRadius: BorderRadius.circular(12),
        border: borderColor != null
            ? Border.all(color: borderColor, width: 2)
            : null,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
            decoration: BoxDecoration(
              gradient: LinearGradient(colors: gradient),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Text(
              tier,
              style: const TextStyle(
                fontSize: 14,
                color: Colors.white,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
          const SizedBox(height: 8),
          Text(
            description,
            style: const TextStyle(fontSize: 14, color: Color(0xFF6B7280)),
          ),
        ],
      ),
    );
  }

  Widget _buildContactCard() {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.1),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.all(16),
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                colors: [Color(0xFFEC4899), Color(0xFF8B5CF6)],
              ),
              borderRadius: BorderRadius.only(
                topLeft: Radius.circular(16),
                topRight: Radius.circular(16),
              ),
            ),
            child: const Row(
              children: [
                Text(
                  'ያግኙን',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w500,
                    color: Colors.white,
                  ),
                ),
              ],
            ),
          ),
          const Padding(
            padding: EdgeInsets.all(20),
            child: Column(
              children: [
                Row(
                  children: [
                    Icon(Icons.email, size: 20, color: Color(0xFF7C3AED)),
                    SizedBox(width: 12),
                    Text(
                      'telegram.me/synaxariumaddis',
                      style: TextStyle(fontSize: 16, color: Color(0xFF374151)),
                    ),
                  ],
                ),
                SizedBox(height: 12),
                Row(
                  children: [
                    Icon(Icons.phone, size: 20, color: Color(0xFF7C3AED)),
                    SizedBox(width: 12),
                    Text(
                      '+251 911 234 567',
                      style: TextStyle(fontSize: 16, color: Color(0xFF374151)),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:url_launcher/url_launcher.dart';
import 'dart:developer';
import 'edit_profile.dart';

class ProfileScreen extends StatefulWidget {
  final String? initialUsername;

  const ProfileScreen({Key? key, this.initialUsername}) : super(key: key);

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  Map<String, dynamic>? _profileData;
  bool _isLoading = true;
  final _supabase = Supabase.instance.client;

  @override
  void initState() {
    super.initState();
    _loadProfile();
  }

  Future<void> _loadProfile() async {
    if (!mounted) return;
    setState(() => _isLoading = true);
    try {
      final userId = _supabase.auth.currentUser!.id;
      final data = await _supabase.from('profiles').select().eq('id', userId).single();
      if (mounted) {
        setState(() {
          _profileData = data;
        });
      }
    } catch (e) {
      log("Error loading profile: $e");
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error loading profile.'), backgroundColor: Colors.red));
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _launchUrl(String? urlString) async {
    if (urlString == null || urlString.isEmpty) return;
    final Uri url = Uri.parse(urlString.startsWith('http') ? urlString : 'https://$urlString');
    if (!await launchUrl(url, mode: LaunchMode.externalApplication)) {
       ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Could not launch $urlString')));
    }
  }

 @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white, // Ensures the background is white
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _profileData == null
              ? _buildErrorState()
              : RefreshIndicator(
                  onRefresh: _loadProfile,
                  child: CustomScrollView(
                    slivers: [
                      _buildAppBar(),
                      _buildContent(),
                    ],
                  ),
                ),
    );
  }

  Widget _buildErrorState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Text('Failed to load profile.', style: TextStyle(fontSize: 18)),
          const SizedBox(height: 10),
          ElevatedButton(onPressed: _loadProfile, child: const Text('Try Again')),
        ],
      ),
    );
  }

  SliverAppBar _buildAppBar() {
    final headerUrl = _profileData?['header_url'] as String?;
    final hasHeader = headerUrl != null && headerUrl.isNotEmpty;

    return SliverAppBar(
      expandedHeight: 140.0, // Height of the header image area
      pinned: true,
      stretch: true,
      elevation: 0,
      backgroundColor: const Color(0xFF27538C),
      flexibleSpace: FlexibleSpaceBar(
        stretchModes: const [StretchMode.zoomBackground],
        background: hasHeader
            ? Image.network(headerUrl!, fit: BoxFit.cover, errorBuilder: (context, error, stackTrace) => Container(color: const Color(0xFFA9B2BC))) 
            : Container(color: const Color(0xFFA9B2BC)),
      ),
    );
  }

  Widget _buildContent() {
    final avatarUrl = _profileData?['avatar_url'] as String?;
    final name = _profileData?['name'] as String? ?? 'No Name';
    final username = _profileData?['username'] as String? ?? 'no_username';
    final bio = _profileData?['bio'] as String?;
    final website = _profileData?['website'] as String?;
    
    return SliverToBoxAdapter(
      child: Stack(
        clipBehavior: Clip.none, // Allows the avatar to overflow
        children: [
          // The main white content area
          Container(
            width: double.infinity,
            color: Colors.white,
            padding: const EdgeInsets.symmetric(horizontal: 16.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // This SizedBox provides vertical space between the avatar and the Edit button
                const SizedBox(height: 12),
                Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                     ElevatedButton(
                      onPressed: () async {
                        final result = await Navigator.of(context).push<bool>(
                          MaterialPageRoute(builder: (context) => const EditProfileScreen()),
                        );
                        if (result == true) {
                          _loadProfile();
                        }
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF27538C),
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(53)),
                        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                      ),
                      child: const Text('Edit Profile', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                    ),
                  ],
                ),
                const SizedBox(height: 4), // Space between button and name
                Text(name, style: const TextStyle(fontSize: 26, fontWeight: FontWeight.bold, color: Color(0xFF1B2E47))),
                const SizedBox(height: 2),
                Text('@$username', style: TextStyle(fontSize: 16, color: Colors.grey[600])),
                if (bio != null && bio.isNotEmpty) ...[
                  const SizedBox(height: 16),
                  Text(bio, style: const TextStyle(fontSize: 16, height: 1.4)),
                ],
                if (website != null && website.isNotEmpty) ...[
                  const SizedBox(height: 16),
                  GestureDetector(
                    onTap: () => _launchUrl(website),
                    child: Row(
                      children: [
                        Icon(Icons.link, color: Colors.grey[600], size: 20),
                        const SizedBox(width: 8),
                        Flexible(child: Text(website, style: const TextStyle(fontSize: 16, color: Color(0xFF558DCA)), overflow: TextOverflow.ellipsis)),
                      ],
                    ),
                  ),
                ],
                const SizedBox(height: 24),
                _buildFollowStats(),
                 const SizedBox(height: 24),
              ],
            ),
          ),
          // Avatar, positioned to pop out of the top of the Stack
          Positioned(
            top: -60, // Negative value makes it overlap the SliverAppBar
            left: 16,
            child: CircleAvatar(
              radius: 60, // White border
              backgroundColor: Colors.white,
              child: CircleAvatar(
                radius: 55, // Avatar size
                backgroundImage: (avatarUrl != null && avatarUrl.isNotEmpty) ? NetworkImage(avatarUrl) : null,
                child: (avatarUrl == null || avatarUrl.isEmpty)
                    ? const Icon(Icons.person, size: 55, color: Colors.grey)
                    : null,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFollowStats() {
    return Row(
      children: [
        _followStat('0', 'Followers'),
        const SizedBox(width: 24),
        _followStat('0', 'Following'),
        const SizedBox(width: 24),
        _followStat('0', 'Tree'),
      ],
    );
  }

  Widget _followStat(String count, String label) {
    return Row(
      children: [
        Text(count, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
        const SizedBox(width: 4),
        Text(label, style: TextStyle(fontSize: 16, color: Colors.grey[600])),
      ],
    );
  }
}

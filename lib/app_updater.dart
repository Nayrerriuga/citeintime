import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:ota_update/ota_update.dart';
import 'package:shared_preferences/shared_preferences.dart'; // or compare build ID

class AppUpdater {
  // Replace with your GitHub username and repo name
  static const String repoOwner = 'YOUR_GITHUB_USERNAME';
  static const String repoName = 'geofence-attendance';

  static Future<void> checkForUpdate(BuildContext context) async {
    try {
      final url = Uri.parse(
        'https://api.github.com/repos/$repoOwner/$repoName/releases/tags/latest',
      );
      final response = await http.get(url);
      if (response.statusCode != 200) return;

      final data = jsonDecode(response.body);
      final latestBuildName =
          data['name'] as String; // e.g., "Latest Build (14)"
      final assets = data['assets'] as List<dynamic>;
      if (assets.isEmpty) return;

      final apkUrl = assets.first['browser_download_url'] as String;

      // Compare against last installed build name saved on device
      final prefs = await SharedPreferences.getInstance();
      final installedBuild = prefs.getString('installed_build_name');

      if (installedBuild == null) {
        // First launch: record current version
        await prefs.setString('installed_build_name', latestBuildName);
        return;
      }

      if (installedBuild != latestBuildName && context.mounted) {
        _showUpdateDialog(context, latestBuildName, apkUrl, prefs);
      }
    } catch (e) {
      debugPrint('Update check skipped: $e');
    }
  }

  static void _showUpdateDialog(
    BuildContext context,
    String newVersion,
    String apkUrl,
    SharedPreferences prefs,
  ) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => AlertDialog(
        title: const Text('App Update Available'),
        content: Text('A new version ($newVersion) is ready to install.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Later'),
          ),
          FilledButton(
            onPressed: () async {
              Navigator.pop(ctx);
              await prefs.setString('installed_build_name', newVersion);
              // Downloads APK and opens Android's package installer automatically
              OtaUpdate().execute(
                apkUrl,
                destinationFilename: 'citeintime.apk',
              );
            },
            child: const Text('Update Now'),
          ),
        ],
      ),
    );
  }
}

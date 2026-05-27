import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../models/video_model.dart';
import '../providers/localization_provider.dart';
import '../providers/video_provider.dart';
import '../utils/app_strings.dart';
import '../widgets/video_card.dart';
import 'video_player_screen.dart';

class HistoryScreen extends StatefulWidget {
  const HistoryScreen({super.key});

  @override
  State<HistoryScreen> createState() => _HistoryScreenState();
}

class _HistoryScreenState extends State<HistoryScreen> {
  List<VideoModel> _watchHistory = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadHistory();
  }

  Future<void> _loadHistory() async {
    final history = await context.read<VideoProvider>().getWatchHistory();
    if (!mounted) {
      return;
    }

    setState(() {
      _watchHistory = history;
      _isLoading = false;
    });
  }

  Future<void> _clearHistory() async {
    await context.read<VideoProvider>().clearWatchHistory();
    if (!mounted) {
      return;
    }

    setState(() {
      _watchHistory = [];
    });
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Consumer<LocalizationProvider>(
      builder: (context, locProvider, _) {
        final lang = locProvider.currentLanguage;

        return Scaffold(
          appBar: AppBar(
            title: Text(
              AppStrings.getByLang('history', lang),
              style: theme.appBarTheme.titleTextStyle,
            ),
            actions: [
              if (_watchHistory.isNotEmpty)
                IconButton(
                  onPressed: _clearHistory,
                  tooltip: AppStrings.getByLang('clearHistory', lang),
                  icon: const Icon(Icons.delete_sweep_rounded),
                ),
            ],
          ),
          body: _isLoading
              ? const Center(child: CircularProgressIndicator())
              : _watchHistory.isEmpty
              ? Center(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 24),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          Icons.history_rounded,
                          size: 64,
                          color: Colors.grey.shade400,
                        ),
                        const SizedBox(height: 16),
                        Text(
                          AppStrings.getByLang('noHistory', lang),
                          style: theme.textTheme.titleLarge,
                          textAlign: TextAlign.center,
                        ),
                        const SizedBox(height: 8),
                        Text(
                          AppStrings.getByLang('historyTip', lang),
                          style: theme.textTheme.bodyMedium,
                          textAlign: TextAlign.center,
                        ),
                      ],
                    ),
                  ),
                )
              : ListView.builder(
                  padding: const EdgeInsets.symmetric(vertical: 8),
                  itemCount: _watchHistory.length,
                  itemBuilder: (context, index) {
                    final video = _watchHistory[index];
                    return VideoCard(
                      video: video,
                      isCompact: true,
                      onTap: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) => VideoPlayerScreen(video: video),
                          ),
                        ).then((_) => _loadHistory());
                      },
                    );
                  },
                ),
        );
      },
    );
  }
}
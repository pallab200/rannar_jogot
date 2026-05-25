import 'package:flutter_test/flutter_test.dart';
import 'package:rannar_jogot/models/video_model.dart';

void main() {
  group('VideoModel short-form detection', () {
    test('flags sub-minute videos as short-form', () {
      final video = _buildVideo(duration: '00:59');

      expect(video.isShortForm, isTrue);
    });

    test('flags metadata tagged shorts even with longer duration', () {
      final video = _buildVideo(
        title: '#Shorts easy chicken recipe',
        duration: '03:15',
      );

      expect(video.isShortForm, isTrue);
    });

    test('keeps regular long-form recipe videos', () {
      final video = _buildVideo(
        title: 'Traditional fish curry recipe',
        description: 'Step by step Bangladeshi cooking tutorial',
        duration: '08:30',
      );

      expect(video.isShortForm, isFalse);
    });
  });
}

VideoModel _buildVideo({
  String title = 'Recipe video',
  String description = 'Detailed cooking guide',
  String duration = '05:00',
}) {
  return VideoModel(
    id: 'video-1',
    title: title,
    description: description,
    thumbnailUrl: 'https://img.youtube.com/vi/video-1/hqdefault.jpg',
    channelTitle: 'Cooking Channel',
    channelId: 'channel-1',
    publishedAt: '2026-05-20T10:00:00Z',
    duration: duration,
  );
}
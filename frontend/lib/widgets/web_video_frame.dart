import 'package:flutter/widgets.dart';

import 'package:compliance_training_app/widgets/web_video_frame_stub.dart'
    if (dart.library.html) 'package:compliance_training_app/widgets/web_video_frame_web.dart' as impl;

class WebVideoFrame extends StatelessWidget {
  const WebVideoFrame({super.key, required this.url, required this.aspectRatio});

  final String url;
  final double aspectRatio;

  @override
  Widget build(BuildContext context) {
    return impl.buildWebVideoFrame(url: url, aspectRatio: aspectRatio);
  }
}

// ignore_for_file: avoid_web_libraries_in_flutter, deprecated_member_use

import 'dart:html' as html;
import 'dart:ui_web' as ui_web;

import 'package:flutter/widgets.dart';

final Set<String> _registeredViewTypes = <String>{};

Widget buildWebVideoFrame({required String url, required double aspectRatio}) {
  final viewType = 'video-iframe-${url.hashCode}';
  if (!_registeredViewTypes.contains(viewType)) {
    ui_web.platformViewRegistry.registerViewFactory(viewType, (int viewId) {
      final element = html.IFrameElement()
        ..src = url
        ..style.border = 'none'
        ..allow = 'autoplay; fullscreen'
        ..allowFullscreen = true;
      return element;
    });
    _registeredViewTypes.add(viewType);
  }

  return AspectRatio(
    aspectRatio: aspectRatio,
    child: HtmlElementView(viewType: viewType),
  );
}

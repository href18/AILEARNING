import 'package:flutter/material.dart';

Widget buildWebVideoFrame({required String url, required double aspectRatio}) {
  return AspectRatio(
    aspectRatio: aspectRatio,
    child: Container(
      color: const Color(0xFF1E1E1E),
      alignment: Alignment.center,
      child: const Icon(Icons.play_circle_outline, color: Color(0x66FFFFFF), size: 48),
    ),
  );
}

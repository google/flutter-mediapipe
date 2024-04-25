import 'dart:math';
import 'package:example/llm_model.dart';
import 'package:example/model_location_provider.dart';
import 'package:flutter/material.dart';
import 'package:getwidget/getwidget.dart';
import 'package:provider/provider.dart';

class ModelStatusBar extends StatelessWidget {
  const ModelStatusBar(
    this.model, {
    required this.delete,
    required this.download,
    super.key,
  });

  final LlmModel model;
  final VoidCallback delete;
  final VoidCallback download;

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<ModelLocationProvider>();
    final path = provider.pathFor(model);
    final downloadedBinarySize = path != null //
        ? provider.binarySize(path)
        : null;
    Stream<double>? downloadStream = provider.getInProgressDownload(model);

    if (downloadStream != null) {
      return StreamBuilder<double>(
          stream: downloadStream,
          builder: (context, snapshot) {
            double progress = snapshot.data ?? 0;
            String progressDisplay =
                (progress * 100).toInt().toString().padLeft(2, '0');
            return GFProgressBar(
              percentage: progress,
              lineHeight: 20,
              backgroundColor: Colors.green[100]!,
              progressBarColor: Colors.green[700]!,
              child: Padding(
                padding: const EdgeInsets.only(right: 5),
                child: Text(
                  '$progressDisplay%',
                  textAlign: TextAlign.center,
                  style: const TextStyle(fontSize: 16, color: Colors.white),
                ),
              ),
            );
          });
    } else if (downloadedBinarySize != null) {
      return Card(
        child: ListTile(
          leading: const Icon(Icons.check, color: Colors.green),
          title: Text('File size: ${humanize(downloadedBinarySize)}'),
          trailing: IconButton(
            icon: const Icon(Icons.delete, color: Colors.red),
            onPressed: delete,
          ),
        ),
      );
    } else {
      return TextButton(
        onPressed: download,
        child: const Text('Download'),
      );
    }
  }
}

final gigaByte = pow(2, 30);
final megaByte = pow(2, 20);

String humanize(int fileSize) {
  if (fileSize > gigaByte) {
    return '${(fileSize / gigaByte).roundTo(2)} GB';
  } else if (fileSize > megaByte) {
    return '${(fileSize / megaByte).roundTo(2)} MB';
  }
  return '$fileSize bytes';
}

extension RoundableDouble on double {
  double roundTo(int decimalPlaces) =>
      double.parse(toStringAsFixed(decimalPlaces));
}

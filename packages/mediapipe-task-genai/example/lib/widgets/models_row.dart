// Copyright 2014 The Flutter Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.
import 'dart:math';

import 'package:adaptive_dialog/adaptive_dialog.dart';
import 'package:example/models/models.dart';
import 'package:flutter/material.dart';
import 'package:getwidget/components/progress_bar/gf_progress_bar.dart';

class ModelsRow extends StatelessWidget {
  const ModelsRow({
    super.key,
    required this.deleteModel,
    required this.downloadModel,
    required this.modelInfoMap,
    required this.selected,
    required this.selectModel,
  });

  final LlmModel selected;

  final Map<LlmModel, ModelInfo> modelInfoMap;

  /// Handler to delete the selected model.
  final VoidCallback deleteModel;

  /// Handler to downloaded the selected model.
  final VoidCallback downloadModel;

  /// Handler to change the selected model.
  final void Function(LlmModel) selectModel;

  @override
  Widget build(BuildContext context) {
    return ListView(
      scrollDirection: Axis.horizontal,
      children: <Widget>[
        Padding(
          padding: const EdgeInsets.only(right: 4),
          child: _modelsRowEntry(LlmModel.gemma4bCpu),
        ),
        Padding(
          padding: const EdgeInsets.only(right: 4),
          child: _modelsRowEntry(LlmModel.gemma4bGpu),
        ),
        Padding(
          padding: const EdgeInsets.only(right: 4),
          child: _modelsRowEntry(LlmModel.gemma8bCpu),
        ),
        Padding(
          padding: const EdgeInsets.only(right: 4),
          child: _modelsRowEntry(LlmModel.gemma8bGpu),
        ),
      ],
    );
  }

  Widget _modelsRowEntry(LlmModel model) {
    return ModelsRowEntry(
      model,
      modelInfo: modelInfoMap[model]!,
      isSelected: model == selected,
      selectModel: () => selectModel(model),
      delete: deleteModel,
      download: downloadModel,
    );
  }
}

class ModelsRowEntry extends StatelessWidget {
  const ModelsRowEntry(
    this.model, {
    required this.delete,
    required this.download,
    required this.modelInfo,
    required this.isSelected,
    required this.selectModel,
    super.key,
  });

  final LlmModel model;
  final bool isSelected;
  final ModelInfo modelInfo;

  /// Handler to change the selected model.
  final VoidCallback selectModel;

  final VoidCallback download;
  final VoidCallback delete;

  @override
  Widget build(BuildContext context) {
    final Color borderColor = modelInfo.downloadedBytes != null //
        ? Colors.green
        : Colors.orange;

    // String? progressDisplay = downloadPercent != null
    //     ? (downloadPercent! * 100).toInt().toString().padLeft(2, '0')
    //     : null;

    return GestureDetector(
      onTap: !isSelected ? selectModel : () => _launchModal(context),
      child: Container(
        height: 100,
        width: 100,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(5),
          border: isSelected //
              ? Border.all(color: borderColor, width: 3)
              : null,
          color: Colors.grey[200],
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: <Widget>[
            Text(model.displayName, style: const TextStyle(fontSize: 12)),
            Padding(
              padding: const EdgeInsets.only(top: 6),
              child: switch (modelInfo.state) {
                ModelState.downloaded =>
                  _DownloadedInfo(modelInfo.downloadedBytes!),
                ModelState.downloading =>
                  _DownloadingBar(downloadPercent: modelInfo.downloadPercent!),
                ModelState.empty => const Icon(Icons.download),
              },
            ),
          ],
        ),
      ),
    );
  }

  void _launchModal(BuildContext context) {
    final VoidCallback? actionHandler = switch (modelInfo.state) {
      ModelState.downloaded => delete,
      ModelState.downloading => null,
      ModelState.empty => download,
    };
    if (actionHandler == null) {
      return;
    }
    final String title = switch (modelInfo.state) {
      ModelState.downloaded => 'Delete',
      ModelState.downloading => '',
      ModelState.empty => 'Download',
    };

    final String? message = switch (modelInfo.state) {
      ModelState.downloaded =>
        'Would you like to delete this downloaded model?',
      ModelState.downloading => null,
      ModelState.empty => 'Would you like to download this model?',
    };

    showAlertDialog<bool>(
      context: context,
      title: title,
      message: message,
      actions: <AlertDialogAction<bool>>[
        AlertDialogAction<bool>(
          key: false,
          label: 'Cancel',
          isDefaultAction: true,
          isDestructiveAction: modelInfo.state == ModelState.downloaded,
        ),
        AlertDialogAction<bool>(
          key: true,
          label: title,
          isDefaultAction: true,
          isDestructiveAction: modelInfo.state == ModelState.downloaded,
        ),
      ],
    ).then((result) {
      if (result == true) {
        actionHandler();
      }
    });
  }
}

class _DownloadedInfo extends StatelessWidget {
  const _DownloadedInfo(this.downloadedBytes);

  final int downloadedBytes;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
      children: <Widget>[
        Text(
          humanize(downloadedBytes),
          style: TextStyle(fontSize: 11, color: Colors.grey[600]!),
        ),
        const Icon(Icons.check, color: Colors.green)
      ],
    );
  }
}

class _DownloadingBar extends StatelessWidget {
  const _DownloadingBar({required this.downloadPercent});

  final int downloadPercent;

  @override
  Widget build(BuildContext context) {
    return GFProgressBar(
      percentage: (downloadPercent / 100).toDouble().clamp(0, 1.0),
      lineHeight: 8,
      backgroundColor: Colors.green[100]!,
      progressBarColor: Colors.green[700]!,
    );
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

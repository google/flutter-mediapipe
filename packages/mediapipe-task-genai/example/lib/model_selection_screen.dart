// import 'package:example/bloc.dart';
import 'dart:math';

import 'package:adaptive_dialog/adaptive_dialog.dart';
import 'package:example/models/llm_model.dart';
import 'package:flutter/material.dart';
import 'package:getwidget/getwidget.dart';

class ModelSelectionScreen extends StatelessWidget {
  const ModelSelectionScreen({
    required this.deleteModel,
    required this.downloadModel,
    required this.modelInfoMap,
    required this.modelsReady,
    required this.selectModel,
    super.key,
  });

  // final TranscriptBloc bloc;
  final Map<LlmModel, ModelInfo> modelInfoMap;
  final bool modelsReady;

  /// Handler to delete the selected model.
  final Function(LlmModel) deleteModel;

  /// Handler to downloaded the selected model.
  final Function(LlmModel) downloadModel;

  /// Handler to change the selected model.
  final Function(LlmModel) selectModel;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(8.0),
      child: ListView(
        // scrollDirection: Axis.horizontal,
        children: <Widget>[
          _modelSelectionTile(LlmModel.gemma4bCpu),
          _modelSelectionTile(LlmModel.gemma4bGpu),
          _modelSelectionTile(LlmModel.gemma8bCpu),
          _modelSelectionTile(LlmModel.gemma8bGpu),
        ],
      ),
    );
  }

  Widget _modelSelectionTile(LlmModel model) {
    return ModelSelectionTile(
      model,
      ready: modelsReady,
      modelInfo: modelInfoMap[model]!,
      selectModel: () => selectModel(model),
      delete: () => deleteModel(model),
      download: () => downloadModel(model),
    );
  }
}

class ModelSelectionTile extends StatelessWidget {
  const ModelSelectionTile(
    this.model, {
    required this.delete,
    required this.download,
    required this.modelInfo,
    required this.ready,
    required this.selectModel,
    super.key,
  });

  final LlmModel model;
  final ModelInfo modelInfo;

  /// False until the initial state of models is fully loaded. Do not render
  /// warnings until this is true.
  final bool ready;

  /// Handler to change the selected model to [model].
  final VoidCallback selectModel;

  /// Handler to downloaded [model].
  final VoidCallback download;

  /// Handler to delete [model].
  final VoidCallback delete;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: _handleTap,
      child: Card(
        child: ListTile(
          title: Text(
            model.displayName,
            // style: const TextStyle(fontSize: 12),
          ),
          leading: switch (modelInfo.state) {
            ModelState.downloaded =>
              const Icon(Icons.check, color: Colors.green),
            ModelState.downloading => const Icon(Icons.downloading),
            ModelState.empty => SizedBox.fromSize(size: const Size.square(1)),
          },
          subtitle: switch (modelInfo.state) {
            ModelState.downloaded => Text(
                humanize(modelInfo.downloadedBytes!),
                style: TextStyle(fontSize: 11, color: Colors.grey[600]!),
              ),
            ModelState.downloading =>
              _DownloadingBar(downloadPercent: modelInfo.downloadPercent!),
            ModelState.empty => ready && modelInfo.remoteLocation == null
                ? const Text('Configure URL to download',
                    style: TextStyle(color: Colors.red))
                : Container(), // const Icon(Icons.download),
          },
          trailing: GestureDetector(
            onTap: () => _launchModal(context),
            child: switch (modelInfo.state) {
              ModelState.downloaded => const Icon(Icons.delete),
              ModelState.downloading =>
                SizedBox.fromSize(size: const Size.square(1)),
              ModelState.empty => modelInfo.remoteLocation == null
                  ? SizedBox.fromSize(size: const Size.square(1))
                  : const Icon(Icons.download),
            },
          ),
        ),
      ),
    );
  }

  // Responds to taps anywhere on the `ModelSelectionTile` except for the
  // trailing action icon.
  void _handleTap() {
    final VoidCallback? actionHandler = switch (modelInfo.state) {
      ModelState.downloaded => selectModel,
      ModelState.downloading => null,
      ModelState.empty => null,
    };
    actionHandler?.call();
  }

  // Responds to taps on the trailing action icon, which should always either
  // do nothing or launch a modal.
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

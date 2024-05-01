// Copyright 2014 The Flutter Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.
import 'package:example/llm_model.dart';
import 'package:example/model_location_provider.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

class ModelsRow extends StatelessWidget {
  const ModelsRow({super.key, required this.selected});

  final LlmModel selected;

  @override
  Widget build(BuildContext context) {
    return ListView(
      scrollDirection: Axis.horizontal,
      children: <Widget>[
        Padding(
          padding: const EdgeInsets.only(right: 4),
          child: ModelsRowEntry(
            LlmModel.gemma4bCpu,
            isSelected: LlmModel.gemma4bCpu == selected,
          ),
        ),
        Padding(
          padding: const EdgeInsets.only(right: 4),
          child: ModelsRowEntry(
            LlmModel.gemma4bGpu,
            isSelected: LlmModel.gemma4bGpu == selected,
          ),
        ),
        Padding(
          padding: const EdgeInsets.only(right: 4),
          child: ModelsRowEntry(
            LlmModel.gemma8bCpu,
            isSelected: LlmModel.gemma8bCpu == selected,
          ),
        ),
        Padding(
          padding: const EdgeInsets.only(right: 4),
          child: ModelsRowEntry(
            LlmModel.gemma8bGpu,
            isSelected: LlmModel.gemma8bGpu == selected,
          ),
        ),
      ],
    );
  }
}

class ModelsRowEntry extends StatelessWidget {
  const ModelsRowEntry(
    this.model, {
    required this.isSelected,
    super.key,
  });

  final LlmModel model;
  final bool isSelected;

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<ModelLocationProvider>();
    final path = provider.pathFor(model);
    final binarySize = path != null ? provider.binarySize(path) : null;
    final Color borderColor = binarySize != null //
        ? Colors.green
        : Colors.orange;

    return Container(
      height: 100,
      width: 100,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(5),
        border: isSelected //
            ? Border.all(color: borderColor, width: 3)
            : null,
        color: Colors.grey[200],
      ),
      child: Center(
        child: Padding(
          padding: const EdgeInsets.all(8.0),
          child: Text(model.displayName),
        ),
      ),
    );
  }
}

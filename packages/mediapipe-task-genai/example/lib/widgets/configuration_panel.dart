// Copyright 2014 The Flutter Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'package:flutter/material.dart';

/// Contains sliders for each configuration option for option passed to the
/// inference engine.
class InferenceConfigurationPanel extends StatelessWidget {
  const InferenceConfigurationPanel({
    required this.topK,
    required this.temp,
    required this.maxTokens,
    required this.updateTopK,
    required this.updateTemp,
    required this.updateMaxTokens,
    super.key,
  });

  /// Top K number of tokens to be sampled from for each decoding step.
  final int topK;

  /// Handler to update [topK].
  final void Function(int) updateTopK;

  /// Context size window for the LLM.
  final int maxTokens;

  /// Handler to update [maxTokens].
  final void Function(int) updateMaxTokens;

  /// Randomness when decoding the next token.
  final double temp;

  /// Handler to update [temp].
  final void Function(double) updateTemp;

  @override
  Widget build(BuildContext context) {
    return ListView(
      children: <Widget>[
        Text('Top K', style: Theme.of(context).textTheme.bodyLarge),
        Text('Number of tokens to be sampled from for each decoding step.',
            style: Theme.of(context).textTheme.bodySmall),
        Slider(
          value: topK.toDouble(),
          min: 1,
          max: 100,
          divisions: 100,
          onChanged: (newTopK) => updateTopK(newTopK.toInt()),
        ),
        Text(
          topK.toString(),
          style: Theme.of(context)
              .textTheme
              .bodySmall!
              .copyWith(color: Colors.grey),
        ),
        const Divider(),
        Text('Temperature', style: Theme.of(context).textTheme.bodyLarge),
        Text('Randomness when decoding the next token.',
            style: Theme.of(context).textTheme.bodySmall),
        Slider(
          value: temp,
          min: 0,
          max: 1,
          onChanged: updateTemp,
        ),
        Text(
          temp.roundTo(3).toString(),
          style: Theme.of(context)
              .textTheme
              .bodySmall!
              .copyWith(color: Colors.grey),
        ),
        const Divider(),
        Text('Max Tokens', style: Theme.of(context).textTheme.bodyLarge),
        Text(
            'Maximum context window for the LLM. Larger windows can tax '
            'certain devices.',
            style: Theme.of(context).textTheme.bodySmall),
        Slider(
          value: maxTokens.toDouble(),
          min: 512,
          max: 8192,
          onChanged: (newMaxTokens) => updateMaxTokens(newMaxTokens.toInt()),
        ),
        Text(
          maxTokens.toString(),
          style: Theme.of(context)
              .textTheme
              .bodySmall!
              .copyWith(color: Colors.grey),
        ),
        const Divider(),
        GestureDetector(
          onTap: () => Navigator.of(context).pop(),
          child: Text(
            'Close',
            style: Theme.of(context).textTheme.headlineMedium,
          ),
        ),
      ],
    );
  }
}

extension on double {
  double roundTo(int decimalPlaces) =>
      double.parse(toStringAsFixed(decimalPlaces));
}

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
    super.key,
  });

  /// Top K number of tokens to be sampled from for each decoding step.
  final ValueNotifier<int> topK;

  /// Randomness when decoding the next token.
  final ValueNotifier<double> temp;

  @override
  Widget build(BuildContext context) {
    return ListView(
      children: <Widget>[
        Text('Top K', style: Theme.of(context).textTheme.bodyLarge),
        Text('Number of tokens to be sampled from for each decoding step.',
            style: Theme.of(context).textTheme.bodySmall),
        ValueListenableBuilder(
          valueListenable: topK,
          builder: (context, topKValue, child) {
            return Slider(
              value: topKValue.toDouble(),
              min: 1,
              max: 100,
              divisions: 100,
              onChanged: (newTopK) => topK.value = newTopK.toInt(),
            );
          },
        ),
        ValueListenableBuilder(
          valueListenable: topK,
          builder: (context, topKValue, child) {
            return Text(
              topKValue.toString(),
              style: Theme.of(context)
                  .textTheme
                  .bodySmall!
                  .copyWith(color: Colors.grey),
            );
          },
        ),
        const Divider(),
        Text('Temperature', style: Theme.of(context).textTheme.bodyLarge),
        Text('Randomness when decoding the next token.',
            style: Theme.of(context).textTheme.bodySmall),
        ValueListenableBuilder(
          valueListenable: temp,
          builder: (context, temperature, child) {
            return Slider(
              value: temperature,
              min: 0,
              max: 1,
              onChanged: (newtemp) => temp.value = newtemp,
            );
          },
        ),
        ValueListenableBuilder(
          valueListenable: temp,
          builder: (context, temperature, child) {
            return Text(
              temperature.roundTo(3).toString(),
              style: Theme.of(context)
                  .textTheme
                  .bodySmall!
                  .copyWith(color: Colors.grey),
            );
          },
        ),
        const Divider(),
        GestureDetector(
          onTap: () => Navigator.of(context).pop(),
          child: Text('Close', style: Theme.of(context).textTheme.bodySmall),
        ),
      ],
    );
  }
}

extension on double {
  double roundTo(int decimalPlaces) =>
      double.parse(toStringAsFixed(decimalPlaces));
}

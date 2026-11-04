"""Records Google's own answers for the Decision Maker test cases.

Runs Google's Python Decision Maker from the official mediapipe 1.1.0 wheel
over the cases below and writes them with the wheel's and model's digests:

    python -I tool/generate_reference.py <laya_s256.task> <output.json>

The package's tests compare their native answers with this file.
"""

import importlib.metadata
import json
import pathlib
import platform
import sys

from mediapipe.tasks.python.core import base_options as base_options_module
from mediapipe.tasks.python.decision import decision_maker as dm

sys.path.insert(0, str(pathlib.Path(__file__).resolve().parents[2] / 'mediapipe-core/tool'))
from tool_helpers import compact_json, digest  # noqa: E402

TEXTS = [
    'My order arrived broken and I want my money back.',
    'Thanks, everything was perfect and it arrived early.',
    'How do I change the email address on my account?',
]

CASES = [
    ('boolean', 'refund', dm.BooleanQuestion(condition='The customer wants a refund.')),
    ('boolean', 'refund_strict', dm.BooleanQuestion(
        condition='The customer wants a refund.', threshold=0.9)),
    ('boolean', 'question_normalized', dm.BooleanQuestion(
        condition='The text asks a question.', normalize_prior=True)),
    ('choice', 'topic', dm.ChoiceQuestion(criteria={
        'shipping': 'A problem with delivery or a damaged package',
        'billing': 'A question about a charge or a refund',
        'account': 'A question about the account or its settings',
        'other': 'Anything else'})),
    ('choice', 'topic_instructed', dm.ChoiceQuestion(
        criteria={'complaint': 'The customer is unhappy',
                  'praise': 'The customer is happy',
                  'question': 'The customer asks for help'},
        instructions='Classify the customer message.')),
    ('score', 'sentiment', dm.ScoreQuestion(rubric=[
        'very unhappy', 'unhappy', 'neutral', 'happy', 'very happy'])),
    ('score', 'urgency', dm.ScoreQuestion(
        rubric=['not urgent', 'somewhat urgent', 'very urgent'],
        instructions='How urgently does this need a reply?')),
]


def _question(kind, question):
  if kind == 'boolean':
    return {'condition': question.condition, 'threshold': question.threshold,
            'normalizePrior': question.normalize_prior}
  if kind == 'choice':
    return {'criteria': question.criteria,
            'instructions': question.instructions or None}
  return {'rubric': question.rubric,
          'instructions': question.instructions or None}


def _result(kind, result):
  if kind == 'boolean':
    return {'value': result.value, 'probabilityTrue': result.probability_true,
            'confidence': result.confidence}
  if kind == 'choice':
    return {'selectedKey': result.selected_key,
            'probabilities': result.probabilities,
            'confidence': result.confidence,
            'predictionSet': result.prediction_set}
  return {'expectedScore': result.expected_score,
          'probabilities': result.probabilities,
          'confidence': result.confidence, 'selectedKey': result.selected_key}


def main():
  model, output = pathlib.Path(sys.argv[1]), pathlib.Path(sys.argv[2])
  task = dm.DecisionMaker.create_from_options(dm.DecisionMakerOptions(
      base_options=base_options_module.BaseOptions(
          model_asset_path=str(model))))
  library = pathlib.Path(dm.__file__).parents[2] / 'c'
  library = next(library.glob('libmediapipe.*'))
  cases = []
  for kind, name, question in CASES:
    single = getattr(task, f'evaluate_{kind}')
    batch = getattr(task, f'evaluate_{kind}_batch')
    cases.append({
        'name': name,
        'kind': kind,
        'question': _question(kind, question),
        'texts': TEXTS,
        'results': [_result(kind, single(text, question)) for text in TEXTS],
        'batch': [_result(kind, r) for r in batch(TEXTS, question)],
    })
  reference = {
      'mediapipe': importlib.metadata.version('mediapipe'),
      'platform': f'{platform.system().lower()}/{platform.machine().lower()}',
      'library': library.name,
      'librarySha256': digest(library),
      'model': model.name,
      'modelSha256': digest(model),
      'cases': cases,
  }
  output.parent.mkdir(parents=True, exist_ok=True)
  output.write_text(compact_json(reference) + '\n')


if __name__ == '__main__':
  main()

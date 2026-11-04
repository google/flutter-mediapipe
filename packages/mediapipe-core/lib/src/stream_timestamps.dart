/// The timestamp rule every family's streaming modes share: vision's video
/// and live stream modes and audio's stream mode check the same way on every
/// platform, before Google's runtime sees the timestamp.
library;

/// The largest timestamp any platform accepts for a frame or an audio block:
/// JavaScript's exact integer range in milliseconds (about 285 years), which
/// native runtimes exceed, so one limit keeps the same input valid
/// everywhere.
const maxStreamTimestampMilliseconds = 9007199254740;

/// Throws [ArgumentError] unless [timestampMilliseconds] is nonnegative, at
/// most [maxStreamTimestampMilliseconds] and above [previous], the last
/// timestamp the task accepted (null before the first): Google's runtimes
/// refuse a timestamp that does not increase.
void checkStreamTimestamp(int timestampMilliseconds, int? previous) {
  if (timestampMilliseconds < 0 ||
      timestampMilliseconds > maxStreamTimestampMilliseconds ||
      (previous != null && timestampMilliseconds <= previous)) {
    throw ArgumentError.value(
      timestampMilliseconds,
      'timestampMilliseconds',
      'Must be nonnegative, strictly increasing and at most '
          '$maxStreamTimestampMilliseconds',
    );
  }
}

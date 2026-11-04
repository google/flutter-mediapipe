/// The timestamp Google's audio stream gives the tail its close flushes:
/// `Timestamp::Max()` in microseconds, divided by 1000 as every native SDK
/// divides it (upstream-issues.md UP-037). Browsers never receive
/// it, since Google has no stream there, and cannot hold it exactly.
const googleTailTimestamp = 9223372036854775;

/// A platform without `dart:ffi` is not iOS, so there is no backup to
/// exclude [path] from. Never called: only iOS excludes its models.
void excludeFromBackup(String path) {}

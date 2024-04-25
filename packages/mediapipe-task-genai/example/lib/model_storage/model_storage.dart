export 'model_storage_interface.dart';

export 'universal_model_storage.dart'
    if (dart.library.html) 'web_model_storage.dart'
    if (dart.library.io) 'io_model_storage.dart';

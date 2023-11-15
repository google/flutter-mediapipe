function ci_package () {
    local channel="$1"

    shift
    local arr=("$@")
    for PACKAGE_NAME in "${arr[@]}"
    do
        echo "== Testing '${PACKAGE_NAME}' on Flutter's $channel channel =="
        pushd "packages/${PACKAGE_NAME}"

        # Grab packages.
        flutter pub get

        # Run the analyzer to find any static analysis issues.
        dart analyze --fatal-infos

        # Run the formatter on all the dart files to make sure everything's linted.
        dart format --output none --set-exit-if-changed .

        # Download bert_classifier.tflite model into example/assets for integration tests
        echo "Downloading TextClassification model"
        pushd ../../tool/builder
        dart pub get
        dart bin/main.dart model -m textclassification
        popd

        # Run the actual tests.
        if [ -d "test" ]
        then
            flutter test
        fi

        popd
    done
}

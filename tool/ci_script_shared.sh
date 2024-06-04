function ci_text_package() {
    # Download bert_classifier.tflite model into example/assets for integration tests
    pushd ../../tool/builder
    dart pub get
    echo "Downloading TextClassification model"
    dart bin/main.dart model -m textclassification
    echo "Downloading TextEmbedding model"
    dart bin/main.dart model -m textembedding
    echo "Downloading Language Detection model"
    dart bin/main.dart model -m languagedetection
    popd
}

function ci_package () {
    local channel="$1"

    shift
    local arr=("$@")
    for PACKAGE_NAME in "${arr[@]}"
    do
        echo "== Testing '${PACKAGE_NAME}' on Flutter's $channel channel =="
        pushd "packages/${PACKAGE_NAME}"

        if [[ $PACKAGE_NAME == "mediapipe-task-text" ]]; then
            ci_text_package
        fi

        # Grab packages.
        flutter pub get

        # Run the analyzer to find any static analysis issues.
        dart analyze --fatal-infos

        # Run the formatter on all the dart files to make sure everything's linted.
        dart format --output none --set-exit-if-changed .
        
        # Turn on the native-assets feature required by flutter-mediapipe
        flutter config --enable-native-assets

        # Run the actual tests if they exist.
        if [ -d "test" ]
        then
            dart --enable-experiment=native-assets test
        fi

        # Run any example tests if they exist
        if [ -d "example/test" ]
        then
            echo "Analyzing '${PACKAGE_NAME}/example'"
            
            pushd "example"

            flutter pub get

            # Run the analyzer to find any static analysis issues.
            dart analyze --fatal-infos

            # Run the formatter on all the dart files to make sure everything's linted.
            dart format --output none --set-exit-if-changed .

            flutter test

            popd
        fi

        popd
    done
}

function ci_text_package() {
    # Download bert_classifier.tflite model into example/assets for integration tests
    echo "Downloading TextClassification model"
    pushd ../../tool/builder
    dart pub get
    dart bin/main.dart model -m textclassification
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
            flutter test
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


        pushd /Users/runner/work/flutter-mediapipe/flutter-mediapipe/packages/mediapipe-task-text/build/native_assets/macos/
        echo `pwd`
        ls -lah
        popd
        
        pushd /Users/runner/work/flutter-mediapipe/flutter-mediapipe/packages/mediapipe-task-text/example/build/
        echo 'dry-run'
        cat dryrun-build-log.txt
        echo 'live-run'
        cat live-run-build-log.txt
        popd
        
        pushd /Users/runner/work/flutter-mediapipe/flutter-mediapipe/packages/mediapipe-task-text/example/.dart_tool/native_assets_builder/e3c4d6cb53c6119f2a9c03f0f880d05f/out
        echo `pwd`
        ls -lah
        echo 'build_output.yaml'
        cat build_output.yaml
        popd

        pushd /Users/runner/work/flutter-mediapipe/flutter-mediapipe/packages/mediapipe-task-text/build/native_assets/macos
        echo `pwd`
        ls -lah
        echo 'native-assets.yaml'
        cat native-assets.yaml
        popd


    done
}

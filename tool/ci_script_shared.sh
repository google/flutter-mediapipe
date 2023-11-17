function ci_text_package() {
    # Download bert_classifier.tflite model into example/assets for integration tests
    echo "Downloading TextClassification model"
    pushd ../../tool/builder
    dart pub get
    dart bin/main.dart model -m textclassification
    popd

    echo `pwd`
    ls -lah
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
        
        flutter config --enable-native-assets

        echo "$ flutter config --list 1"
        flutter config --list

        flutter doctor -v

        echo "$ flutter config --list 2"
        flutter config --list

        # Run the actual tests.
        if [ -d "test" ]
        then
            flutter test
            echo `pwd`
            ls -lah
            ls -lah build/
            ls -lah build/unit_test_assets
            echo "$ flutter config --list 3"
            flutter config --list
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

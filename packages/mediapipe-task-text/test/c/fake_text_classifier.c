#include <stdio.h>
#include <stdlib.h>
#include <string.h>

#include "../../third_party/mediapipe/tasks/c/text/text_classifier/text_classifier.h"
#include "../../../mediapipe-core/third_party/mediapipe/tasks/c/components/containers/category.h"

struct TextClassifier {
    struct TextClassifierOptions options;
};

struct TextClassifierOptions* allocate_text_classifier_options() {
    struct TextClassifierOptions* options = calloc(1, sizeof(struct TextClassifierOptions*));
    struct BaseOptions* _base_options = calloc(1, sizeof(struct BaseOptions));
    struct ClassifierOptions* _classifier_options = calloc(1, sizeof(struct ClassifierOptions));

    options->base_options = *_base_options;
    options->classifier_options = *_classifier_options;
    return options;
}

void* text_classifier_create(struct TextClassifierOptions* options) {
    struct TextClassifier* classifier = calloc(1, sizeof(struct TextClassifier*));
    classifier->options = *options;
    return classifier;
}

int text_classifier_classify(void* classifier, char* utf8_text, TextClassifierResult* results) {

    char* text_copy = strdup(utf8_text);

    struct Category* categories = calloc(2, sizeof(struct Category));
    categories[0].index = 0;
    categories[0].score = 0.9;
    categories[0].category_name = text_copy;
    categories[0].display_name = text_copy;

    categories[1].index = 1;
    categories[1].score = 0.7;
    categories[1].category_name = text_copy;
    categories[1].display_name = text_copy;

    struct Classifications* classification = calloc(1, sizeof(struct Classifications));
    classification->categories = categories;
    classification->categories_count = 2;
    classification->head_index = 1;
    classification->head_name = "Whatever";

    results->classifications = classification;
    results->classifications_count = 1;
    results->timestamp_ms = 300;
    results->has_timestamp_ms = true;

    return 1;
}

void text_classifier_close(void* classifier) {
    struct TextClassifier* cls = (struct TextClassifier*)classifier;
    free(cls);
}

void text_classifier_result_close(TextClassifierResult* result) {
    // TODO: imagine this
}


int main() { return 0; }

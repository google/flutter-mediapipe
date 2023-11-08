#include <stdio.h>
#include <stdlib.h>
#include <string.h>

#include "../../third_party/mediapipe/tasks/c/text/text_classifier/text_classifier.h"
#include "../../../mediapipe-core/third_party/mediapipe/tasks/c/components/containers/category.h"

struct TextClassifier {
    struct TextClassifierOptions options;
};

void* text_classifier_create(struct TextClassifierOptions* options,
    char** error_msg) {
    struct TextClassifier* classifier = calloc(1, sizeof(struct TextClassifier*));
    classifier->options = *options;
    return classifier;
}

int text_classifier_classify(void* classifier, const char* utf8_str,
    TextClassifierResult* result,
    char** error_msg) {

    char* text_copy = strdup(utf8_str);

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

    result->classifications = classification;
    result->classifications_count = 1;
    result->timestamp_ms = 300;
    result->has_timestamp_ms = true;

    return 1;
}

int text_classifier_close(void* classifier,
    char** error_msg) {
    struct TextClassifier* cls = (struct TextClassifier*)classifier;
    free(cls);
    return 0;
}

void text_classifier_result_close(TextClassifierResult* result) {
    // TODO: imagine this
}


int main() { return 0; }
#include "bridge.h"
#ifdef __ANDROID__
#include <jni.h>
#include <stdlib.h>
// Transport is UTF-8 byte arrays: JNI modified UTF-8 must never corrupt emoji,
// embedded NUL, non-BMP text or clinical units on the Swift/Java boundary.
JNIEXPORT jbyteArray JNICALL Java_com_vetpilot_android_NativeCore_dispatchBytes(JNIEnv *env, jclass klass, jbyteArray input) {
    jsize count = (*env)->GetArrayLength(env, input);
    if (count > 20000000) return NULL;
    char *request = calloc((size_t)count + 1, 1);
    if (!request) return NULL;
    (*env)->GetByteArrayRegion(env, input, 0, count, (jbyte *)request);
    if ((*env)->ExceptionCheck(env)) { free(request); return NULL; }
    char *response = vetpilot_dispatch(request);
    free(request);
    if (!response) return NULL;
    size_t n = 0; while (response[n]) ++n;
    jbyteArray result = (*env)->NewByteArray(env, (jsize)n);
    if (result) (*env)->SetByteArrayRegion(env, result, 0, (jsize)n, (jbyte *)response);
    vetpilot_free(response);
    return result;
}
#endif

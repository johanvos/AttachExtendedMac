/*
 * Copyright (c) 2022, Gluon
 *
 * This program is free software: you can redistribute it and/or modify
 * it under the terms of the GNU General Public License as published by
 * the Free Software Foundation, either version 3 of the License, or
 * (at your option) any later version.

 * This program is distributed in the hope that it will be useful,
 * but WITHOUT ANY WARRANTY; without even the implied warranty of
 * MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
 * GNU General Public License for more details.
 *
 * You should have received a copy of the GNU General Public License
 * along with this program.  If not, see <http://www.gnu.org/licenses/>.
 *
 * THIS SOFTWARE IS PROVIDED BY THE COPYRIGHT HOLDERS AND CONTRIBUTORS "AS IS" AND
 * ANY EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED TO, THE IMPLIED
 * WARRANTIES OF MERCHANTABILITY AND FITNESS FOR A PARTICULAR PURPOSE ARE
 * DISCLAIMED. IN NO EVENT SHALL GLUON BE LIABLE FOR ANY
 * DIRECT, INDIRECT, INCIDENTAL, SPECIAL, EXEMPLARY, OR CONSEQUENTIAL DAMAGES
 * (INCLUDING, BUT NOT LIMITED TO, PROCUREMENT OF SUBSTITUTE GOODS OR SERVICES;
 * LOSS OF USE, DATA, OR PROFITS; OR BUSINESS INTERRUPTION) HOWEVER CAUSED AND
 * ON ANY THEORY OF LIABILITY, WHETHER IN CONTRACT, STRICT LIABILITY, OR TORT
 * (INCLUDING NEGLIGENCE OR OTHERWISE) ARISING IN ANY WAY OUT OF THE USE OF THIS
 * SOFTWARE, EVEN IF ADVISED OF THE POSSIBILITY OF SUCH DAMAGE.
 */

#include "CaptureVideo.h"

JNIEnv *jEnv = NULL;

#ifdef STATIC_BUILD
JNIEXPORT jint JNICALL JNI_OnLoad_CaptureVideo(JavaVM *vm, void *reserved)
#else
JNIEXPORT jint JNICALL JNI_OnLoad(JavaVM *vm, void *reserved)
#endif
{
    //min. returned JNI_VERSION required by JDK8 for builtin libraries
    if ((*vm)->GetEnv(vm, (void **)&jEnv, JNI_VERSION_1_8) != JNI_OK) {
        return JNI_VERSION_1_4;
    }
    return JNI_VERSION_1_8;
}

static int captureInited = 0;

// Capture Video
jclass mat_jCaptureVideoServiceClass;
jmethodID mat_jCaptureVideoService_setResult = 0;
CaptureVideo *_captureVideo;

JNIEXPORT void JNICALL Java_com_gluonhq_attachextendedmac_capturevideo_impl_DesktopCaptureVideoService_initCaptureVideo
(JNIEnv *env, jclass jClass)
{
    if (captureInited)
    {
        return;
    }

    NSString *bundleIdentifier = [[NSBundle mainBundle] bundleIdentifier];
    if ([bundleIdentifier isEqualToString:@"net.java.openjdk.java"]) {
        AttachLog(@"Warning: bundleIdentifier is %@: it doesn't support Capture Video. Use jpackage to create an app", bundleIdentifier);
        return;
    }

    captureInited = 1;

    mat_jCaptureVideoServiceClass = (*env)->NewGlobalRef(env, (*env)->FindClass(env, "com/gluonhq/attachextendedmac/capturevideo/impl/DesktopCaptureVideoService"));
    mat_jCaptureVideoService_setResult = (*env)->GetStaticMethodID(env, mat_jCaptureVideoServiceClass, "setResult", "(III[B)V");
}

JNIEXPORT void JNICALL Java_com_gluonhq_attachextendedmac_capturevideo_impl_DesktopCaptureVideoService_nativeStart
(JNIEnv *env, jclass jClass)
{
    if (!captureInited) {
        AttachLog(@"Warning: Capture Video not supported. Use jpackage to create an app");
        return;
    }
    AttachLog(@"Capture video start");
    _captureVideo = [[CaptureVideo alloc] init];
    [_captureVideo startSession];

}

JNIEXPORT void JNICALL Java_com_gluonhq_attachextendedmac_capturevideo_impl_DesktopCaptureVideoService_nativeStop
(JNIEnv *env, jclass jClass)
{
    if (!captureInited) {
        AttachLog(@"Warning: Capture Video not supported. Use jpackage to create an app");
        return;
    }
    AttachLog(@"Capture video stop");
    if (_captureVideo) {
        [_captureVideo stopSession];
    }
}

void sendPicturesResult(int width, int height, uint8_t* data, size_t len) {
    JNIEnv *env = jEnv;
    jbyteArray picByteArray = (*env)->NewByteArray(env, len);
    (*env)->SetByteArrayRegion(env, picByteArray, 0, len, data);
    if ((*env)->ExceptionCheck(env)) {
        (*env)->ExceptionDescribe(env);
        (*env)->ExceptionClear(env);
        return;
    }
    (*env)->CallStaticVoidMethod(env, mat_jCaptureVideoServiceClass, mat_jCaptureVideoService_setResult, width, height, 0, picByteArray);
    (*env)->DeleteLocalRef(env, picByteArray);
}

@implementation CaptureVideo

- (void) loadView {
    // prevents runtime error: "could not load the nibName:"
}

AVCaptureSession *_session;
AVCaptureDevice *_device;
AVCaptureDeviceInput *_input;
AVCaptureVideoDataOutput *_output;

 - (void) startSession
 {
     _session = [[AVCaptureSession alloc] init];
     _session.sessionPreset = AVCaptureSessionPreset320x240;
     _device = [AVCaptureDevice defaultDeviceWithMediaType:AVMediaTypeVideo];
     NSError *error = nil;

     _input = [AVCaptureDeviceInput deviceInputWithDevice:_device error:&error];
     if (_input) {
        AttachLog(@"Add _input: %@", _input);
         [_session addInput:_input];
     } else {
         AttachLog(@"Error _input: %@", error);
     }

     _output = [[AVCaptureVideoDataOutput alloc] init];
     if (_output) {
        NSString* key = (NSString*)kCVPixelBufferPixelFormatTypeKey;
        NSNumber* val = [NSNumber numberWithUnsignedInt:kCVPixelFormatType_32BGRA];
        // NSNumber* val = [NSNumber numberWithUnsignedInt:kCVPixelFormatType_420YpCbCr8BiPlanarFullRange];
        NSDictionary* videoSettings = [NSDictionary dictionaryWithObject:val forKey:key];
        _output.videoSettings = videoSettings;
        _output.alwaysDiscardsLateVideoFrames = true;
        dispatch_queue_t queue = dispatch_queue_create("myQueue", NULL);
        [_output setSampleBufferDelegate:self queue:queue];
        dispatch_release(queue);
        AttachLog(@"Add _output: %@", _output);
        [_session addOutput:_output];
     } else {
        AttachLog(@"Error _output: %@", error);
     }

     AttachLog(@"startRunning: %@", _session);
     [_session startRunning];
 }

- (void) stopSession
{
    AttachLog(@"stopSession: %@", _session);
    if([_session isRunning])
    {
        [_session stopRunning];
    }
    [_session removeInput:_input];
    [_session removeOutput:_output];
    _session = nil;
}

- (void)captureOutput:(AVCaptureOutput *)output didOutputSampleBuffer:(CMSampleBufferRef)sampleBuffer
       fromConnection:(AVCaptureConnection *)connection
{
    NSAutoreleasePool *pool = [[NSAutoreleasePool alloc] init];
    {
        CVImageBufferRef imageBuffer = CMSampleBufferGetImageBuffer(sampleBuffer);
        if (imageBuffer != NULL) {
            CVPixelBufferLockBaseAddress(imageBuffer, 0);
            uint8_t* data = CVPixelBufferGetBaseAddress(imageBuffer);
            size_t width = CVPixelBufferGetWidth(imageBuffer);
            size_t height = CVPixelBufferGetHeight(imageBuffer);
            size_t length = CVPixelBufferGetDataSize(imageBuffer);
            uint8_t* rdata = malloc(length);
            memcpy(rdata, data, length);
            size_t bytesPerRow = CVPixelBufferGetBytesPerRow(imageBuffer);
            size_t pixelFormat = CVPixelBufferGetPixelFormatType(imageBuffer); // kCVPixelFormatType_422YpCbCr8
            CVPixelBufferUnlockBaseAddress(imageBuffer, 0);
            dispatch_async(dispatch_get_main_queue(), ^{
                sendPicturesResult(width, height, rdata, length);
                free(rdata);
            });
       }
    }
    [pool drain];
    pool=nil;
}

- (void) logMessage:(NSString *)format, ...;
{
//     if (debugAttach)
//     {
        va_list args;
        va_start(args, format);
        NSLogv([@"[Debug] " stringByAppendingString:format], args);
        va_end(args);
//     }
}
@end 


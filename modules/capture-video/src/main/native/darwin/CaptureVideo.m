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
    mat_jCaptureVideoService_setResult = (*env)->GetStaticMethodID(env, mat_jCaptureVideoServiceClass, "setResult", "(Ljava/lang/String;)V");
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

void sendPicturesResult(NSString *picResult) {
    JNIEnv *env = jEnv;
    if (picResult)
    {
        const char *picChars = [picResult UTF8String];
        jstring jpic = (*env)->NewStringUTF(env, picChars);
        (*env)->CallStaticVoidMethod(env, mat_jCaptureVideoServiceClass, mat_jCaptureVideoService_setResult, jpic);
        (*env)->DeleteLocalRef(env, jpic);
//         AttachLog(@"Finished sending picture");
    } else
    {
        (*env)->CallStaticVoidMethod(env, mat_jCaptureVideoServiceClass, mat_jCaptureVideoService_setResult, NULL);
    }
}

@interface NSImage (data)
- (NSData *)toNSData;
@end

@implementation NSImage (data)

- (NSData *)toNSData
{
    NSBitmapImageRep *bmprep = [self bitmapImageRepresentation];
    return [bmprep representationUsingType:NSBitmapImageFileTypePNG properties:@{NSImageCompressionFactor: @(0.0)}];
}

- (NSBitmapImageRep *)bitmapImageRepresentation {
    int width = [self size].width;
    int height = [self size].height;

    if(width < 1 || height < 1)
        return nil;

    NSBitmapImageRep *rep = [[NSBitmapImageRep alloc]
                             initWithBitmapDataPlanes: NULL
                             pixelsWide: width
                             pixelsHigh: height
                             bitsPerSample: 8
                             samplesPerPixel: 4
                             hasAlpha: YES
                             isPlanar: NO
                             colorSpaceName: NSDeviceRGBColorSpace
                             bytesPerRow: width * 4
                             bitsPerPixel: 32];

    NSGraphicsContext *ctx = [NSGraphicsContext graphicsContextWithBitmapImageRep: rep];
    [NSGraphicsContext saveGraphicsState];
    [NSGraphicsContext setCurrentContext: ctx];
    [self drawAtPoint: NSZeroPoint fromRect: NSZeroRect operation: NSCompositingOperationCopy fraction: 1.0];
    [ctx flushGraphics];
    [NSGraphicsContext restoreGraphicsState];

    return rep;
}

@end

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
//      _session.sessionPreset = AVCaptureSessionPresetMedium;
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
//        NSLog(@"Handle frame %@", sampleBuffer);
       NSImage *image = [self screenshotOfVideoStream:sampleBuffer];
       NSData *imageData = [image toNSData];
       NSString *base64StringOfImage = [imageData base64EncodedStringWithOptions:NSDataBase64Encoding64CharacterLineLength];
       dispatch_async(dispatch_get_main_queue(), ^{
            sendPicturesResult(base64StringOfImage);
       });
    }
    [pool drain];
    pool=nil;
}

- (NSImage *)screenshotOfVideoStream:(CMSampleBufferRef)samImageBuff
{
    NSImage *image;
    NSAutoreleasePool *pool = [[NSAutoreleasePool alloc] init];
    {
        CVImageBufferRef imageBuffer = CMSampleBufferGetImageBuffer(samImageBuff);
        CIImage *ciImage = [CIImage imageWithCVPixelBuffer:imageBuffer];
        CIContext *temporaryContext = [CIContext contextWithOptions:nil];
        CGImageRef videoImage = [temporaryContext
                         createCGImage:ciImage
                         fromRect:CGRectMake(0, 0,
                         CVPixelBufferGetWidth(imageBuffer),
                         CVPixelBufferGetHeight(imageBuffer))];

        image = [[NSImage alloc] initWithCGImage:videoImage size:NSMakeSize(CVPixelBufferGetWidth(imageBuffer), CVPixelBufferGetHeight(imageBuffer))];
        CGImageRelease(videoImage);
    }
    [pool drain];
    pool=nil;
    return image;
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

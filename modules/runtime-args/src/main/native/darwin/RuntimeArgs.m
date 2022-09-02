/*
 * Copyright (c) 2016, 2022, Gluon
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

#include "RuntimeArgs.h"

JNIEnv *jEnv = NULL;


#ifdef STATIC_BUILD
jint JNICALL JNI_OnLoad_RuntimeArgs(JavaVM *vm, void *reserved)
#else
jint JNICALL JNI_OnLoad(JavaVM *vm, void *reserved)
#endif
{
    //min. returned JNI_VERSION required by JDK8 for builtin libraries
    if ((*vm)->GetEnv(vm, (void **)&jEnv, JNI_VERSION_1_8) != JNI_OK) {
        return JNI_VERSION_1_4;
    }
    return JNI_VERSION_1_8;
}

static int runtimeArgsInited = 0;

jclass mat_jRuntimeArgsClass;
jmethodID mat_jProcessRuntimeArgsMethod = 0;
RasDelegate *_rasDelegate;

JNIEXPORT void JNICALL Java_com_gluonhq_attachextendedmac_runtimeargs_impl_DesktopRuntimeArgsService_initRuntimeArgs
(JNIEnv *env, jclass jClass)
{
    if (runtimeArgsInited)
    {
        return;
    }
    NSString *bundleIdentifier = [[NSBundle mainBundle] bundleIdentifier];
    if ([bundleIdentifier isEqualToString:@"net.java.openjdk.java"]) {
        AttachLog(@"Warning: bundleIdentifier is %@: it doesn't support Runtime Args. Use jpackage to create an app", bundleIdentifier);
        return;
    }

    runtimeArgsInited = 1;

    mat_jRuntimeArgsClass = (*env)->NewGlobalRef(env, (*env)->FindClass(env, "com/gluonhq/attachextendedmac/runtimeargs/impl/DesktopRuntimeArgsService"));
    mat_jProcessRuntimeArgsMethod = (*env)->GetStaticMethodID(env, mat_jRuntimeArgsClass, "processRuntimeArgs", "(Ljava/lang/String;Ljava/lang/String;)V");

    _rasDelegate = [[RasDelegate alloc] init];
    [_rasDelegate register];
}

void processRuntimeArgs(NSString* key, NSString* value) {
    JNIEnv *env = jEnv;
    const char *keyChars = [key UTF8String];
    jstring jkey = (*env)->NewStringUTF(env, keyChars);
    const char *valueChars = [value UTF8String];
    jstring jvalue = (*env)->NewStringUTF(env, valueChars);
    (*env)->CallStaticVoidMethod(env, mat_jRuntimeArgsClass, mat_jProcessRuntimeArgsMethod, jkey, jvalue);
    (*env)->DeleteLocalRef(env, jkey);
    (*env)->DeleteLocalRef(env, jvalue);
}

// Remote Notifications macOS

@implementation RasDelegate

- (void)register
{
//        processRuntimeArgs(@"Launch.LocalNotification", @"test myId");
    UNUserNotificationCenter *center = [UNUserNotificationCenter currentNotificationCenter];
    center.delegate = self;
}

-(void)userNotificationCenter:(UNUserNotificationCenter *)center willPresentNotification:(UNNotification *)notification withCompletionHandler:(void (^)(UNNotificationPresentationOptions options))completionHandler{

    //When a notification is delivered to a foreground app, this will show it on top:
    completionHandler(UNNotificationPresentationOptionList + UNNotificationPresentationOptionBanner + UNNotificationPresentationOptionSound);
}

-(void)userNotificationCenter:(UNUserNotificationCenter *)center didReceiveNotificationResponse:(UNNotificationResponse *)response withCompletionHandler:(void(^)())completionHandler{

    //Called when a notification is delivered to foreground or background app.
    AttachLog(@"Received remote notification: Userinfo %@",response.notification.request.content.userInfo);
    NSAutoreleasePool *pool = [[NSAutoreleasePool alloc] init];
    {
        NSError *err;
        NSData *jsonData = [NSJSONSerialization dataWithJSONObject:response.notification.request.content.userInfo options:0 error: &err];
        if ([response.notification.request.trigger isKindOfClass:[UNPushNotificationTrigger class]]) {
            AttachLog(@"Handling Push notification");
            NSString *jsonString = [[NSString alloc] initWithData:jsonData encoding:NSUTF8StringEncoding];
            processRuntimeArgs(@"Launch.PushNotification", jsonString);
        } else {
            AttachLog(@"Handling Local notification");
            NSDictionary *myUserInfo = [NSJSONSerialization JSONObjectWithData:jsonData options:NSJSONReadingMutableContainers error:&err];
            NSString *myId = [myUserInfo objectForKey:@"userId"];
            AttachLog(@"Sending local notification with id %@", myId);
            processRuntimeArgs(@"Launch.LocalNotification", myId);
        }
    }
    [pool drain];
    completionHandler();
}

@end

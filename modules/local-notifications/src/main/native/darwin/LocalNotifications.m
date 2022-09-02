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

#include "LocalNotifications.h"

JNIEnv *jEnv = NULL;

#ifdef STATIC_BUILD
JNIEXPORT jint JNICALL JNI_OnLoad_LocalNotifications(JavaVM *vm, void *reserved)
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

static int notificationsInited = 0;

// Notifications

JNIEXPORT void JNICALL Java_com_gluonhq_attachextendedmac_localnotifications_impl_DesktopLocalNotificationsService_initLocalNotification
(JNIEnv *env, jclass jClass)
{
    if (notificationsInited)
    {
        return;
    }

    NSString *bundleIdentifier = [[NSBundle mainBundle] bundleIdentifier];
    if ([bundleIdentifier isEqualToString:@"net.java.openjdk.java"]) {
        AttachLog(@"Warning: bundleIdentifier is %@: it doesn't support Local Notifications. Use jpackage to create an app", bundleIdentifier);
        return;
    }

    notificationsInited = 1;

    if (@available(macOS 10.14, *))
    {
        AttachLog(@"Initialize UNUserNotificationCenter macOS");
        UNUserNotificationCenter *center = [UNUserNotificationCenter currentNotificationCenter];
        UNAuthorizationOptions options = UNAuthorizationOptionAlert + UNAuthorizationOptionBadge + UNAuthorizationOptionSound;
        [center requestAuthorizationWithOptions:options completionHandler:^(BOOL granted, NSError * _Nullable error) {
            if (!granted) {
                AttachLog(@"Error granting notification options %@", error);
            }
        }];

        [center getNotificationSettingsWithCompletionHandler:^(UNNotificationSettings *settings) {
            // Authorization status of the UNNotificationSettings object
            switch (settings.authorizationStatus) {
            case UNAuthorizationStatusAuthorized:
                AttachLog(@"UNNotificationSettings Status Authorized");
                break;
            case UNAuthorizationStatusDenied:
                AttachLog(@"UNNotificationSettings Status Denied");
                break;
            case UNAuthorizationStatusNotDetermined:
                AttachLog(@"UNNotificationSettings Status Undetermined");
                break;
            default:
                break;
            }

            // Status of specific settings
            if (settings.alertSetting != UNAuthorizationStatusAuthorized) {
                AttachLog(@"Alert settings not authorized");
            }

            if (settings.badgeSetting != UNAuthorizationStatusAuthorized) {
                AttachLog(@"Badge settings not authorized");
            }

            if (settings.soundSetting != UNAuthorizationStatusAuthorized) {
                AttachLog(@"Sound settings not authorized");
            }
        }];
    }
    
}

JNIEXPORT void JNICALL Java_com_gluonhq_attachextendedmac_localnotifications_impl_DesktopLocalNotificationsService_registerNotification
(JNIEnv *env, jobject obj, jstring jTitle, jstring jText, jstring jIdentifier, jdouble seconds)
{
    if (!notificationsInited) {
        AttachLog(@"Warning: Local Notifications not supported. Use jpackage to create an app");
        return;
    }
    AttachLog(@"Register notification");
    const jchar *charsTitle = (*env)->GetStringChars(env, jTitle, NULL);
    NSString *name = [NSString stringWithCharacters:(UniChar *)charsTitle length:(*env)->GetStringLength(env, jTitle)];
    (*env)->ReleaseStringChars(env, jTitle, charsTitle);
    const jchar *charsText = (*env)->GetStringChars(env, jText, NULL);
    NSString *text = [NSString stringWithCharacters:(UniChar *)charsText length:(*env)->GetStringLength(env, jText)];
    (*env)->ReleaseStringChars(env, jText, charsText);
    const jchar *charsIdentifier = (*env)->GetStringChars(env, jIdentifier, NULL);
    NSString *identifier = [NSString stringWithCharacters:(UniChar *)charsIdentifier length:(*env)->GetStringLength(env, jIdentifier)];
    (*env)->ReleaseStringChars(env, jIdentifier, charsIdentifier);

    if (@available(macOS 10.14, *))
    {
        UNMutableNotificationContent *content = [UNMutableNotificationContent new];
        content.title = name;
        content.body = text;
        content.sound = [UNNotificationSound defaultSound];
//         content.badge = @1;
        content.userInfo = [NSDictionary dictionaryWithObjectsAndKeys:identifier, @"userId", nil];

        NSString *documentsDir = NSSearchPathForDirectoriesInDomains(NSLibraryDirectory, NSUserDomainMask, YES)[0];
        NSString *imagePath = [documentsDir stringByAppendingPathComponent:@"gluon/assets/notificationImage.png"];

        if ([[NSFileManager defaultManager] fileExistsAtPath:imagePath]) {
            AttachLog(@"Image from resources %@", imagePath);
            NSURL *imageURL = [[NSURL alloc] initFileURLWithPath:imagePath];
            NSError *error = nil;
            UNNotificationAttachment *icon = [UNNotificationAttachment attachmentWithIdentifier:@"Image" URL:imageURL options:nil error:&error];
            if (error)
            {
                AttachLog(@"Error creating image attachment: %@", error);
            }
            if (icon)
            {
                content.attachments = @[icon];
            }
        }

        NSDate *date = [NSDate dateWithTimeIntervalSince1970:seconds];
        NSDateComponents *triggerDate = [[NSCalendar currentCalendar]
                      components:NSCalendarUnitYear +
                      NSCalendarUnitMonth + NSCalendarUnitDay +
                      NSCalendarUnitHour + NSCalendarUnitMinute +
                      NSCalendarUnitSecond fromDate:date];
        UNCalendarNotificationTrigger *trigger = [UNCalendarNotificationTrigger triggerWithDateMatchingComponents:triggerDate
                                                 repeats:NO];
        UNNotificationRequest *request = [UNNotificationRequest requestWithIdentifier:identifier
                                           content:content trigger:trigger];

        UNUserNotificationCenter *center = [UNUserNotificationCenter currentNotificationCenter];
        [center addNotificationRequest:request withCompletionHandler:^(NSError * _Nullable error) {
             if (error != nil) {
                 AttachLog(@"Something went wrong scheduling local notification: %@",error);
             } else
             {
                 AttachLog(@"done register notifications for %@ with identifier %@", name, identifier);
             }
        }];
    }
    return;
}

JNIEXPORT void JNICALL Java_com_gluonhq_attachextendedmac_localnotifications_impl_DesktopLocalNotificationsService_unregisterNotification
(JNIEnv *env, jclass jClass, jstring jIdentifier)
{
    if (!notificationsInited) {
        AttachLog(@"Warning: Local Notifications not supported. Use jpackage to create an app");
        return;
    }

    const jchar *charsIdentifier = (*env)->GetStringChars(env, jIdentifier, NULL);
    NSString *identifier = [NSString stringWithCharacters:(UniChar *)charsIdentifier length:(*env)->GetStringLength(env, jIdentifier)];
    (*env)->ReleaseStringChars(env, jIdentifier, charsIdentifier);

    if (@available(macOS 10.14, *))
    {
        UNUserNotificationCenter *center = [UNUserNotificationCenter currentNotificationCenter];
        NSArray *array = [NSArray arrayWithObjects:identifier, nil];
        [center removePendingNotificationRequestsWithIdentifiers:array];
        AttachLog(@"We did remove the notification with id: %@", identifier);
    } else {
        AttachLog(@"Warning: Local Notifications not supported. Use jpackage to create an app");
    }
}

@implementation LocalNotifications

- (void)userNotificationCenter:(UNUserNotificationCenter *)center didReceiveNotificationResponse:(UNNotificationResponse *)response withCompletionHandler:(void (^)(void))completionHandler
{
    // called when a user selects an action in a delivered notification
    [self logMessage:@"didReceiveNotificationResponse %@", response];
    completionHandler();
}

- (void)userNotificationCenter:(UNUserNotificationCenter *)center willPresentNotification:(UNNotification *)notification withCompletionHandler:(void (^)(UNNotificationPresentationOptions options))completionHandler
{
   // called when a notification is delivered to a foreground app
   [self logMessage:@"willPresentNotification %@", notification];
   completionHandler(UNNotificationPresentationOptionList + UNNotificationPresentationOptionBanner + UNNotificationPresentationOptionSound);
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

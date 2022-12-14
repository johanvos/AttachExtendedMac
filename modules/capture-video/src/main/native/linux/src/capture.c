// INSPIRED BY: 
/* V4L2 video picture grabber
   Copyright (C) 2009 Mauro Carvalho Chehab <mchehab@infradead.org>

   This program is free software; you can redistribute it and/or modify
   it under the terms of the GNU General Public License as published by
   the Free Software Foundation version 2 of the License.

   This program is distributed in the hope that it will be useful,
   but WITHOUT ANY WARRANTY; without even the implied warranty of
   MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
   GNU General Public License for more details.

   Modified by Derek Molloy (www.derekmolloy.ie)
   Modified to change resolution details and set paths for the Beaglebone.
 */

#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <fcntl.h>
#include <errno.h>
#include <libudev.h>
#include <sys/ioctl.h>
#include <sys/mman.h>
#include <linux/videodev2.h>
#include <libv4l2.h>
#include <unistd.h>

#include "jni.h"

JNIEnv *jEnv = NULL;
jclass jCaptureVideoServiceClass;
jmethodID jCaptureVideoService_setResult = 0;


int active = 0;

#define CLEAR(x) memset(&(x), 0, sizeof(x))

struct buffer {
        void   *start;
        size_t length;
};

static void xioctl(int fh, int request, void *arg) {
        int r;
        do {
                r = v4l2_ioctl(fh, request, arg);
        } while (r == -1 && ((errno == EINTR) || (errno == EAGAIN)));
        if (r == -1) {
                fprintf(stderr, "error %d, %s\n", errno, strerror(errno));
                exit(EXIT_FAILURE);
        }
}

int initializeGrabber() {
}

void sendPicturesResult(int width, int height, int format, uint8_t* data, size_t len) {
    fprintf(stderr, "send pic, format = %d, len = %ld\n", format,len);
    JNIEnv *env = jEnv;
    jbyteArray picByteArray = (*env)->NewByteArray(env, len);
    (*env)->SetByteArrayRegion(env, picByteArray, 0, len, data);
    if ((*env)->ExceptionCheck(env)) {
        (*env)->ExceptionDescribe(env);
        (*env)->ExceptionClear(env);
        return;
    }
    fprintf(stderr, "send pic2, format = %d\n", format);
    (*env)->CallStaticVoidMethod(env, jCaptureVideoServiceClass, jCaptureVideoService_setResult, width, height, format, picByteArray);
    fprintf(stderr, "send pic3, format = %d\n", format);
    (*env)->DeleteLocalRef(env, picByteArray);
    fprintf(stderr, "send pic4, format = %d\n", format);
}

void rgbToRgba(char* rgba, const char* rgb, const int count) {
    if(count==0) return;
    for(int i=count; --i; rgba+=4, rgb+=3) {
        *(uint32_t*)(void*)rgba = *(const uint32_t*)(const void*)rgb;
    }
    for(int j=0; j<3; ++j) {
        rgba[j] = rgb[j];
    }
}

int startGrabbing() {
        struct v4l2_format              fmt;
        struct v4l2_buffer              buf;
        struct v4l2_requestbuffers      req;
        enum v4l2_buf_type              type;
        fd_set                          fds;
        struct timeval                  tv;
        int                             r, fd = -1;
        unsigned int                    i, n_buffers;
        char                            *dev_name = "/dev/video0";
        char                            out_name[256];
        FILE                            *fout;
        struct buffer                   *buffers;

        fd = v4l2_open(dev_name, O_RDWR | O_NONBLOCK, 0);
        if (fd < 0) {
                perror("Cannot open device");
                exit(EXIT_FAILURE);
        }
        CLEAR(fmt);
        fmt.type = V4L2_BUF_TYPE_VIDEO_CAPTURE;
        fmt.fmt.pix.width       = 1920;
        fmt.fmt.pix.height      = 1080;
        fmt.fmt.pix.pixelformat = V4L2_PIX_FMT_RGB24;
        fmt.fmt.pix.field       = V4L2_FIELD_INTERLACED;
        xioctl(fd, VIDIOC_S_FMT, &fmt);
        if (fmt.fmt.pix.pixelformat != V4L2_PIX_FMT_RGB24) {
                printf("Libv4l didn't accept RGB24 format. Can't proceed.\n");
                exit(EXIT_FAILURE);
        }
        if ((fmt.fmt.pix.width != 640) || (fmt.fmt.pix.height != 480))
                printf("Warning: driver is sending image at %dx%d\n",
                        fmt.fmt.pix.width, fmt.fmt.pix.height);

        CLEAR(req);
        req.count = 2;
        req.type = V4L2_BUF_TYPE_VIDEO_CAPTURE;
        req.memory = V4L2_MEMORY_MMAP;
        xioctl(fd, VIDIOC_REQBUFS, &req);

        buffers = calloc(req.count, sizeof(*buffers));
        for (n_buffers = 0; n_buffers < req.count; ++n_buffers) {
                CLEAR(buf);

                buf.type        = V4L2_BUF_TYPE_VIDEO_CAPTURE;
                buf.memory      = V4L2_MEMORY_MMAP;
                buf.index       = n_buffers;

                xioctl(fd, VIDIOC_QUERYBUF, &buf);

                buffers[n_buffers].length = buf.length;
                buffers[n_buffers].start = v4l2_mmap(NULL, buf.length,
                              PROT_READ | PROT_WRITE, MAP_SHARED,
                              fd, buf.m.offset);

                if (MAP_FAILED == buffers[n_buffers].start) {
                        perror("mmap");
                        exit(EXIT_FAILURE);
                }
        }
        for (i = 0; i < n_buffers; ++i) {
                CLEAR(buf);
                buf.type = V4L2_BUF_TYPE_VIDEO_CAPTURE;
                buf.memory = V4L2_MEMORY_MMAP;
                buf.index = i;
                xioctl(fd, VIDIOC_QBUF, &buf);
        }
        type = V4L2_BUF_TYPE_VIDEO_CAPTURE;

        xioctl(fd, VIDIOC_STREAMON, &type);
        while (active > 0) {
               do {
                        FD_ZERO(&fds);
                        FD_SET(fd, &fds);

                        /* Timeout. */
                        tv.tv_sec = 2;
                        tv.tv_usec = 0;

                        r = select(fd + 1, &fds, NULL, NULL, &tv);
                } while ((r == -1 && (errno = EINTR)));
                if (r == -1) {
                        perror("select");
                        return errno;
                }

                CLEAR(buf);
                buf.type = V4L2_BUF_TYPE_VIDEO_CAPTURE;
                buf.memory = V4L2_MEMORY_MMAP;
                xioctl(fd, VIDIOC_DQBUF, &buf);

                int width = fmt.fmt.pix.width;
                int height = fmt.fmt.pix.height;
                void* rgba = malloc(width*height*4);
rgbToRgba(rgba, buffers[buf.index].start, width * height);
    int len = width * height * 4;
// rgbToRgba(rgba, buffers[buf.index].start, width * height);
    // memcpy(snd, buffers[buf.index].start, len);
sendPicturesResult(width, height, 2, rgba, len);
free(rgba);
                xioctl(fd, VIDIOC_QBUF, &buf);
        }

        type = V4L2_BUF_TYPE_VIDEO_CAPTURE;
        xioctl(fd, VIDIOC_STREAMOFF, &type);
        for (i = 0; i < n_buffers; ++i)
                v4l2_munmap(buffers[i].start, buffers[i].length);
        v4l2_close(fd);
return 0;

}

int deviceId = -1;

JNIEXPORT void JNICALL Java_com_gluonhq_attachextendedmac_capturevideo_impl_DesktopCaptureVideoService_initCaptureVideo (JNIEnv *env, jclass jClass) {
    fprintf(stderr, "LINUXNATIVEInit\n");
    jCaptureVideoServiceClass = (*env)->NewGlobalRef(env, (*env)->FindClass(env, "com/gluonhq/attachextendedmac/capturevideo/impl/DesktopCaptureVideoService"));
    jCaptureVideoService_setResult = (*env)->GetStaticMethodID(env, jCaptureVideoServiceClass, "setResult", "(III[B)V");
initializeGrabber();
}

JNIEXPORT void JNICALL Java_com_gluonhq_attachextendedmac_capturevideo_impl_DesktopCaptureVideoService_nativeStart (JNIEnv *env, jclass jClass) {
jEnv = env;
    fprintf(stderr, "LINUXNATIVESTART\n");
    active =1 ;
startGrabbing();
}


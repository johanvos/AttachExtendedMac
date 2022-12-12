#include <fcntl.h>
#include <libudev.h>
#include <stdio.h>
#include <stdlib.h>
#include <sys/ioctl.h>
#include <sys/mman.h>
#include <linux/videodev2.h>
#include <unistd.h>


#define UDEV_SUBSYSTEM "video4linux"

    u_int8_t* buffer; 

int initialize () {
    struct udev* udev;
    struct udev_enumerate* enumerate;
    struct udev_list_entry* udev_devices, *dev_list_entry;
    udev = udev_new();
    enumerate = udev_enumerate_new(udev);
    udev_enumerate_add_match_subsystem(enumerate, UDEV_SUBSYSTEM);
    udev_enumerate_scan_devices(enumerate);
    udev_devices = udev_enumerate_get_list_entry(enumerate);
    fprintf(stderr, "Got some devices: %p\n", udev_devices);
int fd = -1;
    udev_list_entry_foreach(dev_list_entry, udev_devices) {
        const char * path = udev_list_entry_get_name(dev_list_entry);
        fprintf(stderr, "Got a device: %s\n", path);
        struct udev_device * dev = udev_device_new_from_syspath(udev, path);
        const char * node = udev_device_get_devnode(dev);
        int v4l2_fd = open(node, O_RDONLY);
        fprintf(stderr, "Got a node with fd = %d: %s\n", v4l2_fd, path);
        if (v4l2_fd < 0) {
            fprintf(stderr, "ERROR1\n");
        }
        struct v4l2_capability vcap;
        if (ioctl(v4l2_fd, VIDIOC_QUERYCAP, &vcap) == -1) {
            fprintf(stderr, "ERROR2\n");
        }
        if (!(vcap.capabilities & V4L2_CAP_VIDEO_CAPTURE)) {
            fprintf(stderr, "ERROR3\n");
        }
if (fd == -1) fd = v4l2_fd;
        const char * name = (const char *) vcap.card;
        fprintf(stderr, "Name = %s\n", name);
        struct v4l2_format format = {0};
        struct v4l2_fmtdesc fmt = { 0 };
        struct v4l2_frmsizeenum frameSize = { 0 };

        fmt.index = 0;
        fmt.type = V4L2_BUF_TYPE_VIDEO_CAPTURE;
        while (ioctl(v4l2_fd, VIDIOC_ENUM_FMT, &fmt) >= 0) {
            fprintf(stderr, "Pixelformat = %d\n", fmt.pixelformat);
            fmt.index++;
        }

    }
    return fd;
}

int set_format(int fd) {
    struct v4l2_format format = {0};
    format.type = V4L2_BUF_TYPE_VIDEO_CAPTURE;
    format.fmt.pix.width = 320;
    format.fmt.pix.height = 240;
    format.fmt.pix.pixelformat = V4L2_PIX_FMT_YUYV;
    format.fmt.pix.field = V4L2_FIELD_NONE;
    int res = ioctl(fd, VIDIOC_S_FMT, &format);
    if(res == -1) {
        perror("Could not set format");
        exit(1);
    }
    return res;
}

int request_buffer(int fd, int count) {
    struct v4l2_requestbuffers req = {0};
    req.count = count;
    req.type = V4L2_BUF_TYPE_VIDEO_CAPTURE;
    req.memory = V4L2_MEMORY_MMAP;
    if (-1 == ioctl(fd, VIDIOC_REQBUFS, &req))
    {
        perror("Requesting Buffer");
        exit(1);
    }
    return 0;
}

int query_buffer(int fd) {
    struct v4l2_buffer buf = {0};
    buf.type = V4L2_BUF_TYPE_VIDEO_CAPTURE;
    buf.memory = V4L2_MEMORY_MMAP;
    buf.index = 0;
    int res = ioctl(fd, VIDIOC_QUERYBUF, &buf);
    if(res == -1) {
        perror("Could not query buffer");
        return 2;
    }
    buffer = (u_int8_t*)mmap (NULL, buf.length, PROT_READ | PROT_WRITE, MAP_SHARED, fd, buf.m.offset);
    return buf.length;
}

int start_streaming(int fd) {
    unsigned int type = V4L2_BUF_TYPE_VIDEO_CAPTURE;
    if(ioctl(fd, VIDIOC_STREAMON, &type) == -1){
        perror("VIDIOC_STREAMON");
        exit(1);
    }
}

int queue_buffer(int fd) {
    fprintf(stderr, "queue buffer for %d\n", fd);
    struct v4l2_buffer bufd = {0};
    bufd.type = V4L2_BUF_TYPE_VIDEO_CAPTURE;
    bufd.memory = V4L2_MEMORY_MMAP;
    bufd.index = 0;
    if(-1 == ioctl(fd, VIDIOC_QBUF, &bufd))
    {
    fprintf(stderr, "bummer.\n");
        perror("Queue Buffer");
        return 1;
    }
    return bufd.bytesused;
}

void grab_frame(int camera, int size) {
    queue_buffer(camera);
    //Wait for io operation
    fd_set fds;
    FD_ZERO(&fds);
    FD_SET(camera, &fds);
    struct timeval tv = {0};
    tv.tv_sec = 2; //set timeout to 2 second
    int r = select(camera+1, &fds, NULL, NULL, &tv);
    if(-1 == r){
        perror("Waiting for Frame");
        exit(1);
    }
    int file = open("output.yuy", O_WRONLY);
    write(file, buffer, size); //size is obtained from the query_buffer function
    // dequeue_buffer(camera);
}

void capture() {
     int fd = initialize();
// int fd = open("/dev/video0", O_RDWR);
set_format(fd);
request_buffer(fd, 10);
int size = query_buffer(fd);
start_streaming(fd);
queue_buffer(fd);
grab_frame(fd, size);
}


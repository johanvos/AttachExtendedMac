#include <fcntl.h>
#include <libudev.h>
#include <stdio.h>
#include <sys/ioctl.h>
#include <linux/videodev2.h>


#define UDEV_SUBSYSTEM "video4linux"

void capture () {
    struct udev* udev;
    struct udev_enumerate* enumerate;
    struct udev_list_entry* udev_devices, *dev_list_entry;
    udev = udev_new();
    enumerate = udev_enumerate_new(udev);
    udev_enumerate_add_match_subsystem(enumerate, UDEV_SUBSYSTEM);
    udev_enumerate_scan_devices(enumerate);
    udev_devices = udev_enumerate_get_list_entry(enumerate);
    fprintf(stderr, "Got some devices: %p\n", udev_devices);
    udev_list_entry_foreach(dev_list_entry, udev_devices) {
        const char * path = udev_list_entry_get_name(dev_list_entry);
        fprintf(stderr, "Got a device: %s\n", path);
        struct udev_device * dev = udev_device_new_from_syspath(udev, path);
        const char * node = udev_device_get_devnode(dev);
        fprintf(stderr, "Got a node: %s\n", path);
        int v4l2_fd = open(node, O_RDONLY);
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
        const char * name = (const char *) vcap.card;
        fprintf(stderr, "Name = %s\n", name);
    }
}

package com.gluonhq.attachextendedmac.capturevideo;

import javafx.scene.image.Image;

public class Frame {

    private final int width;
    private final int height;
    private final int pixelFormat;
    private final byte[] bytes;

    public Frame(int width, int height, int pixelFormat, byte[] bytes) {
        this.width = width;
        this.height = height;
        this.pixelFormat = pixelFormat;
        this.bytes = bytes;
    }

    public int getWidth() {
        return width;
    }

    public int getHeight() {
        return height;
    }

    public int getPixelFormat() {
        return pixelFormat;
    }

    public byte[] getBytes() {
        return bytes;
    }
}

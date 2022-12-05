package com.gluonhq.attachextendedmac.capturevideo;

import javafx.scene.image.Image;

public class Frame {

    private final int width;
    private final int height;
    private final byte[] bytes;

    public Frame(int width, int height, byte[] bytes) {
        this.width = width;
        this.height = height;
        this.bytes = bytes;
    }

    public int getWidth() {
        return width;
    }

    public int getHeight() {
        return height;
    }

    public byte[] getBytes() {
        return bytes;
    }
}

cmake_minimum_required(VERSION 3.10)
project(capturevideo)

add_library(capture SHARED
    src/main/native/linux/capture.c
)

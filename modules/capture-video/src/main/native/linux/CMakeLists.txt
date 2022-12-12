cmake_minimum_required(VERSION 3.10)
project(capturevideo)
set(CMAKE_LIBRARY_OUTPUT_DIRECTORY ../../../../../build/native/linux)


add_library(CaptureVideo SHARED
    ../src/capture.c
)

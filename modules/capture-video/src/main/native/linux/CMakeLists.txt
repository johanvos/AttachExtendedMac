cmake_minimum_required(VERSION 3.10)
project(capturevideo)
set(CMAKE_LIBRARY_OUTPUT_DIRECTORY ../../../../../build/native/linux)
include_directories($ENV{JAVA_HOME}/include)
include_directories($ENV{JAVA_HOME}/include/linux)

add_library(CaptureVideo SHARED
    ../src/capture.c
)
target_link_libraries(CaptureVideo v4l2 udev)

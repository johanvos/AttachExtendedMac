cmake_minimum_required(VERSION 3.10)
project(capturevideo)
set(CMAKE_LIBRARY_OUTPUT_DIRECTORY ../../../../../build/native/linux)
include_directories(/opt/java/include)
include_directories(/opt/java/include/linux)

add_library(CaptureVideo SHARED
    ../src/capture.c
)
target_link_libraries(CaptureVideo udev)

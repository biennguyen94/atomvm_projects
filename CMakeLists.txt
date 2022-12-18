# Copyright 2022 Bien Nguyen <nguyennhubientdh94@gmail.com>

cmake_minimum_required (VERSION 2.6)

project(AtomVM)
set(CMAKE_MODULE_PATH ${PROJECT_SOURCE_DIR}/CMakeModules)

if (NOT "${CMAKE_GENERATOR}" MATCHES "Xcode")
    add_subdirectory(doc)
endif()


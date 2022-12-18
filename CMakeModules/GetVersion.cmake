# Copyright 2022 Bien Nguyen <nguyennhubientdh94@gmail.com>

include(${CMAKE_SOURCE_DIR}/version.cmake)

if (ATOMVM_DEV)
    set(ATOMVM_GIT_REVISION "<unknown>")
    execute_process(
        COMMAND git rev-parse --short HEAD
        WORKING_DIRECTORY ${CMAKE_SOURCE_DIR}
        OUTPUT_VARIABLE ATOMVM_GIT_REVISION
        OUTPUT_STRIP_TRAILING_WHITESPACE
    )
    if (NOT ATOMVM_GIT_REVISION STREQUAL "")
        set(ATOMVM_VERSION "${ATOMVM_BASE_VERSION}+git.${ATOMVM_GIT_REVISION}")
    else()
        set(ATOMVM_VERSION ${ATOMVM_BASE_VERSION})
    endif()
else()
    set(ATOMVM_VERSION ${ATOMVM_BASE_VERSION})
endif()

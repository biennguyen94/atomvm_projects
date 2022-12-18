# Copyright 2022 Bien Nguyen <nguyennhubientdh94@gmail.com>

find_program(SPHINX_PATH sphinx-build)

if (SPHINX_PATH)
    set(SPHINX_FOUND TRUE)
    set(SPHINX_BUILD_EXECUTABLE "${SPHINX_PATH}")
elseif(SPHINX_FIND_REQUIRED)
    message(FATAL_ERROR "Sphinx command (spinx-build) not found")
endif()

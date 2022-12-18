# Copyright 2022 Bien Nguyen <nguyennhubientdh94@gmail.com>

project(doc)

file(MAKE_DIRECTORY ${CMAKE_CURRENT_BINARY_DIR}/html)
##
## Sphinx documentation
##
find_package(Sphinx)
if(SPHINX_FOUND)

    include(${CMAKE_SOURCE_DIR}/CMakeModules/GetVersion.cmake)

    message("Sphinx found: ${SPHINX_BUILD_EXECUTABLE}")
    configure_file(${CMAKE_CURRENT_SOURCE_DIR}/conf.py.in ${CMAKE_CURRENT_BINARY_DIR}/conf.py @ONLY)
    add_custom_target(sphinx-html
        ${SPHINX_BUILD_EXECUTABLE} -b html -c ${CMAKE_CURRENT_BINARY_DIR} ${CMAKE_CURRENT_SOURCE_DIR}/src ${CMAKE_CURRENT_BINARY_DIR}/html
        WORKING_DIRECTORY ${CMAKE_CURRENT_BINARY_DIR}
        COMMENT "Generating Sphinx HTML documentation" VERBATIM
        DEPENDS ${ERLANG_DOTFILE_TARGETS}
    )
else()
    message("Unable to find Sphinx -- no Sphinx documentation will be generated")
endif()


add_custom_target(doc #ALL
    DEPENDS ${ERLANG_EDOC_TARGETS} sphinx-html
)

#
# This file is part of AtomVM.
#
# Copyright 2018-2020 Fred Dushin <fred@dushin.net>
#
# Licensed under the Apache License, Version 2.0 (the "License");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at
#
#    http://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.
#
# SPDX-License-Identifier: Apache-2.0 OR LGPL-2.1-or-later
#

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

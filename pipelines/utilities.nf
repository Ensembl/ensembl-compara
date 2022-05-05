#!/usr/bin/env nextflow
/** See the NOTICE file distributed with this work for additional information
* regarding copyright ownership.
*
* Licensed under the Apache License, Version 2.0 (the "License");
* you may not use this file except in compliance with the License.
* You may obtain a copy of the License at
*
*     http://www.apache.org/licenses/LICENSE-2.0
*
* Unless required by applicable law or agreed to in writing, software
* distributed under the License is distributed on an "AS IS" BASIS,
* WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
* See the License for the specific language governing permissions and
* limitations under the License.
*/

import groovy.json.JsonSlurper

def ensemblLogo() {
    /**
    *ANSI string of ensembl logo (e!)
    *
    *@return string of ANSI ensembl (e!) logo with colour compatible with bash/shell
    */
    reset = "\u001b[0m"
    blue = "\u001b[34;1m"
    red = "\u001b[31m"
    logo = """
        ${red}----------------------------------------------------${reset}
               ${red}_${reset}    ${blue}_____                          _     _${reset}
          ${blue}___${reset} ${red}| |${reset}  ${blue}| ____|_ __  ___  ___ _ __ ___ | |__ | |${reset}
         ${blue}/ _ \\${reset}${red}| |${reset}  ${blue}|  _| | '_ \\/ __|/ _ \\ '_ ` _ \\| '_ \\| |${reset}
        ${blue}|  __/${reset}${red}|_|${reset}  ${blue}| |___| | | \\__ \\  __/ | | | | | |_) | |${reset}
         ${blue}\\___|${reset}${red}(_)${reset}  ${blue}|_____|_| |_|___/\\___|_| |_| |_|_.__/|_|${reset}

        ${red}----------------------------------------------------${reset}
    """.stripIndent()
        return logo
}

def listSubDirs(base_dir, exclude_str) {
    /**
    *Definition to return immediate subdirectories in specified directory
    *
    *@param base_dir Parent directory in which children directories are to be listed
    *@param exclude string to exclude in subdirectory list return (optional)
    *@return List of immediate subdirectories in base_dir
    */
    def dir_list = [];
    exclude = exclude_str ? exclude_str : ""
    base_dir.eachFile { item ->
        if ( item.isDirectory() ) {
            if ( !item.getName().equals(exclude) ) {
                dir_list.add(item.getName())
            }
        }
    }
    return dir_list
}

def parseJSONSoloEntry(json_string, key_name) {
    /**
    *Parses json_string and returns single entry matching key_name
    *
    *@param json_string simple JSON formatted string
    *@param key_name JSON key with which to return corresponding value
    *@return value corresponding to key_name in json_string
    */
    def json = new groovy.json.JsonSlurper().parseText(json_string)
    assert json instanceof Map
    return json.key_name
}

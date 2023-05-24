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

import java.util.zip.GZIPInputStream


def chainFileHasData(chain_file) {
    /**
    * Check if chain file has data.
    *
    * @param chain_file GZIP-compressed chain file.
    * @return true if chain file has data; false otherwise.
    */
    def stream = new GZIPInputStream(chain_file.newInputStream())
    def reader = new InputStreamReader(stream, 'utf-8')

    def data_found = false
    while ((line = reader.readLine()) != null) {
        if (!line.startsWith('#')) {
            data_found = true
            break
        }
    }

    return data_found
}

def composeChainFileName(task_params, level, gzip) {
    /**
    * Compose chain file name.
    *
    * @param task_params Task parameters.
    * @param level Level for which chain is generated.
    * @return Chain file name.
    */
    def source_tag_parts = [task_params.source_genome]
    if (level in ['sequence', 'location']) {
        source_tag_parts.add(task_params.source_sequence)

        if (level == 'location') {
            source_tag_parts.addAll([task_params.source_start,
                                     task_params.source_end,
                                     task_params.source_strand])
        }
    }

    def chain_file_name = sprintf('%s_to_%s.linearGap_medium.chain',
                                  source_tag_parts.join('_'),
                                  task_params.dest_genome)

    if (gzip) {
        chain_file_name += '.gz'
    }

    return chain_file_name
}

def convertTaskParamTypes(task_params) {
    /**
    * Convert task parameter types.
    *
    * @param task_params Input task parameters.
    * @return Task parameters with converted types.
    */
    def int_param_names = ['group_size', 'source_start', 'source_end']

    int_param_names.each { param_name ->
        if (task_params.containsKey(param_name)) {
            task_params[param_name] = task_params[param_name].toInteger()
        }
    }

    return task_params
}

def getCommonMapEntries(maps) {
    /**
    * Get entries common to input maps.
    *
    * @param maps List of map objects.
    * @return A single map object
    * containing common entries.
    */
    def map_key_sets = maps*.keySet()

    def common_keys = map_key_sets.tail().inject(map_key_sets.head()) {
        intersection, key_set -> intersection.intersect(key_set)
    }

    def common_entries = common_keys.collectEntries { key ->
        maps*.get(key).toSet().size() == 1 ? [(key): maps.head().get(key)] : [:]
    }

    return common_entries
}

def getDefaultHalCachePath(hal_file_path) {
    /**
    * Get default HAL cache path from HAL file.
    *
    * @param hal_file_path Path of HAL file.
    * @return Path of HAL cache.
    */
    def hal_cache_prefix = hal_file_path
    if (hal_file_path.endsWith('.hal')) {
        hal_cache_prefix = hal_file_path.substring(0, hal_file_path.lastIndexOf('.hal'))
    }
    return sprintf('%s_cache', hal_cache_prefix)
}

def getNonemptyChains(chain_files) {
    /**
    * Filter chain files, keeping only nonempty ones.
    *
    * @param chain_files List of chain files.
    * @return Filtered list of chain files.
    */
    return chain_files.findAll { chainFileHasData(it) }
}

def loadMappingFromTsv(file_path) {
    /**
    * Load mapping from two-column TSV file.
    *
    * @param file_path Path of two-column TSV file.
    * @return Mapping of each value in the first column
    * to its corresponding value in the second column.
    */
    def lines = file_path.readLines('utf-8')

    def mapping = [:]
    lines.each { line ->
        def (key, value) = line.split('\t')
        mapping[key] = value
    }

    return mapping
}

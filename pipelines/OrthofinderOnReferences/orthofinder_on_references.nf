#!/usr/bin/env nextflow

nextflow.enable.dsl=2

include { orthoFinderFactory; runOrthoFinder } from './../orthofinder_modules.nf'

// A little groovy scripting to collect just the file names from the directories for ease of use,
// as far as I can tell the file handling in nextflow is much more file rather than directory friendly
base_dir = file(params.dir)
def dir_list = [];
base_dir.eachFile { item ->
    if ( item.isDirectory() ) {
        if ( !item.getName().equals('references') ) {
            dir_list.add(item.getName())
        }
    }
}

workflow {
    // The starting flow of data to use in the first process
    Channel
        .from(dir_list)
        .set{ collection_ch }

    orthoFinderFactory(collection_ch)
    runOrthoFinder(orthoFinderFactory.out)
}

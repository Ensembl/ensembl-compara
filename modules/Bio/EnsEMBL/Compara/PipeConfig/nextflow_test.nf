#!/usr/bin/env nextflow

// Commandline parameters here
params.dir = '/hps/nobackup/flicek/ensembl/compara/shared/reference_fasta_symlinks/'
params.orthofinder_exe = '/hps/software/users/ensembl/ensw/C8-MAR21-sandybridge/linuxbrew/bin/orthofinder'
params.destination = '/hps/nobackup/flicek/ensembl/compara/cristig/reference_collections'

// Assign parameters to variables for later use
orthofinder_exe = params.orthofinder_exe
base_dir = file(params.dir)
dest_dir = file(params.destination)

// A little groovy scripting to collect just the file names from the directories for ease of use,
// as far as I can tell the file handling in nextflow is much more file rather than directory friendly
def dir_list = [];
base_dir.eachFile { item ->
    if( item.isDirectory() ) {
        if( !item.getName().equals('references') ) {
            dir_list.add(item.getName())
        }
    }
}

// The starting flow of data to use in the first process
Channel
    .from(dir_list)
    .set{ collection_ch }

process orthoFinderFactory {

    label 'job_default'

    publishDir dest_dir

    input:
    val x from collection_ch

    output:
    val x into collection_dataset

    shell:
    """
    rsync -Lavz ${base_dir}/${x} ${dest_dir}/
    """
}

process runOrthoFinder {

    label 'job_64Gb_32C'

    input:
    val x from collection_dataset
    
    shell:
    """
    ${orthofinder_exe} -t 32 -a 8 -f ${dest_dir}/${x}
    """
}

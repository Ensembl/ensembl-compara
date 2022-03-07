#!/usr/bin/env nextflow

nextflow.enable.dsl=2

params.orthofinder_exe = ''
params.dir = ''
params.destination = ''

process orthoFinderFactory {

    label 'rc_default'

    publishDir("$params.destination")

    input:
    val x

    output:
    val x

    shell:
    """
    echo 'rsync -Lavz ${params.dir}/${x} ${params.destination}/'
    """
}

process runOrthoFinder {

    label 'rc_64Gb_32C'

    input:
    val x
    
    shell:
    """
    ${params.orthofinder_exe} -t 32 -a 8 -f ${params.destination}/${x}
    """
}

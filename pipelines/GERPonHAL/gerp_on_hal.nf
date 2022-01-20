#!/usr/bin/env nextflow

genomes_file = file(params.genomes_file)
tree_file = file(params.tree_file)

// Initialise workflow
Channel
    .fromPath(params.hal_file)
    .set { hal_file }

process getMAFfiles {
    label 'rc_default'

    input:
    file hal_file

    output:
    file "*.maf" into maf_files mode flatten

    shell:
    '''
    python $ENSEMBL_ROOT_DIR/ensembl-compara/scripts/hal_alignment/hal_to_maf.py !{hal_file} output.maf \
        --ref-genome "" --ref-sequence "" --keep-genomes-file !{genomes_file}
    '''
}

process convertMAFtoMFA {
    label 'rc_default'

    input:
    file maf from maf_files

    output:
    file "*.mfa" into mfa_files mode flatten
    
    script:
    """
    touch ${maf.baseName}.mfa
    """
}

process runGERP {
    label 'rc_default'

    input:
    file mfa from mfa_files

    output:
    file "*.ce" into ce_files mode flatten
    
    shell:
    '''
    python $ENSEMBL_ROOT_DIR/ensembl-compara/src/python/scripts/run_gerp.py --msa_file !{mfa} \
        --tree_file !{tree_file}
    '''
}

process mergeConstElems {
    label 'rc_default'
    echo true

    input:
    val ce from ce_files.collect()

    script:
    """
    echo "DONE"
    """
}

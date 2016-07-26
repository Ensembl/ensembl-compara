// HAL C -> perl interface, to be used with Inline::C.
// NB: all of the following functions must be compiled into the *same*
// .so--otherwise the functions that use HAL "file descriptors" will
// fail to work properly!
// #include <stdlib.h>
// #include <iostream.h>
// #include <fstream.h>
#include <stdio.h>
// #include "hal.h"
#include "halBlockViz.h"
// #include "halMafExport.h"
// #include "halDefs.h"

int _open_hal(char *halFilePath) {
    return halOpen(halFilePath, NULL);
}

SV *_get_genome_metadata(int hal_fd, const char *genomeName) {
    HV *ret = newHV();
    char *errStr = NULL;
    struct hal_metadata_t *metadata = halGetGenomeMetadata(hal_fd, genomeName, &errStr);
    if (errStr) {
      croak(errStr);
    }
    struct hal_metadata_t *curMetadata = metadata;
    while (curMetadata != NULL) {
        hv_store(ret, curMetadata->key, strlen(curMetadata->key),
                 newSVpv(curMetadata->value, strlen(curMetadata->value)),
                 0);
        curMetadata = curMetadata->next;
    }

    // Clean up
    halFreeMetadataList(metadata);
    return newRV_noinc((SV *) ret);
}

void _get_genome_names(int hal_fd) {
    Inline_Stack_Vars;
    Inline_Stack_Reset;
    struct hal_species_t *genomes = halGetSpecies(hal_fd, NULL);
    struct hal_species_t *curGenome = genomes;
    while (curGenome != NULL) {
        SV *genomeName = newSVpv(curGenome->name, strlen(curGenome->name));
        Inline_Stack_Push(genomeName);
        curGenome = curGenome->next;
    }
    halFreeSpeciesList(genomes);
    Inline_Stack_Done;
}

// Get a list of sequence names belonging to a genome.
void _get_seqs_in_genome(int fileHandle, const char *genomeName) {
  Inline_Stack_Vars;
  Inline_Stack_Reset;
  char *errStr = NULL;
  struct hal_chromosome_t *chroms = halGetChroms(fileHandle, genomeName,
                                                 &errStr);
  if (errStr != NULL) {
    croak(errStr);
  }
  struct hal_chromosome_t *curChrom = chroms;
  while (curChrom != NULL) {
    Inline_Stack_Push(newSVpv(curChrom->name, strlen(curChrom->name)));
    curChrom = curChrom->next;
  }
  halFreeChromList(chroms);
  Inline_Stack_Done;
}

void _get_pairwise_blocks(int fileHandle, char *querySpecies, char *targetSpecies, char *targetChrom, int targetStart, int targetEnd) {
    Inline_Stack_Vars;
    Inline_Stack_Reset;
    // We should be asking for target dups but this is simpler for now.
    char *errStr = NULL;
    // Last parameter (0 or 1) controls the inclusion of overlapping blocks
    struct hal_block_results_t *results = halGetBlocksInTargetRange(fileHandle, querySpecies, targetSpecies, targetChrom, targetStart, targetEnd, 0, HAL_FORCE_LOD0_SEQUENCE, HAL_QUERY_DUPS, 1, NULL, &errStr);
    
    // To enable the snake track
    /*struct hal_block_results_t *results = halGetBlocksInTargetRange(fileHandle, querySpecies, targetSpecies, targetChrom, targetStart, targetEnd, 0, HAL_FORCE_LOD0_SEQUENCE, HAL_QUERY_AND_TARGET_DUPS, 1, NULL, &errStr);*/
    if (errStr != NULL) {
      croak(errStr);
    }
    struct hal_block_t *curBlock = results->mappedBlocks;
    do {
        if (curBlock == NULL) {
            break;
        }
        // Create a perl array that will store the info for this block.
        AV *blockInfo = newAV();
        // Fill in the array with the block info, in order:
        // 0: query chrom name
        // 1: target start pos (0-based, inclusive)
        // 2: query start pos (0-based, inclusive)
        // 3: size of the block
        // 4: query strand '+' or '-'
        // 5: query seq DNA, or undefined
        // 6: target seq DNA, or undefined
        assert(curBlock->qChrom != NULL);
        SV *chromName = newSVpv(curBlock->qChrom, strlen(curBlock->qChrom));
        av_push(blockInfo, chromName);
        assert(curBlock->tStart != NULL_INDEX);
        SV *tStart = newSVuv(curBlock->tStart);
        av_push(blockInfo, tStart);
        assert(curBlock->qStart != NULL_INDEX);
        SV *qStart = newSVuv(curBlock->qStart);
        av_push(blockInfo, qStart);
        assert(curBlock->size != NULL_INDEX);
        SV *size = newSVuv(curBlock->size);
        av_push(blockInfo, size);
        assert(curBlock->strand == '-' || curBlock->strand == '+');
        SV *strand = newSVpv(&curBlock->strand, 1);
        av_push(blockInfo, strand);
        SV *qSequence;
        if (curBlock->qSequence != NULL) {
            qSequence = newSVpv(curBlock->qSequence, strlen(curBlock->qSequence));
        } else {
            av_push(blockInfo, newSV(NULL));
        }
        av_push(blockInfo, qSequence);
        SV *tSequence;
        if (curBlock->tSequence != NULL) {
            tSequence = newSVpv(curBlock->tSequence, strlen(curBlock->tSequence));
        } else {
            av_push(blockInfo, newSV(NULL));
        }
        av_push(blockInfo, tSequence);

        // Finally, add this block to the growing list.
        SV *blockInfoRef = newRV_noinc((SV *) blockInfo);
        Inline_Stack_Push(blockInfoRef);
    } while ((curBlock = curBlock->next) != NULL);
    halFreeBlockResults(results);
    Inline_Stack_Done;
}

void _get_pairwise_blocks_filtered(int fileHandle, char *querySpecies, char *targetSpecies, char *targetChrom, int targetStart, int targetEnd, char *queryChrom) {
    Inline_Stack_Vars;
    Inline_Stack_Reset;

    printf("%s\t%s\t%s\t%s\n", querySpecies, queryChrom, targetSpecies, targetChrom );
    // We should be asking for target dups but this is simpler for now.
    char *errStr = NULL;
    // Last parameter (0 or 1) controls the inclusion of overlapping blocks
    struct hal_block_results_t *results = halGetBlocksInTargetRange_filterByChrom(fileHandle, querySpecies, targetSpecies, targetChrom, targetStart, targetEnd, 0, HAL_FORCE_LOD0_SEQUENCE, HAL_QUERY_DUPS, 1, queryChrom, NULL, &errStr);
    
    // To enable the snake track
    /*struct hal_block_results_t *results = halGetBlocksInTargetRange(fileHandle, querySpecies, targetSpecies, targetChrom, targetStart, targetEnd, 0, HAL_FORCE_LOD0_SEQUENCE, HAL_QUERY_AND_TARGET_DUPS, 1, NULL, &errStr);*/
    if (errStr != NULL) {
      croak(errStr);
    }
    struct hal_block_t *curBlock = results->mappedBlocks;
    do {
        if (curBlock == NULL) {
            break;
        }
        // Create a perl array that will store the info for this block.
        AV *blockInfo = newAV();
        // Fill in the array with the block info, in order:
        // 0: query chrom name
        // 1: target start pos (0-based, inclusive)
        // 2: query start pos (0-based, inclusive)
        // 3: size of the block
        // 4: query strand '+' or '-'
        // 5: query seq DNA, or undefined
        // 6: target seq DNA, or undefined
        assert(curBlock->qChrom != NULL);
        SV *chromName = newSVpv(curBlock->qChrom, strlen(curBlock->qChrom));
        av_push(blockInfo, chromName);
        assert(curBlock->tStart != NULL_INDEX);
        SV *tStart = newSVuv(curBlock->tStart);
        av_push(blockInfo, tStart);
        assert(curBlock->qStart != NULL_INDEX);
        SV *qStart = newSVuv(curBlock->qStart);
        av_push(blockInfo, qStart);
        assert(curBlock->size != NULL_INDEX);
        SV *size = newSVuv(curBlock->size);
        av_push(blockInfo, size);
        assert(curBlock->strand == '-' || curBlock->strand == '+');
        SV *strand = newSVpv(&curBlock->strand, 1);
        av_push(blockInfo, strand);
        SV *qSequence;
        if (curBlock->qSequence != NULL) {
            qSequence = newSVpv(curBlock->qSequence, strlen(curBlock->qSequence));
        } else {
            av_push(blockInfo, newSV(NULL));
        }
        av_push(blockInfo, qSequence);
        SV *tSequence;
        if (curBlock->tSequence != NULL) {
            tSequence = newSVpv(curBlock->tSequence, strlen(curBlock->tSequence));
        } else {
            av_push(blockInfo, newSV(NULL));
        }
        av_push(blockInfo, tSequence);

        // Finally, add this block to the growing list.
        SV *blockInfoRef = newRV_noinc((SV *) blockInfo);
        Inline_Stack_Push(blockInfoRef);
    } while ((curBlock = curBlock->next) != NULL);
    halFreeBlockResults(results);
    Inline_Stack_Done;
}

void _get_multiple_aln_blocks( int halfileHandle, char *querySpecies[], char *targetSpecies, char *targetChrom, int targetStart, int targetEnd, int maxRefGap, bool showAncestors, bool printTree, int maxBlockLen ) {
    Inline_Stack_Vars;
    Inline_Stack_Reset;

    // prepare reference handles
    // const Genome* refGenome = NULL;
    // if (targetSpecies != "\"\"")
    // {
    //   refGenome = alignment->openGenome(targetSpecies);
    //   if (refGenome == NULL)
    //   {
    //     throw hal_exception(string("Reference genome, ") + targetSpecies + 
    //                         ", not found in alignment");
    //   }
    // }
    // else
    // {
    //   refGenome = alignment->openGenome(alignment->getRootName());
    // }
    // const SegmentedSequence* ref = refGenome;

    // // prepare target genome handles
    // set<const Genome*> targetSet;
    // for (size_t i = 0; i < querySpecies.size(); ++i)
    // {
    //     const Genome* tgtGenome = alignment->openGenome(querySpecies[i]);
    //     if (tgtGenome == NULL)
    //     {
    //       throw hal_exception(string("Target genome, ") + querySpecies[i] + 
    //                           ", not found in alignment");
    //     }
    //     targetSet.insert(tgtGenome);
    // }

    // SV *msa_blocks = halGetMSABlocksInTargetRange(halfileHandle, ref, targetStart, targetEnd, targetSet, maxRefGap, true, printTree, maxBlockLen);
    // Inline_Stack_Push(msa_blocks);

    Inline_Stack_Done;
}

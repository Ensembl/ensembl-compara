/*
 * Copyright [1999-2015] Wellcome Trust Sanger Institute and the EMBL-European Bioinformatics Institute
 * Copyright [2016-2018] EMBL-European Bioinformatics Institute
 *
 * Licensed under the Apache License, Version 2.0 (the "License");
 * you may not use this file except in compliance with the License.
 * You may obtain a copy of the License at
 *
 *      http://www.apache.org/licenses/LICENSE-2.0
 *
 * Unless required by applicable law or agreed to in writing, software
 * distributed under the License is distributed on an "AS IS" BASIS,
 * WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
 * See the License for the specific language governing permissions and
 * limitations under the License.
 */

#include "EXTERN.h"
#include "perl.h"
#include "XSUB.h"
#include "INLINE.h"

// HAL C -> perl interface, to be used with Inline::C.
// NB: all of the following functions must be compiled into the *same*
// .so--otherwise the functions that use HAL "file descriptors" will
// fail to work properly!
// #include <stdlib.h>
// #include <iostream.h>
// #include <fstream.h>
#include <stdio.h>
//#include "hal.h"
#include "halBlockViz.h"
// #include "halMafExport.h"
// #include "halDefs.h"

/** Some information about a genome */
// struct hal_species_t
// {
//    struct hal_species_t* next;
//    char* name;
//    hal_int_t length;
//    hal_int_t numChroms;
//    char* parentName;
//    double parentBranchLength;
// };

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
void _get_seqs_in_genome(int fileHandle, char *genomeName) {
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
    struct hal_block_results_t *results = halGetBlocksInTargetRange(fileHandle, querySpecies, targetSpecies, targetChrom, targetStart, targetEnd, 0, HAL_FORCE_LOD0_SEQUENCE, HAL_NO_DUPS, 1, NULL, &errStr);
    
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
            av_push(blockInfo, newSV(0));   // undef
        }
        av_push(blockInfo, qSequence);
        SV *tSequence;
        if (curBlock->tSequence != NULL) {
            tSequence = newSVpv(curBlock->tSequence, strlen(curBlock->tSequence));
        } else {
            av_push(blockInfo, newSV(0));   // undef
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

    //printf("%s\t%s\t%s\t%s\n", querySpecies, queryChrom, targetSpecies, targetChrom );
    // We should be asking for target dups but this is simpler for now.
    char *errStr = NULL;
    // Last parameter (0 or 1) controls the inclusion of overlapping blocks
    struct hal_block_results_t *results = halGetBlocksInTargetRange_filterByChrom(fileHandle, querySpecies, targetSpecies, targetChrom, targetStart, targetEnd, 0, HAL_FORCE_LOD0_SEQUENCE, HAL_NO_DUPS, 1, queryChrom, NULL, &errStr);
    
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
            av_push(blockInfo, newSV(0));   // undef
        }
        av_push(blockInfo, qSequence);
        SV *tSequence;
        if (curBlock->tSequence != NULL) {
            tSequence = newSVpv(curBlock->tSequence, strlen(curBlock->tSequence));
        } else {
            av_push(blockInfo, newSV(0));   // undef
        }
        av_push(blockInfo, tSequence);

        // Finally, add this block to the growing list.
        SV *blockInfoRef = newRV_noinc((SV *) blockInfo);
        Inline_Stack_Push(blockInfoRef);
    } while ((curBlock = curBlock->next) != NULL);
    halFreeBlockResults(results);
    Inline_Stack_Done;
}

// pass querySpecies as a comma-seperated string
void _get_multiple_aln_blocks( int halfileHandle, char *querySpecies, char *targetSpecies, char *targetChrom, int targetStart, int targetEnd, int maxRefGap) {
    //int maxRefGap, bool showAncestors, bool printTree, int maxBlockLen ) {
    Inline_Stack_Vars;
    Inline_Stack_Reset;

    // open memory file buffer
    char *bp;
    size_t size;
    FILE *stream;
    stream = open_memstream (&bp, &size);

    //printf("%s\n", "MSA 1");

    // create a hal_species_t struct for querySpecies
    // struct hal_species_t* head = NULL;
    // struct hal_species_t* prev = NULL;
    // struct hal_species_t* cur  = NULL;

    // char *str_copy = strdup(querySpecies);
    // char *str_copy_ptr = str_copy;
    // char *token;
    // while ((token = strsep(&str_copy_ptr, ","))) {
    //     cur = (struct hal_species_t*) calloc(1, sizeof(struct hal_species_t));
    //     cur->name = strdup(token);
    //     cur->next = NULL;
    //     if ( head == NULL ){ //struct start
    //         head = cur;
    //     }
    //     else {
    //         prev->next = cur;
    //     }
    //     prev = cur;
    // }
    // free(str_copy);

    // only way seems to be to fetch all and split structure into 2
    struct hal_species_t *hal_genomes = halGetSpecies(halfileHandle, NULL);
    struct hal_species_t *curGenome = hal_genomes; // iterator
    struct hal_species_t* query_species = NULL; // pointer for head of query list
    struct hal_species_t* other_species = NULL; // pointer for head of non-query list
    struct hal_species_t* prev_q = NULL; // iterator - holds previous query genome
    struct hal_species_t* prev_o = NULL; // iterator - holds prev non-query genome

    while (curGenome != NULL) {
        int x;
        int found = 0; 
        char *str_copy = strdup(querySpecies);
        char *str_copy_ptr = str_copy;
        char *token;
        // check if curGenome is a query genome or not - set found boolean if so
        while ((token = strsep(&str_copy_ptr, ","))) {
            if (strcmp(curGenome->name, token) == 0) {
                found = 1;
                break;
            }
        }
        free(str_copy);
        if ( found == 0 ) { // non-query genome
            if ( other_species == NULL ) { //start a new list
                other_species = curGenome;
            } else {
                prev_o->next = curGenome;
            }
            prev_o = curGenome;
        } else { // query genome
            if ( query_species == NULL ) {
                query_species = curGenome;
            } else {
                prev_q->next = curGenome; 
            }
            prev_q = curGenome;
        }
        curGenome = curGenome->next;
    }
    // terminate both lists
    prev_o->next = NULL;
    prev_q->next = NULL;

    // print MAF to buffer
    char *errStr = NULL;
    halGetMAF( stream, halfileHandle, query_species, targetSpecies, targetChrom, targetStart, targetEnd, maxRefGap, 0, &errStr );
    fclose (stream);
    
    //SV *maf = newSVpv(bp, strlen(bp));
    SV *maf = newSVpvn(bp, size);
    Inline_Stack_Push(maf);

    halFreeSpeciesList(other_species);
    halFreeSpeciesList(query_species);
    free(bp);
    Inline_Stack_Done;
}

MODULE = HALXS  PACKAGE = HALXS  

PROTOTYPES: DISABLE

void
hello()
CODE:
    printf("Hello, world!\n");

int
_open_hal (halFilePath)
	char *	halFilePath

SV *
_get_genome_metadata (hal_fd, genomeName)
	int	hal_fd
	const char *	genomeName

void
_get_genome_names (hal_fd)
	int	hal_fd
        PREINIT:
        I32* temp;
        PPCODE:
        temp = PL_markstack_ptr++;
        _get_genome_names(hal_fd);
        if (PL_markstack_ptr != temp) {
          /* truly void, because dXSARGS not invoked */
          PL_markstack_ptr = temp;
          XSRETURN_EMPTY; /* return empty stack */
        }
        /* must have used dXSARGS; list context implied */
        return; /* assume stack size is correct */

void
_get_seqs_in_genome (fileHandle, genomeName)
	int	fileHandle
	char *	genomeName
        PREINIT:
        I32* temp;
        PPCODE:
        temp = PL_markstack_ptr++;
        _get_seqs_in_genome(fileHandle, genomeName);
        if (PL_markstack_ptr != temp) {
          /* truly void, because dXSARGS not invoked */
          PL_markstack_ptr = temp;
          XSRETURN_EMPTY; /* return empty stack */
        }
        /* must have used dXSARGS; list context implied */
        return; /* assume stack size is correct */

void
_get_pairwise_blocks (fileHandle, querySpecies, targetSpecies, targetChrom, targetStart, targetEnd)
	int	fileHandle
	char *	querySpecies
	char *	targetSpecies
	char *	targetChrom
	int	targetStart
	int	targetEnd
        PREINIT:
        I32* temp;
        PPCODE:
        temp = PL_markstack_ptr++;
        _get_pairwise_blocks(fileHandle, querySpecies, targetSpecies, targetChrom, targetStart, targetEnd);
        if (PL_markstack_ptr != temp) {
          /* truly void, because dXSARGS not invoked */
          PL_markstack_ptr = temp;
          XSRETURN_EMPTY; /* return empty stack */
        }
        /* must have used dXSARGS; list context implied */
        return; /* assume stack size is correct */

void
_get_pairwise_blocks_filtered (fileHandle, querySpecies, targetSpecies, targetChrom, targetStart, targetEnd, queryChrom)
	int	fileHandle
	char *	querySpecies
	char *	targetSpecies
	char *	targetChrom
	int	targetStart
	int	targetEnd
	char *	queryChrom
        PREINIT:
        I32* temp;
        PPCODE:
        temp = PL_markstack_ptr++;
        _get_pairwise_blocks_filtered(fileHandle, querySpecies, targetSpecies, targetChrom, targetStart, targetEnd, queryChrom);
        if (PL_markstack_ptr != temp) {
          /* truly void, because dXSARGS not invoked */
          PL_markstack_ptr = temp;
          XSRETURN_EMPTY; /* return empty stack */
        }
        /* must have used dXSARGS; list context implied */
        return; /* assume stack size is correct */

void
_get_multiple_aln_blocks (halfileHandle, querySpecies, targetSpecies, targetChrom, targetStart, targetEnd, maxRefGap)
	int	halfileHandle
	char *	querySpecies
	char *	targetSpecies
	char *	targetChrom
	int	targetStart
	int	targetEnd
    int maxRefGap
        PREINIT:
        I32* temp;
        PPCODE:
        temp = PL_markstack_ptr++;
        _get_multiple_aln_blocks(halfileHandle, querySpecies, targetSpecies, targetChrom, targetStart, targetEnd, maxRefGap);
        if (PL_markstack_ptr != temp) {
          /* truly void, because dXSARGS not invoked */
          PL_markstack_ptr = temp;
          XSRETURN_EMPTY; /* return empty stack */
        }
        /* must have used dXSARGS; list context implied */
        return; /* assume stack size is correct */


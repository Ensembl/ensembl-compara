use strict;
use warnings;
use Inline ( C => Config =>
             libs => "-L/cluster/home/jcarmstr/progressiveCactus-fresh/submodules/hdf5/lib -lstdc++ -lhdf5 -lhdf5_cpp",
             myextlib => ["/cluster/home/jcarmstr/progressiveCactus-fresh/submodules/hal/lib/halChain.a", "/cluster/home/jcarmstr/progressiveCactus-fresh/submodules/hal/lib/halLod.a", "/cluster/home/jcarmstr/progressiveCactus-fresh/submodules/hal/lib/halLiftover.a", "/cluster/home/jcarmstr/progressiveCactus-fresh/submodules/hal/lib/halLib.a", "/cluster/home/jcarmstr/progressiveCactus-fresh/submodules/sonLib/lib/sonLib.a"],
             inc => "-I/cluster/home/jcarmstr/progressiveCactus-fresh/submodules/hal/chain/inc/");
use Inline 'C';

my $halHandle = open_hal("test.hal");
my @blocks = getBlocksInTargetRange($halHandle, "mhc1", "mhc2", "mhc2", 0, 100);
foreach my $block (@blocks) {
    print "$block\n";
    foreach my $entry (@$block) {
        if (defined $entry) {
            print "$entry\n"
        }
    }
    print "\n"
}

__END__
__C__
#include "halBlockViz.h"
int open_hal(char *halFilePath) {
    return halOpen(halFilePath, NULL);
}

void get_pairwise_blocks(int fileHandle, char *querySpecies, char *targetSpecies, char *targetChrom, int targetStart, int targetEnd) {
    Inline_Stack_Vars;
    Inline_Stack_Reset;
    // We should be asking for target dups but this is simpler for now.
    struct hal_block_results_t *results = halGetBlocksInTargetRange(fileHandle, querySpecies, targetSpecies, targetChrom, targetStart, targetEnd, 0, HAL_FORCE_LOD0_SEQUENCE, HAL_QUERY_DUPS, 1, NULL);
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
        SV *blockInfoRef = newRV_inc((SV *) blockInfo);
        Inline_Stack_Push(blockInfoRef);
    } while ((curBlock = curBlock->next) != NULL);
    Inline_Stack_Done;
}

void test()
{
    printf("test\n");
}

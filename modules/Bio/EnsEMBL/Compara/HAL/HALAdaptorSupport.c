#include "halBlockViz.h"

int open_hal(char *halFilePath) {
    return halOpen(halFilePath, NULL);
}

SV *getGenomeMetadata(int hal_fd, const char *genomeName) {
    HV *ret = newHV();
    struct hal_metadata_t *metadata = halGetGenomeMetadata(hal_fd, genomeName);
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

void getGenomeNames(int hal_fd) {
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

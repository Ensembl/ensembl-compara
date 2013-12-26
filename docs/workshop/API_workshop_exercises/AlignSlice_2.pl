# Copyright [1999-2013] Wellcome Trust Sanger Institute and the EMBL-European Bioinformatics Institute
# 
# Licensed under the Apache License, Version 2.0 (the "License");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at
# 
#      http://www.apache.org/licenses/LICENSE-2.0
# 
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.

use strict;
use warnings;
use Bio::EnsEMBL::Registry;
use Data::Dumper;

Bio::EnsEMBL::Registry->load_registry_from_db(
        -host=>'ensembldb.ensembl.org', -user=>'anonymous', 
        -port=>'5306');

my $ref_species = "homo_sapiens";

my $genome_db_adaptor = Bio::EnsEMBL::Registry->get_adaptor(
        'Multi', 'compara', 'GenomeDB');

my $ref_genome_db = $genome_db_adaptor->fetch_by_registry_name("$ref_species");

my @all_pairwise_mlss;

my $method_link_species_set_adaptor = Bio::EnsEMBL::Registry->get_adaptor(
        'Multi', 'compara', 'MethodLinkSpeciesSet');

# get all the pairwise alignment types which have the reference species (BLASTZ_NET, LASTZ_NET, TRANSLATED_BLAT_NET) 
foreach my $method_type ('BLASTZ_NET', 'LASTZ_NET', 'TRANSLATED_BLAT_NET'){
        push(@all_pairwise_mlss, @{ $method_link_species_set_adaptor->fetch_all_by_method_link_type_GenomeDB( "$method_type", $ref_genome_db) });
}

my $ref_slice_adaptor = Bio::EnsEMBL::Registry->get_adaptor(
        "$ref_species", 'core', 'Slice');

my $align_slice_adaptor = Bio::EnsEMBL::Registry->get_adaptor(
        'Multi', 'compara', 'AlignSlice');

while(<>){
        chomp;
        next if $_=~/#/;
        my ($ref_seq_region, $snp) = split(/\s+/, $_);
        print join("\t", "##############", $ref_species, $ref_seq_region, $snp), "\n";
        my $ref_slice = $ref_slice_adaptor->fetch_by_region( 'toplevel', $ref_seq_region, $snp, $snp );
        next if($ref_slice->seq eq "N");
        my $ref_seen;
        foreach my $pairwise_methodLinkSpeciesSet( @all_pairwise_mlss ){
                my $alignSlice = $align_slice_adaptor->fetch_by_Slice_MethodLinkSpeciesSet( $ref_slice, $pairwise_methodLinkSpeciesSet );
                foreach my $genome_db( @{ $pairwise_methodLinkSpeciesSet->species_set_obj->genome_dbs() } ){
                        my $species_name = $genome_db->name;
                        next if ($ref_seen && $species_name eq "$ref_species");
                        my $align_slice_slice = $alignSlice->get_all_Slices( $species_name );
                        next unless( $align_slice_slice->[0] );
                        my($slice, $position) = $align_slice_slice->[0]->get_original_seq_region_position(1);
                        # the returned slice does not have an adaptor, hence
                        if($species_name eq "$ref_species"){
                                $ref_seen = 1;
                                get_codons( $ref_slice );
                        } else {
                                my $non_ref_slice_adaptor =  Bio::EnsEMBL::Registry->get_adaptor(
                                        "$species_name", 'core', 'Slice');
                                my $non_ref_slice = $non_ref_slice_adaptor->fetch_by_region( 'toplevel', $slice->seq_region_name(), $position, $position );
                                get_codons( $non_ref_slice );
                        }
                }
        }
}

sub get_codons {
        my $slice = shift;
        return unless $slice;
        my ($snp, $seq_region_name) = ($slice->start, $slice->seq_region_name);
        my $seq_region_slice = $slice->adaptor->fetch_by_region('toplevel', $slice->seq_region_name); # need this for the mapper
        foreach my $transcript ( @{$slice->get_all_Transcripts} ){
                next unless $transcript->is_canonical();
                next unless $transcript->translateable_seq(); # skip if not coding (it's UTR or a pseudogene)
                my ($tr_mapper);
                foreach my $seq_region_transcript( @{$seq_region_slice->get_all_Transcripts} ){
                        if( $seq_region_transcript->stable_id eq $transcript->stable_id ){
                                $tr_mapper = Bio::EnsEMBL::TranscriptMapper->new($seq_region_transcript); # get the mapper
                        }
                }

                # find the (amino acid) position where the snp maps on the transcript translation 
                my @pep_coords = $tr_mapper->genomic2pep($snp, $snp, $transcript->strand); 

                next unless $pep_coords[0]->isa("Bio::EnsEMBL::Mapper::Coordinate"); # dont want gaps

                # find the coords where the amino acid maps to the genome (this should take care of codons split across exons)
                my @genomic_coords = $tr_mapper->pep2genomic($pep_coords[0]->start, $pep_coords[0]->end); 

                my ($transcript_id, $species_name, $transcript_strand, $gene_stable_id) = 
                ($transcript->stable_id, $transcript->species, $transcript->strand, $transcript->get_Gene->stable_id);
                foreach my $coord_set( @genomic_coords ){
                        my ($start, $end, $strand) = ($coord_set->start, $coord_set->end, $coord_set->strand);
                        printf "[ %s ]\t", $seq_region_slice->sub_Slice($start, $end, $strand)->seq;
                }
                printf "\t%s\t%s:%s\t", $species_name, $seq_region_name, $snp;
                print "\n";
        }
}



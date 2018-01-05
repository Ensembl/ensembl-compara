# Copyright [1999-2015] Wellcome Trust Sanger Institute and the EMBL-European Bioinformatics Institute
# Copyright [2016-2018] EMBL-European Bioinformatics Institute
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

#########################
#
# Before `make install' is performed this script should be runnable with
# `make test'. After `make install' it should work as `perl HALXS.t'

#########################

use strict;
use warnings;

use Data::Dumper;

use Bio::EnsEMBL::Registry;
use Bio::EnsEMBL::Compara::DBSQL::DBAdaptor;
#use Bio::EnsEMBL::Compara::HAL::HALXS::HALAdaptor;

#use Memory::Usage;
#my $mu = Memory::Usage->new();

# Register everything from a particular release
my $registry = 'Bio::EnsEMBL::Registry';
$registry->load_registry_from_url(
  'mysql://ensro@mysql-ensembl-mirror.ebi.ac.uk:4240/89',
  1
);

my $compara_alias = 'Multi';

#uncomment this for a custom ensembl compara database
if (0) {
    Bio::EnsEMBL::Registry->remove_DBAdaptor('ofa', 'core'); # deregister old version
    $compara_alias = 'compara_curr';
    new Bio::EnsEMBL::Compara::DBSQL::DBAdaptor(
        -host => 'mysql-ens-compara-prod-1.ebi.ac.uk',
        -user => 'ensro',
        -port => 4485,
        -species => $compara_alias,
        -dbname => 'ensembl_compara_90'
    );
}

my $limit_number;

my $mlssa = $registry->get_adaptor($compara_alias, "compara", "MethodLinkSpeciesSet");
my $gaba  = $registry->get_adaptor($compara_alias, "compara", "GenomicAlignBlock"  );
my $gdba  = $registry->get_adaptor($compara_alias, "compara", "GenomeDB"  );

# my $mlsses = $mlssa->fetch_all_by_method_link_type('CACTUS_HAL');
# my $mlss   = $mlsses->[0];
# my $mlss = $mlssa->fetch_by_dbID(859); # rat v castaneus
my $mlss = $mlssa->fetch_by_dbID(835); # all strains
# my $mlss = $mlssa->fetch_by_dbID(828);

# my $mouse_gdb = $gdba->fetch_by_registry_name('mouse');
# my $rat_gdb   = $gdba->fetch_by_registry_name('rat');
# my $mlss = $mlssa->fetch_by_method_link_type_GenomeDBs("CACTUS_HAL_PW", [$mouse_gdb, $rat_gdb]);
# my $mlss = $mlssa->fetch_by_method_link_type_GenomeDBs("LASTZ_NET", [$mouse_gdb, $rat_gdb]);

# my $mlss_list = $mlssa->fetch_all_by_method_link_type_GenomeDB('CACTUS_HAL_PW', $rat_gdb);

############################################################
#                  Memory leak test                        #
############################################################
# my $sliceAdaptor = $registry->get_adaptor('mus_castaneus', 'Core', 'Slice');
# my ( $start, $slice_size, $max ) = (0, 1000, 5000000);
# $mu->record('starting work');
# foreach my $x ( 0..10000 ) {
# 	while ( $start+$slice_size < $max ){
# 		my $slice = $sliceAdaptor->fetch_by_region('chromosome', '5', $start, $start+$slice_size);
# 		$start += $slice_size;
# 	}
# 	$start = 0;
# 	if ( $x%100 == 0 ){
# 		$mu->record("loop $x");
# 		print "loop $x";
# 	}
# }
# $mu->record('finished work');
# $mu->dump();

############################################################
#               GenomicAlignBlock tests                    #
############################################################
# my ( $start, $end ) = ( 5000000, 5100000 ); # 5000000, 5100000
# print "\n-----------SLICE GABS---------------\n\n";
# my $sliceAdaptor = $registry->get_adaptor('mus_castaneus', 'Core', 'Slice');
# my $slice = $sliceAdaptor->fetch_by_region('chromosome', '5', $start, $end);

# my $slice_gabs = $gaba->fetch_all_by_MethodLinkSpeciesSet_Slice( $mlss->[0], $slice, $limit_number );

# my $c = 0;
# foreach my $gab ( @$slice_gabs ) {
# 	print "$c : ";
# 	$gab->_print;
# 	$c++;
# }

# print "-----------DNAFRAG GABS-------------\n";
# my $dnafrag_adaptor = $registry->get_adaptor( 'mouse_master', 'compara', 'DnaFrag' );
# my $dnafrag = $dnafrag_adaptor->fetch_by_Slice( $slice );

# my $dnafrag_gabs = $gaba->fetch_all_by_MethodLinkSpeciesSet_DnaFrag( $mlss->[0], $dnafrag, $start, $end, $limit_number );

# $c = 0;
# foreach my $gab ( @$dnafrag_gabs ) {
# 	print "$c : ";
# 	$gab->_print;
# 	$c++;
# }

# print "-----------DNA_DNA GABS-------------\n";
# my $gdba = $registry->get_adaptor( 'mouse_master', 'compara', 'GenomeDB' );
# my $nonref_gdb = $gdba->fetch_by_name_assembly( 'mus_spretus', 'CURRENT' );
# my $nonref_dnafrag = $dnafrag_adaptor->fetch_by_GenomeDB_and_name( $nonref_gdb, '5' );
# my $dna_dna_gabs = $gaba->fetch_all_by_MethodLinkSpeciesSet_DnaFrag_DnaFrag( $mlss->[0], $dnafrag, $start, $end, $nonref_dnafrag, $limit_number );

# $c = 0;
# foreach my $gab ( @$dna_dna_gabs ) {
# 	print "$c : ";
# 	$gab->_print;
# 	$c++;
# }

############################################################
#                   Sandbox Testing                        #
############################################################

# my ( $species, $chr, $start, $end ) = ('mus_musculus_casteij', 4, 136445586, 136468192);
# my ( $species, $chr, $start, $end ) = ('rattus_norvegicus', 5, 65377319, 65380320);
# my ( $species, $chr, $start, $end ) = ('rattus_norvegicus', 5, 62700000, 62800000); # 100kbp
# my ( $species, $chr, $start, $end ) = ('rattus_norvegicus', 5, 62797383, 63627669); # rat sample region
# my ( $species, $chr, $start, $end ) = ('rattus_norvegicus', 5, 155810542, 155810773);
# my ( $species, $chr, $start, $end ) = ('mus_musculus', 4, 136366473, 136547301); # quite evil


my ( $species, $chr, $start, $end ) = ('rattus_norvegicus', 2, 56000000, 56050000);
# my ( $species, $chr, $start, $end ) = ('rattus_norvegicus', 2, 56000000, 56500000);

print "Fetching $chr:$start-$end from $species (" . ($end-$start+1) . " bp)\n";

my $sliceAdaptor = $registry->get_adaptor($species, 'Core', 'Slice');
my $slice = $sliceAdaptor->fetch_by_region('chromosome', $chr, $start, $end);

my $c = 0;

# my $alignSliceAdaptor = $registry->get_adaptor('compara_curr', 'compara', 'AlignSlice');
# print "Fetching alignSlice\n";
# my $alignSlice = $alignSliceAdaptor->fetch_by_Slice_MethodLinkSpeciesSet($slice, $mlss, 'expanded', 'restrict');

# #$Data::Dumper::Maxdepth = 6;
# #print Dumper $alignSlice->{slices};

# print "\n\n------------SLICES-------------\n";
# my $all_slices = $alignSlice->get_all_Slices();
# foreach my $this_slice (@$all_slices) {
# #    ## See also Bio::EnsEMBL::Compara::AlignSlice::Slice
# #    my $species_name = $this_slice->genome_db->name();
# #    my $all_mapped_genes = $this_slice->get_all_Genes();
#      print $this_slice->display_id . "\n";
# #    my $projection = $this_slice->project('seqlevel', undef, 1);
# #    print "projection: ";
# #    print Dumper $projection;
# }


# #print "\n\n------------BLOCKS-------------\n";
# #for my $gblock ( @{ $alignSlice->get_all_GenomicAlignBlocks } ){
# #	$gblock->_print;
# #	#print ">>>>>>>\n\n";
# #	#for my $g ( @{ $gblock->genomic_align_array } ) {
# #	#      $g->_print;
# #	#}
# #	#print "<<<<<<<\n\n";
# #}
# #$c++;
# print "\n-----------------------------------\n\n";

#}

my $slice_gabs = $gaba->fetch_all_by_MethodLinkSpeciesSet_Slice( $mlss, $slice, $limit_number );

$c = 0;
foreach my $gab ( @$slice_gabs ) {
	print "$c : " . $gab->toString . "\n";
	$c++;
}
print "Got $c blocks! Yay!\n\n";

# use Statistics::Histogram;
# my $slice_gabs = $gaba->fetch_all_by_MethodLinkSpeciesSet_Slice( $mlss, $slice, $limit_number );
# my @block_lens = map { $_->length } @$slice_gabs;
# print get_histogram(\@block_lens);

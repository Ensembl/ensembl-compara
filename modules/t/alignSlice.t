#!/usr/bin/env perl

use strict;
use warnings;

use Test::More;
use Test::Exception;

use Bio::EnsEMBL::Utils::Exception qw (warning verbose);
use Bio::EnsEMBL::Test::MultiTestDB;
use Bio::EnsEMBL::Test::TestUtils;
use Bio::EnsEMBL::Compara::GenomicAlignBlock;
use Bio::EnsEMBL::Compara::GenomicAlignGroup;
use Bio::EnsEMBL::Compara::MethodLinkSpeciesSet;

#####################################################################
## Connect to the test database using the MultiTestDB.conf file

my $multi = Bio::EnsEMBL::Test::MultiTestDB->new( "multi" );
my $compara_dba = $multi->get_DBAdaptor( "compara" );
my $genome_db_adaptor = $compara_dba->get_GenomeDBAdaptor();

my $ref_species = "homo_sapiens";

## Connect to core DB specified in the MultiTestDB.conf file
my $species_db;
$species_db->{$ref_species} = Bio::EnsEMBL::Test::MultiTestDB->new($ref_species);

#Set up adaptors
my $slice_adaptor = $species_db->{$ref_species}->get_DBAdaptor("core")->get_SliceAdaptor();
my $align_slice_adaptor = $compara_dba->get_AlignSliceAdaptor();
my $genomic_align_adaptor = $compara_dba->get_GenomicAlignAdaptor();
my $genomic_align_block_adaptor = $compara_dba->get_GenomicAlignBlockAdaptor();
my $genomic_align_tree_adaptor = $compara_dba->get_GenomicAlignTreeAdaptor();
my $method_link_species_set_adaptor = $compara_dba->get_MethodLinkSpeciesSetAdaptor();

#####################################################################
##  DATA USED TO TEST API
##
my $slice_coord_system_name = "chromosome";
my $slice_seq_region_name = "6";
my $dnafrag_id = $compara_dba->dbc->db_handle->selectrow_array("
    SELECT dnafrag_id FROM dnafrag df, genome_db gdb
    WHERE df.genome_db_id = gdb.genome_db_id
      AND df.name = \"$slice_seq_region_name\"
      AND df.coord_system_name = \"$slice_coord_system_name\"
      AND gdb.name = \"$ref_species\"");
my $slice_start = 31500000;
my $slice_end = 32000000;

my $method_type = "EPO_LOW_COVERAGE";
my $epo_species_set_name = "mammals";
my $epo_mlss = $method_link_species_set_adaptor->fetch_by_method_link_type_species_set_name($method_type, $epo_species_set_name);

#
# New(void) method
#
subtest "Test Bio::EnsEMBL::Compara::AlignSlice new(void) method", sub {
  my $align_slice = new Bio::EnsEMBL::Compara::AlignSlice();
  isa_ok($align_slice, "Bio::EnsEMBL::Compara::AlignSlice", "check object");

  done_testing();
};

#
# New(ALL) method
#
subtest "Test Bio::EnsEMBL::Compara::GenomicAlign new(ALL) method", sub {

    my $gab_forward_id = 5990000047741;
    my $sth = $compara_dba->dbc->prepare("SELECT genomic_align_id
    FROM genomic_align WHERE genomic_align_block_id=$gab_forward_id");
    
    $sth->execute();
    my $genomic_aligns;
    while (my $genomic_align_id = $sth->fetchrow_array) {
        my $ga = $genomic_align_adaptor->fetch_by_dbID($genomic_align_id);
        push @{$genomic_aligns->{$ga->dnafrag->genome_db->name}}, $ga;
   }
    my $ref_species = "homo_sapiens";
    my $ref_ga = $genomic_aligns->{$ref_species}->[0];

    my $slice = $slice_adaptor->fetch_by_region(
                                                $ref_ga->dnafrag->coord_system_name,
                                                $ref_ga->dnafrag->name,
                                                $ref_ga->dnafrag_start,
                                                $ref_ga->dnafrag_end,
                                                1
                                               );
    #EPO_LOW_COVERAGE
    #my $gab_forward = $genomic_align_block_adaptor->fetch_by_dbID($gab_forward_id);
    my $gabs = $genomic_align_block_adaptor->fetch_all_by_MethodLinkSpeciesSet_Slice($epo_mlss, $slice, undef, undef, 1);
    
    #my $gats = $genomic_align_tree_adaptor->fetch_all_by_MethodLinkSpeciesSet_Slice($epo_mlss, $slice, undef, undef, 1);

    my $gats;
    my $expanded = 1;
    my $solve_overlapping = 0;
    my $preserve_blocks = 0;
    my $species_order;

    my $align_slice = new Bio::EnsEMBL::Compara::AlignSlice(-adaptor => $align_slice_adaptor,
                                                            -reference_slice => $slice,
                                                            -Genomic_Align_Blocks => $gabs, 
                                                            -Genomic_Align_Trees => $gats,
                                                            -method_link_species_set => $epo_mlss,
                                                            -expanded => $expanded,
                                                            -solve_overlapping => $solve_overlapping,
                                                            -preserve_blocks => $preserve_blocks,
                                                            -species_order => $species_order,
                                                           );

    #Not many getter functions. Can only set many fields via the new method
    isa_ok($align_slice, "Bio::EnsEMBL::Compara::AlignSlice", "check object");
    is($align_slice->adaptor, $align_slice_adaptor, "adaptor");
    is($align_slice->reference_Slice, $slice, "reference_slice");
    is($align_slice->get_MethodLinkSpeciesSet, $epo_mlss, "mlss");

    #compare_gab_as($gabs->[0], $gats->[0], $align_slice);



    done_testing();
};

done_testing();

sub compare_gab_as {
    my ($gab, $gat, $align_slice) = @_;

    print "gab length " . $gab->length . "\n";
    my $ga_hash;
    foreach my $genomic_align (@{$gab->get_all_GenomicAligns}) {
        print substr($genomic_align->aligned_sequence, 0,100) . " " .  $genomic_align->genome_db->name . " " . length($genomic_align->aligned_sequence) . "\n";
        #$ga_hash->{$genomic_algin->genome_db->name} = $genomic_align;
    }


    my %ga_aligned_seqs;
    foreach my $this_genomic_align_tree (@{$gat->get_all_sorted_genomic_align_nodes()}) {
        next if (!$this_genomic_align_tree->genomic_align_group);
        #push(@{$segments}, $this_genomic_align_tree->genomic_align_group);
        my $gag = $this_genomic_align_tree->genomic_align_group;
        my $name = $this_genomic_align_tree->genomic_align_group->genome_db->name;
        print "NAME $name\n";

        my $aligned_seq = $gag->aligned_sequence;

        $ga_aligned_seqs{$name}{aligned_seq} = $aligned_seq;
        $ga_aligned_seqs{$name}{num_gas} = @{$gag->genomic_align_array};
    }

    foreach my $slice (@{$align_slice->get_all_Slices()}) {
        is (length($slice->seq), $gab->length, "length");
        
#       print "NAME " . $slice->genome_db->name . " length " . length($slice->seq) . " " . $slice->seq . "\n";
        print substr($slice->seq,0,100) . " " . $slice->genome_db->name . " " . length($slice->seq) . "\n";
        is($slice->seq, $ga_aligned_seqs{$slice->genome_db->name}, "seq");

    }

}

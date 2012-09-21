#!/usr/bin/env perl

use strict;
use warnings;

use Test::More;

use Bio::EnsEMBL::Utils::Exception qw (warning verbose);
use Bio::EnsEMBL::Test::MultiTestDB;
use Bio::EnsEMBL::Test::TestUtils;

use Bio::EnsEMBL::Compara::GenomicAlignGroup;


#####################################################################
## Connect to the test database using the MultiTestDB.conf file

my $multi = Bio::EnsEMBL::Test::MultiTestDB->new( "multi" );

my $compara_db_adaptor = $multi->get_DBAdaptor( "compara" );

my $genomic_align_group;
my $genomic_align_group_adaptor = $compara_db_adaptor->get_GenomicAlignGroupAdaptor;
my $genomic_align_adaptor = $compara_db_adaptor->get_GenomicAlignAdaptor;

my $dnafrag_id = 4671099; #cat GeneScaffold_4790 (probably should do this better)
my $dnafrag_adaptor = $compara_db_adaptor->get_DnaFragAdaptor();
my $dnafrag = $dnafrag_adaptor->fetch_by_dbID($dnafrag_id);

my $cigar_line = "100M";
my $ga1 = new Bio::EnsEMBL::Compara::GenomicAlign(-dbID => 1,
                                                  -dnafrag => $dnafrag,
                                                  -dnafrag_start => 1,
                                                  -dnafrag_end => 100,
                                                  -dnafrag_strand => 1,
                                                  -cigar_line => $cigar_line,
                                                 );
my $ga2 = new Bio::EnsEMBL::Compara::GenomicAlign(-dbID => 2,
                                                  -dnafrag => $dnafrag,
                                                  -dnafrag_start => 101,
                                                  -dnafrag_end => 200,
                                                  -dnafrag_strand => 1,
                                                  -cigar_line => $cigar_line,
                                                 );
my $ga3 = new Bio::EnsEMBL::Compara::GenomicAlign(-dbID => 3,
                                                  -dnafrag => $dnafrag,
                                                  -dnafrag_start => 201,
                                                  -dnafrag_end => 300,
                                                  -dnafrag_strand => 1,
                                                  -cigar_line => $cigar_line,
                                                 );

my $genomic_align_array;
push @$genomic_align_array, $ga1, $ga2, $ga3;

##
#####################################################################

subtest "Test Bio::EnsEMBL::Compara::GenomicAlignGroup::new(void) method", sub {
    $genomic_align_group = new Bio::EnsEMBL::Compara::GenomicAlignGroup();
    isa_ok($genomic_align_group, "Bio::EnsEMBL::Compara::GenomicAlignGroup");
    done_testing();
};

subtest "Test Bio::EnsEMBL::Compara::GenomicAlignGroup::new(ALL) method", sub {
    my $genomic_align_group_id = 123;
    $genomic_align_group = new Bio::EnsEMBL::Compara::GenomicAlignGroup(
                                                                        -adaptor => $genomic_align_group_adaptor,
                                                                        -dbID    => $genomic_align_group_id,
                                                                        -genomic_align_array => $genomic_align_array
                                                                       );
    isa_ok($genomic_align_group, "Bio::EnsEMBL::Compara::GenomicAlignGroup");
    is($genomic_align_group->adaptor, $genomic_align_group_adaptor);
    is($genomic_align_group->dbID, $genomic_align_group_id);
    is(scalar(@{$genomic_align_group->genomic_align_array}), scalar(@{$genomic_align_array}));
    is_deeply($genomic_align_group->genomic_align_array, $genomic_align_array);

    done_testing();
};

subtest "Test getter/setter Bio::EnsEMBL::Compara::GenomicAlignGroup methods", sub {
    my $genomic_align_group_id = 123;
    $genomic_align_group = new Bio::EnsEMBL::Compara::GenomicAlignGroup(
                                                                        -adaptor => $genomic_align_group_adaptor,
                                                                        -dbID    => $genomic_align_group_id,
                                                                        -genomic_align_array => $genomic_align_array
                                                                       );
    ok(test_getter_setter($genomic_align_group, "adaptor", $genomic_align_group_adaptor));
    ok(test_getter_setter($genomic_align_group, "dbID", $genomic_align_group_id));

    is_deeply($genomic_align_group->genomic_align_array, $genomic_align_array);
    done_testing();
};

done_testing();


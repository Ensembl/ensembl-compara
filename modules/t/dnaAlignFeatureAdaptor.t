#!/usr/local/ensembl/bin/perl -w

#
# Test script for Bio::EnsEMBL::Compara::DBSQL::DnaAlignFeatureAdaptor module
#
# Written by Abel Ureta-Vidal (abel@ebi.ac.uk)
# Updated by Javier Herrero (jherrero@ebi.ac.uk)
#
# Copyright (c) 2004. EnsEMBL Team
#
# You may distribute this module under the same terms as perl itself

=head1 NAME

dnaAlignFeatureAdaptor.t

=head1 INSTALLATION

*_*_*_*_*_*_*_*_*_*_*_*_*_*_   W A R N I N G  _*_*_*_*_*_*_*_*_*_*_*_*_*_*

YOU MUST EDIT THE <MultiTestDB.conf> FILE BEFORE USING THIS TEST SCRIPT!!!

*_*_*_*_*_*_*_*_*_*_*_*_*_*_   W A R N I N G  _*_*_*_*_*_*_*_*_*_*_*_*_*_*

Please, read the README file for instructions.

=head1 SYNOPSIS

For running this test only:
perl -w ../../../ensembl-test/scripts/runtests.pl dnaAlignFeatureAdaptor.t

For running all the test scripts:
perl -w ../../../ensembl-test/scripts/runtests.pl

For running all the test scripts and cleaning the database afterwards:
perl -w ../../../ensembl-test/scripts/runtests.pl -c

=head1 DESCRIPTION

This script uses a small compara database build following the specifitions given in the MultiTestDB.conf file.

This script tests (as far as possible) all the methods in the
Bio::EnsEMBL::Compara::DBSQL::DnaAlignFeatureAdaptor module.

This script includes 22 tests.

=head1 AUTHORS

Abel Ureta-Vidal (abel@ebi.ac.uk)
Javier Herrero (jherrero@ebi.ac.uk)

=head1 COPYRIGHT

Copyright (c) 2004. EnsEMBL Team

You may distribute this module under the same terms as perl itself

=head1 CONTACT

This modules is part of the EnsEMBL project (http://www.ensembl.org)

Questions can be posted to the ensembl-dev mailing list:
ensembl-dev@ebi.ac.uk

=head1 TODO

Add tests for the interpolate_best_location() method

=cut

use strict;
use warnings;

use Bio::EnsEMBL::Test::MultiTestDB;
use Bio::EnsEMBL::Test::TestUtils qw(debug test_getter_setter);

BEGIN {
  $| = 1;
  use Test;
  plan tests => 22;
}

#set to 1 to turn on debug prints
our $verbose = 0;

my $multi = Bio::EnsEMBL::Test::MultiTestDB->new('multi');

my $homo_sapiens = Bio::EnsEMBL::Test::MultiTestDB->new("homo_sapiens");
my $rattus_norvegicus = Bio::EnsEMBL::Test::MultiTestDB->new("rattus_norvegicus");
my $gallus_gallus = Bio::EnsEMBL::Test::MultiTestDB->new("gallus_gallus");

my $hs_dba = $homo_sapiens->get_DBAdaptor('core');
my $rn_dba = $rattus_norvegicus->get_DBAdaptor('core');
my $gg_dba = $gallus_gallus->get_DBAdaptor('core');
my $compara_dba = $multi->get_DBAdaptor('compara');

my $human_name     = $hs_dba->get_MetaContainer->get_Species->binomial;
my $human_assembly = $hs_dba->get_CoordSystemAdaptor->fetch_all->[0]->version;
my $rat_name       = $rn_dba->get_MetaContainer->get_Species->binomial;
my $rat_assembly   = $rn_dba->get_CoordSystemAdaptor->fetch_all->[0]->version;
my $chicken_name       = $gg_dba->get_MetaContainer->get_Species->binomial;
my $chicken_assembly   = $gg_dba->get_CoordSystemAdaptor->fetch_all->[0]->version;

my $gdba = $compara_dba->get_GenomeDBAdaptor;

my $hs_gdb = $gdba->fetch_by_name_assembly($human_name,$human_assembly);
$hs_gdb->db_adaptor($hs_dba);
my $rn_gdb = $gdba->fetch_by_name_assembly($rat_name,$rat_assembly);
$rn_gdb->db_adaptor($rn_dba);
my $gg_gdb = $gdba->fetch_by_name_assembly($chicken_name,$chicken_assembly);
$gg_gdb->db_adaptor($gg_dba);

my $dafa = $compara_dba->get_DnaAlignFeatureAdaptor;

sub print_matches {
  my $matches = shift;

  foreach my $match (@$matches) {
    debug($match->seqname.":".$match->start . "-" . $match->end . ":" . 
	  $match->cigar_string);
  }
}

#######
#  1  #
#######

my $slice = $hs_dba->get_SliceAdaptor->fetch_by_region('toplevel',14,50000010,50249000);
my $chicken_matches =
	$dafa->fetch_all_by_Slice($slice, $chicken_name, $chicken_assembly, "BLASTZ_NET");


my $num = scalar(@$chicken_matches);
ok($num, 17);
debug("\ngot $num human-chicken matches\n");

#$verbose && &print_matches($chicken_matches);

#######
#  2  #
#######

my $rat_matches =
	$dafa->fetch_all_by_Slice($slice, $rat_name, $rat_assembly, "BLASTZ_NET");


$num = scalar(@$rat_matches);
ok($num, 281);
debug("\ngot $num human-rat matches\n");

$verbose && &print_matches($rat_matches);

$rat_matches = $dafa->fetch_all_by_species_region(
        $human_name,
        $human_assembly,
        $rat_name,
        $rat_assembly,
        "14",
        50000010,
        50000020,
        "BLASTZ_NET",
        0,
        "chromosome"
    );

$num = scalar(@$rat_matches);
ok($num, 1);
ok($rat_matches->[0]->{'seqname'}, "14");
ok($rat_matches->[0]->{'start'}, 49999812);
ok($rat_matches->[0]->{'end'}, 50000028);
ok($rat_matches->[0]->{'strand'}, 1);
ok($rat_matches->[0]->{'species'}, "Homo sapiens");
ok($rat_matches->[0]->{'score'}, 4581);
ok($rat_matches->[0]->{'percent_id'}, 48);
ok($rat_matches->[0]->{'hstart'}, 92842620);
ok($rat_matches->[0]->{'hend'}, 92842888);
ok($rat_matches->[0]->{'hstrand'}, 1);
ok($rat_matches->[0]->{'hseqname'}, "6");
ok($rat_matches->[0]->{'hspecies'}, "Rattus norvegicus");
ok($rat_matches->[0]->{'alignment_type'}, "BLASTZ_NET");
ok($rat_matches->[0]->{'group_id'}, 1);
ok($rat_matches->[0]->{'level_id'}, 1);
ok($rat_matches->[0]->{'strands_reversed'}, 0);
ok($rat_matches->[0]->{'cigar_string'}, "86M2D39M14I10MD34M7D6M12D15M44D13M");

$verbose && &print_matches($rat_matches);

#######
#  3  #
#######

$slice = $gg_dba->get_SliceAdaptor->fetch_by_region('toplevel',5,54735035,54743580);
my $human_matches = 
	$dafa->fetch_all_by_Slice($slice, $human_name, $human_assembly, "BLASTZ_NET");

$num = scalar(@$human_matches);
ok($num, 14);

debug("\ngot $num chicken-human matches\n");
$verbose && &print_matches($human_matches);

#######
#  4  #
#######

$slice = $rn_dba->get_SliceAdaptor->fetch_by_region('toplevel',6,93002042,93038844);
$human_matches = 
	$dafa->fetch_all_by_Slice($slice, $human_name, $human_assembly, "BLASTZ_NET");

$num = scalar(@$human_matches);
ok($num, 44);

debug("\ngot $num rat-human matches\n");
$verbose && &print_matches($human_matches);

__END__;

#######
#  5  #
#######

#
# transitive alignment...
#
$slice = $hs_dba->get_SliceAdaptor->fetch_by_region('toplevel',14,50000010,50249000);
$rat_matches = $dafa->fetch_all_by_Slice($slice, $rat_name, $rat_assembly,"BLASTZ_NET");
$num = scalar(@$rat_matches);

ok($num, 281);
debug("\ngot $num human-rat matches\n");
$verbose && &print_matches($rat_matches);

#######
#  6  #
#######

#
# reverse-transitive alignment
#

$slice = $rn_dba->get_SliceAdaptor->fetch_by_region('toplevel',6,92842600, 92852150);
$human_matches = 
	$dafa->fetch_all_by_Slice($slice, $human_name, $human_assembly,"BLASTZ_NET");
$num = scalar(@$human_matches);

ok($num, 11);
debug("got $num rat-human matches\n");
$verbose && &print_matches($human_matches);





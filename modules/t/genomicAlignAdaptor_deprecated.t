#!/usr/local/ensembl/bin/perl -w

#
# Test script for Bio::EnsEMBL::Compara::DBSQL::GenomicAlignAdaptor module
#
# Written by Javier Herrero (jherrero@ebi.ac.uk)
#
# Copyright (c) 2004. EnsEMBL Team
#
# You may distribute this module under the same terms as perl itself

=head1 NAME

genomicAlignAdaptor.t

=head1 INSTALLATION

*_*_*_*_*_*_*_*_*_*_*_*_*_*_   W A R N I N G  _*_*_*_*_*_*_*_*_*_*_*_*_*_*

YOU MUST EDIT THE <MultiTestDB.conf> FILE BEFORE USING THIS TEST SCRIPT!!!

*_*_*_*_*_*_*_*_*_*_*_*_*_*_   W A R N I N G  _*_*_*_*_*_*_*_*_*_*_*_*_*_*

Please, read the README file for instructions.

=head1 SYNOPSIS

For running this test only:
perl -w ../../../ensembl-test/scripts/runtests.pl genomicAlignAdaptor.t

For running all the test scripts:
perl -w ../../../ensembl-test/scripts/runtests.pl

For running all the test scripts and cleaning the database afterwards:
perl -w ../../../ensembl-test/scripts/runtests.pl -c

=head1 DESCRIPTION

This script uses a small compara database build following the specifitions given in the MultiTestDB.conf file.

This script (as far as possible) tests all the methods defined in the
Bio::EnsEMBL::Compara::DBSQL::GenomicAlignAdaptor module.

This script includes 64 tests.

=head1 AUTHOR

Javier Herrero (jherrero@ebi.ac.uk)

=head1 COPYRIGHT

Copyright (c) 2004. EnsEMBL Team

You may distribute this module under the same terms as perl itself

=head1 CONTACT

This modules is part of the EnsEMBL project (http://www.ensembl.org)

Questions can be posted to the ensembl-dev mailing list:
ensembl-dev@ebi.ac.uk

=cut


# Think about adding "Rat -- Mouse deduced" and "Mouse -- Rat deduced"

use strict;

BEGIN { $| = 1;  
    use Test;
    plan tests => 64;
}

use Bio::EnsEMBL::Utils::Exception qw (warning verbose);
use Bio::EnsEMBL::Test::MultiTestDB;
use Bio::EnsEMBL::Test::TestUtils;
use Bio::EnsEMBL::Compara::GenomicAlignBlock;
use Bio::EnsEMBL::Compara::MethodLinkSpeciesSet;

# switch off the debug prints 
our $verbose = 0;

my $multi = Bio::EnsEMBL::Test::MultiTestDB->new( "multi" );
my $homo_sapiens = Bio::EnsEMBL::Test::MultiTestDB->new("homo_sapiens");
my $mus_musculus = Bio::EnsEMBL::Test::MultiTestDB->new("mus_musculus");
my $rattus_norvegicus = Bio::EnsEMBL::Test::MultiTestDB->new("rattus_norvegicus");

my $compara_db = $multi->get_DBAdaptor( "compara" );
  
my $genomic_align;
my $genomic_align_block;
my $all_genomic_aligns;
my $genomic_align_adaptor = $compara_db->get_GenomicAlignAdaptor();
my $dnafrag_adaptor = $compara_db->get_DnaFragAdaptor();
my $genomeDB_adaptor = $compara_db->get_GenomeDBAdaptor();


print "\nTest **DEPRECATED** functions:\n";
verbose(1000);

print "Test Bio::EnsEMBL::Compara::DBSQL::GenomicAlignAdaptor fetch_all_by_DnaFrag_GenomeDB method:";
  my $genomic_aligns = $genomic_align_adaptor->fetch_all_by_DnaFrag_GenomeDB(
          $dnafrag_adaptor->fetch_by_dbID(19),
          $genomeDB_adaptor->fetch_by_dbID(2),
          50000001,
          50001001,
          "BLASTZ_NET"
      );
  ok(@{$genomic_aligns}, scalar(2));

my $consensus_dnafrag = $dnafrag_adaptor->fetch_by_dbID(19);
my $consensus_start = 49999738;
my $consensus_end = 50000033;
my $query_dnafrag = $dnafrag_adaptor->fetch_by_dbID(34);
my $query_start = 66608068;
my $query_end = 66608528;
my $query_strand = 1;
my $alignment_type = "BLASTZ_NET";
my $score = 1849;
my $perc_id = 39;

debug "Test Bio::EnsEMBL::Compara::GenomicAlign new(OLD_PARAM) method:";
  $genomic_align = new Bio::EnsEMBL::Compara::GenomicAlign(
      -adaptor => $genomic_align_adaptor,
      -consensus_dnafrag => $consensus_dnafrag,
      -consensus_start => $consensus_start,
      -consensus_end => $consensus_end,
      -query_dnafrag => $query_dnafrag,
      -query_start => $query_start,
      -query_end => $query_end,
      -query_strand => $query_strand,
#       -alignment_type => $alignment_type,
      -score => $score,
      -perc_id => $perc_id
      );
  $genomic_align->{'_rootI_verbose'} = -1;
  ok($genomic_align->consensus_dnafrag, $consensus_dnafrag);
  ok($genomic_align->consensus_start, $consensus_start);
  ok($genomic_align->consensus_end, $consensus_end);
  ok($genomic_align->query_dnafrag, $query_dnafrag);
  ok($genomic_align->query_start, $query_start);
  ok($genomic_align->query_end, $query_end);
  ok($genomic_align->query_strand, $query_strand);
#   ok($genomic_align->alignment_type, $alignment_type);
  ok($genomic_align->score, $score);
  ok($genomic_align->perc_id, $perc_id);

my $gdba = $compara_db->get_GenomeDBAdaptor();

#######
#  1  #
#######
debug( "GenomeDBAdaptor exists" );
ok( defined $gdba );

#
# set the locators, we have to cheat because
# with the test dbs these are different every time
#

$compara_db->add_db_adaptor($homo_sapiens->get_DBAdaptor('core'));
$compara_db->add_db_adaptor($mus_musculus->get_DBAdaptor('core'));
$compara_db->add_db_adaptor($rattus_norvegicus->get_DBAdaptor('core'));


my $hum = $gdba->fetch_by_name_assembly( "Homo sapiens", 'NCBI34' );
my $mouse = $gdba->fetch_by_name_assembly( "Mus musculus", 'NCBIM32' );
my $rat = $gdba->fetch_by_name_assembly( "Rattus norvegicus", 'RGSC3.1' );



#######
#  2  #
#######
debug( "GenomeDBs for hum, mouse, rat exist" );
ok( defined $hum && defined $mouse && defined $rat );

my $dfa = $compara_db->get_DnaFragAdaptor();
my $hfrags = $dfa->fetch_all_by_GenomeDB_region( $hum, 'chromosome', "14" );
my $rfrags =  $dfa->fetch_all_by_GenomeDB_region( $rat, 'chromosome', "6" );

#######
#  3  #
#######
debug( "Human first dnafrag" );
#map { print_hashref( $_ ) } @$hfrags;
ok( scalar( @$hfrags ) == 1 );


my $gaa = $compara_db->get_GenomicAlignAdaptor();

debug( "Human -- Mouse direct alignments" );
my $aligns = $gaa->fetch_all_by_DnaFrag_GenomeDB( $hfrags->[0], $mouse , 50000000, 50250000,"BLASTZ_NET");
#map { print_hashref( $_ ) } @$aligns;
debug();

#######
#  4  #
#######
ok( scalar @$aligns == 255 );

my $mfrags = $dfa->fetch_all_by_GenomeDB_region( $mouse, 'chromosome', "12" );

debug( "Mouse -- Human reverse direct" );
$aligns = $gaa->fetch_all_by_DnaFrag_GenomeDB( $mfrags->[0], $hum, 66608000,66615600,"BLASTZ_NET" );
map { print_hashref( $_ ) } @$aligns;
debug();

#######
#  5  #
#######
ok( grep {$_->cigar_line() eq "32MI30M3D31M2D33M"} @$aligns );

debug( "Mouse -- Rat direct" );
$aligns = $gaa->fetch_all_by_DnaFrag_GenomeDB( $mfrags->[0], $hum, 66608000,66615600,"BLASTZ_NET" );
map { print_hashref( $_ ) } @$aligns;
debug();


debug( "Human -- Rat direct" );
$aligns = $gaa->fetch_all_by_DnaFrag_GenomeDB( $hfrags->[0], $rat, 50000000, 50250000,"BLASTZ_NET" );
map { print_hashref( $_ ) } @$aligns;
debug();

debug( "Rat -- Human direct" );
$aligns = $gaa->fetch_all_by_DnaFrag_GenomeDB( $rfrags->[0], $hum, 92842600, 92852150,"BLASTZ_NET" );
map { print_hashref( $_ ) } @$aligns;
debug();

# Think about adding "Rat -- Mouse deduced" and "Mouse -- Rat deduced"

#########
#  6-10  #
#########
ok( grep {$_->cigar_line eq "26M2D7M2I69M4D10MI55M10D5M16D16MD43M8D22M"} @$aligns);

ok( grep {$_->consensus_start == 92842620 && $_->consensus_end == 92842888 &&
	  $_->query_start == 49999812 && $_->query_end == 50000028 &&
	  $_->cigar_line eq '86M2I39M14D10MI34M7I6M12I15M44I13M'} @$aligns );

ok( grep {$_->consensus_start == 92852113 && $_->consensus_end == 92852234 &&
	  $_->query_start == 50006864 && $_->query_end == 50006989 &&
	  $_->cigar_line eq '27MI32M3D32M2D30M'} @$aligns );


#######
#  11  #
#######
ok( scalar @$aligns == 11 );

#######
#  12  #
#######
$multi->hide( "compara", "genomic_align_block" );
debug();
$gaa->store( $aligns );

my $sth = $gaa->prepare( "select count(*) from genomic_align_block" );
$sth->execute();
my ( $count ) = $sth->fetchrow_array();
$sth->finish();


if( $verbose ) {
  debug();
  $sth = $gaa->prepare( "select * from genomic_align_block" );
  $sth->execute();
  while( my $aref = $sth->fetchrow_arrayref() ) {
    debug( join( " ", @$aref ));
  }
  debug();
}

ok( $count == 11 );

sub print_hashref {
  my $hr = shift;
  
  my @keys = sort keys %$hr;
  map { debug( "  $_ ".$hr->{$_} ) } @keys;
  debug( );
}


exit 0;

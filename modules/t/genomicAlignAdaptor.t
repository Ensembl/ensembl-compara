use strict;
use warnings;

BEGIN { $| = 1;  
	use Test;
	plan tests => 10;
}

use Bio::EnsEMBL::Test::MultiTestDB;
use Bio::EnsEMBL::Test::TestUtils;

# switch on the debug prints
our $verbose = 0;

my $multi = Bio::EnsEMBL::Test::MultiTestDB->new( "multi" );
my $homo_sapiens = Bio::EnsEMBL::Test::MultiTestDB->new("homo_sapiens");
my $mus_musculus = Bio::EnsEMBL::Test::MultiTestDB->new("mus_musculus");
my $rattus_norvegicus = Bio::EnsEMBL::Test::MultiTestDB->new("rattus_norvegicus");


my $compara_db = $multi->get_DBAdaptor( "compara" );

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

my $hs_gdb = $gdba->fetch_by_name_assembly( "Homo sapiens", 'NCBI34' );
my $mm_gdb = $gdba->fetch_by_name_assembly( "Mus musculus", 'NCBIM32' );
my $rn_gdb = $gdba->fetch_by_name_assembly( "Rattus norvegicus", 'RGSC3.1' );

$hs_gdb->db_adaptor($homo_sapiens->get_DBAdaptor('core'));
$mm_gdb->db_adaptor($mus_musculus->get_DBAdaptor('core'));
$rn_gdb->db_adaptor($rattus_norvegicus->get_DBAdaptor('core'));

#######
#  2  #
#######
debug( "GenomeDBs for hum, mouse, rat exist" );
ok( defined $hs_gdb && defined $mm_gdb && defined $rn_gdb );

my $dfa = $compara_db->get_DnaFragAdaptor();
my $hfrags = $dfa->fetch_all_by_GenomeDB_region( $hs_gdb, 'chromosome', "14" );
my $rfrags =  $dfa->fetch_all_by_GenomeDB_region( $rn_gdb, 'chromosome', "6" );

#######
#  3  #
#######
debug( "Human first dnafrag" );
#map { print_hashref( $_ ) } @$hfrags;
ok( scalar( @$hfrags ) == 1 );


my $gaa = $compara_db->get_GenomicAlignAdaptor();

debug( "Human -- Mouse direct alignments" );
my $aligns = $gaa->fetch_all_by_DnaFrag_GenomeDB( $hfrags->[0], $mm_gdb , 50000000, 50250000,"BLASTZ_NET");
#map { print_hashref( $_ ) } @$aligns;
debug();

#######
#  4  #
#######
ok( scalar @$aligns == 255 );

my $mfrags = $dfa->fetch_all_by_GenomeDB_region( $mm_gdb, 'chromosome', "12" );

debug( "Mouse -- Human reverse direct" );
$aligns = $gaa->fetch_all_by_DnaFrag_GenomeDB( $mfrags->[0], $hs_gdb, 66608000,66615600,"BLASTZ_NET" );
map { print_hashref( $_ ) } @$aligns;
debug();

#######
#  5  #
#######
ok( grep {$_->cigar_line() eq "32MI30M3D31M2D33M"} @$aligns );

debug( "Mouse -- Rat direct" );
$aligns = $gaa->fetch_all_by_DnaFrag_GenomeDB( $mfrags->[0], $hs_gdb, 66608000,66615600,"BLASTZ_NET" );
map { print_hashref( $_ ) } @$aligns;
debug();


debug( "Human -- Rat direct" );
$aligns = $gaa->fetch_all_by_DnaFrag_GenomeDB( $hfrags->[0], $rn_gdb, 50000000, 50250000,"BLASTZ_NET" );
map { print_hashref( $_ ) } @$aligns;
debug();

debug( "Rat -- Human direct" );
$aligns = $gaa->fetch_all_by_DnaFrag_GenomeDB( $rfrags->[0], $hs_gdb, 92842600, 92852150,"BLASTZ_NET" );
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




    

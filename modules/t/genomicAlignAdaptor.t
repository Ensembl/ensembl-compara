use lib 't';
use strict;
use warnings;

BEGIN { $| = 1;  
	use Test;
	plan tests => 12;
}

use MultiTestDB;
use TestUtils;
use Bio::EnsEMBL::Compara::DBSQL::GenomicAlignAdaptor;

# switch on the debug prints
our $verbose = 1;

my $multi = MultiTestDB->new( "multi" );
my $homo_sapiens = MultiTestDB->new("homo_sapiens");
my $mus_musculus = MultiTestDB->new("mus_musculus");
my $rattus_norvegicus = MultiTestDB->new("rattus_norvegicus");


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
my $rfrags =  $dfa->fetch_all_by_GenomeDB_region( $rat, 'chromosome', "11" );

#######
#  3  #
#######
debug( "Human first dnafrag" );
map { print_hashref( $_ ) } @$hfrags;
ok( scalar( @$hfrags ) == 1 );


my $gaa = $compara_db->get_GenomicAlignAdaptor();

debug( "Human -- Mouse direct alignments" );
my $aligns = $gaa->fetch_all_by_DnaFrag_GenomeDB( $hfrags->[0], $mouse , 50000000, 50250000,"BLASTZ_NET");
map { print_hashref( $_ ) } @$aligns;
debug();

#######
#  4  #
#######
debug(scalar @$aligns);
ok( scalar @$aligns == 2 );

my $mfrags = $dfa->fetch_all_by_GenomeDB_region( $mouse, 'chromosome', "12" );

debug( "Mouse -- Human reverse direct" );
$aligns = $gaa->fetch_all_by_DnaFrag_GenomeDB( $mfrags->[0], $hum, 66608000,66615600,"BLASTZ_NET" );
map { print_hashref( $_ ) } @$aligns;
debug();

#######
#  5  #
#######
ok( grep {$_->cigar_line() eq "19MD30M"} @$aligns );

debug( "Mouse -- Rat direct" );
$aligns = $gaa->fetch_all_by_DnaFrag_GenomeDB( $mfrags->[0], $hum, 66608000,66615600,"BLASTZ_NET" );
map { print_hashref( $_ ) } @$aligns;
debug();


debug( "Human -- Rat deduced" );
$aligns = $gaa->fetch_all_by_DnaFrag_GenomeDB( $hfrags->[0], $rat, , 50000000, 50250000,"BLASTZ_NET" );
map { print_hashref( $_ ) } @$aligns;
debug();

debug( "Rat -- Human deduced" );
$aligns = $gaa->fetch_all_by_DnaFrag_GenomeDB( $rfrags->[0], $hum, 18379900, 18380100,"BLASTZ_NET" );
map { print_hashref( $_ ) } @$aligns;
debug();


#########
#  6-10  #
#########
ok( grep {$_->cigar_line eq "26MD3MD2M2D5M3I10M"} @$aligns);
ok( grep {$_->cigar_line eq "19MD21M"} @$aligns);

ok( grep {$_->consensus_start == 320 && $_->consensus_end == 327 &&
	  $_->query_start == 202 && $_->query_end == 209 &&
	  $_->cigar_line eq '8M'} @$aligns );

ok( grep {$_->consensus_start == 330 && $_->consensus_end == 332 &&
	  $_->query_start == 212 && $_->query_end == 214 &&
	  $_->cigar_line eq '3M'} @$aligns );

ok( grep {$_->consensus_start == 336 && $_->consensus_end == 338 &&
	  $_->query_start == 218 && $_->query_end == 220 &&
	  $_->cigar_line eq '3M'} @$aligns );


#######
#  11  #
#######
ok( scalar @$aligns == 5 );


#######
#  12  #
#######
$multi->hide( "compara", "genomic_align_block" );
$gaa->store( $aligns );

my $sth = $gaa->prepare( "select count(*) from genomic_align_block" );
$sth->execute();
my ( $count ) = $sth->fetchrow_array();
$sth->finish();


if( $verbose ) {
  $sth = $gaa->prepare( "select * from genomic_align_block" );
  $sth->execute();
  while( my $aref = $sth->fetchrow_arrayref() ) {
    debug( join( " ", @$aref ));
  }
  debug();
}

ok( $count == 5 );



sub print_hashref {
  my $hr = shift;
  
  my @keys = sort keys %$hr;
  map { debug( "  $_ ".$hr->{$_} ) } @keys;
  debug( );
}




    

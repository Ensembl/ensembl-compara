use lib 't';
use strict;
use warnings;

BEGIN { $| = 1;  
	use Test;
	plan tests => 7;
}

use MultiTestDB;
use TestUtils qw ( debug test_getter_setter );

use Bio::EnsEMBL::Compara::DBSQL::GenomicAlignAdaptor;

# switch on the debug prints

our $verbose = 1;

my $multi = MultiTestDB->new( "multi" );
my $compara_db = $multi->get_DBAdaptor( "compara" );

my $gdba = $compara_db->get_GenomeDBAdaptor();

#######
#  1  #
#######
debug( "GenomeDBAdaptor exists" );
ok( defined $gdba );

my $hum = $gdba->fetch_by_species_tag( "Homo_sapiens" );
my $mouse = $gdba->fetch_by_species_tag( "Mus_musculus" );
my $rat = $gdba->fetch_by_species_tag( "Rattus_norvegicus" );


#
# set the locators, we have to cheat because
# with the test dbs these are different every time
#
my $homo_sapiens = MultiTestDB->new("homo_sapiens");
my $mus_musculus = MultiTestDB->new("mus_musculus");

my $hs = $homo_sapiens->get_DBAdaptor('core');
my $mm = $mus_musculus->get_DBAdaptor('core');

my $loc = ref($hs->_obj)."/host=".$hs->host.";port=".$hs->port.";dbname=".
  $hs->dbname.";user=".$hs->username.";pass=".$hs->password;
$hum->locator($loc);

$loc = ref($mm->_obj)."/host=".$mm->host.";port=".$mm->port.";dbname=".
  $mm->dbname.";user=".$mm->username.";pass=".$mm->password;

#######
#  2  #
#######
debug( "GenomeDBs for hum, mouse, rat exist" );
ok( defined $hum && defined $mouse && defined $rat );

my $dfa = $compara_db->get_DnaFragAdaptor();
my $hfrags = $dfa->fetch_all_by_GenomeDB_region( $hum, 'Chromosome', "X" );


#######
#  3  #
#######
debug( "Human first dnafrag" );
map { print_hashref( $_ ) } @$hfrags;
ok( scalar( @$hfrags ) == 1 );


my $gaa = $compara_db->get_GenomicAlignAdaptor();

debug( "Human -- Mouse direct alignments" );
my $aligns = $gaa->fetch_all_by_dnafrag_genomedb( $hfrags->[0], $mouse );
map { print_hashref( $_ ) } @$aligns;
debug();

#######
#  4  #
#######
ok( scalar @$aligns == 1 );

my $mfrags = $dfa->fetch_all_by_GenomeDB_region( $mouse, 'Chromosome', "X" );

debug( "Mouse -- Human reverse direct" );
$aligns = $gaa->fetch_all_by_dnafrag_genomedb( $mfrags->[0], $hum );
map { print_hashref( $_ ) } @$aligns;
debug();

#######
#  5  #
#######
ok( $aligns->[0]->cigar_line() eq "19MD30M" );

debug( "Mouse -- Rat direct" );
$aligns = $gaa->fetch_all_by_dnafrag_genomedb( $mfrags->[0], $hum );
map { print_hashref( $_ ) } @$aligns;
debug();


debug( "Human -- Rat deduced" );
$aligns = $gaa->fetch_all_by_dnafrag_genomedb( $hfrags->[0], $rat );
map { print_hashref( $_ ) } @$aligns;
debug();


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

#######
#  6  #
#######
ok( $count == 2 );



sub print_hashref {
  my $hr = shift;
  
  my @keys = sort keys %$hr;
  map { debug( "  $_ ".$hr->{$_} ) } @keys;
  debug( );
}


#######
#  7  #
#######
ok( scalar @$aligns == 2 );

    

use lib 't';
use strict;
use warnings;

BEGIN { $| = 1;  
	use Test;
	plan tests => 6;
}

use MultiTestDB;
use TestUtils qw ( debug test_getter_setter );

use Bio::EnsEMBL::Compara::DBSQL::GenomicAlignAdaptor;

# switch on the debug prints

our $verbose = 0;

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


#######
#  2  #
#######
debug( "GenomeDBs for hum, mouse, rat exist" );
ok( defined $hum && defined $mouse && defined $rat );

my $dfa = $compara_db->get_DnaFragAdaptor();
my $hfrags = $dfa->fetch_all_by_genomedb_position( $hum, "X" );


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

my $mfrags = $dfa->fetch_all_by_genomedb_position( $mouse, "X" );

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



sub print_hashref {
  my $hr = shift;
  
  my @keys = sort keys %$hr;
  map { debug( "  $_ ".$hr->{$_} ) } @keys;
  debug( );
}


#######
#  6  #
#######
ok( scalar @$aligns == 2 );

    

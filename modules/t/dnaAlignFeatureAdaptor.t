use strict;
use warnings;

use lib 't';
use MultiTestDB;
use TestUtils qw(debug test_getter_setter);

BEGIN {
  $| = 1;
  use Test;
  plan tests => 6;
}


#set to 1 to turn on debug prints
our $verbose = 1;


my $CHR   = 'X';
my $START = 400_000;
my $END   = 500_000;

my $multi = MultiTestDB->new('multi');


my $homo_sapiens = MultiTestDB->new("homo_sapiens");
my $mus_musculus = MultiTestDB->new("mus_musculus");
my $rattus_norvegicus = MultiTestDB->new("rattus_norvegicus");


my $hs_db = $homo_sapiens->get_DBAdaptor('core');
my $mm_db = $mus_musculus->get_DBAdaptor('core');
my $rn_db = $rattus_norvegicus->get_DBAdaptor('core');
my $compara_db = $multi->get_DBAdaptor('compara');

#
# update the locators in the compara database
#
my $sth = 
  $compara_db->prepare('UPDATE genome_db SET locator = ? WHERE name = ?');
$sth->execute($hs_db->locator, 'Homo_sapiens');
$sth->execute($mm_db->locator, 'Mus_musculus');
$sth->execute($rn_db->locator, 'Rattus_norvegicus');




my $dafa = $compara_db->get_DnaAlignFeatureAdaptor;


#######
#  1  #
#######

my $slice = $hs_db->get_SliceAdaptor->fetch_by_chr_start_end($CHR,$START,$END);
my $mouse_matches = $dafa->fetch_all_by_Slice($slice, 'mus_musculus');


my $num = scalar(@$mouse_matches);
ok($num);
debug("got $num human-mouse matches\n");

$verbose && &print_matches($mouse_matches);


#######
#  2  #
#######

$slice = $mm_db->get_SliceAdaptor->fetch_by_chr_start_end($CHR, $START, $END);
my $human_matches = $dafa->fetch_all_by_Slice($slice, 'homo_sapiens');

$num = scalar(@$human_matches);
ok($num);

debug("got $num mouse-human matches\n");
$verbose && &print_matches($human_matches);


#######
#  3  #
#######

my $rat_matches = $dafa->fetch_all_by_Slice($slice, 'rattus_norvegicus');
$num = scalar(@$rat_matches);
ok($num);

debug("got $num mouse-rat matches\n");
$verbose && &print_matches($rat_matches);

#######
#  4  #
#######

$slice = $rn_db->get_SliceAdaptor->fetch_by_chr_start_end($CHR, $START, $END);
$mouse_matches = $dafa->fetch_all_by_Slice($slice, 'mus_musculus');
$num = scalar(@$mouse_matches);

debug("got $num rat-mouse matches\n");
$verbose && &print_matches($mouse_matches);


#######
#  5  #
#######

#
# transitive alignment...
#
$slice = $hs_db->get_SliceAdaptor->fetch_by_chr_start_end($CHR,$START,$END);
$rat_matches = $dafa->fetch_all_by_Slice($slice, 'rattus_norvegicus');
$num = scalar(@$rat_matches);

debug("got $num human-rat matches\n");
$verbose && &print_matches($rat_matches);

#######
#  6  #
#######

#
# reverse-transitive alignment
#

$slice = $rn_db->get_SliceAdaptor->fetch_by_chr_start_end($CHR, $START, $END);
$human_matches = $dafa->fetch_all_by_Slice($slice, 'homo_sapiens');
$num = scalar(@$human_matches);

debug("got $num rat-human matches\n");
$verbose && &print_matches($human_matches);

  

###############################################################################

sub print_matches {
  my $matches = shift;

  foreach my $match (@$matches) {
    debug($match->start . "-" . $match->end . ":" . 
	  $match->cigar_string . "\n");
  }
}


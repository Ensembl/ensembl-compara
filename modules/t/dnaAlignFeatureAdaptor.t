use strict;
use warnings;

use Bio::EnsEMBL::Test::MultiTestDB;
use Bio::EnsEMBL::Test::TestUtils qw(debug test_getter_setter);

BEGIN {
  $| = 1;
  use Test;
  plan tests => 6;
}

#set to 1 to turn on debug prints
our $verbose = 0;


my $CHR   = '19';
my $START = 50_000_000;
my $END   = 50_250_000;

my $multi = Bio::EnsEMBL::Test::MultiTestDB->new('multi');


my $homo_sapiens = Bio::EnsEMBL::Test::MultiTestDB->new("homo_sapiens");
my $mus_musculus = Bio::EnsEMBL::Test::MultiTestDB->new("mus_musculus");
my $rattus_norvegicus = Bio::EnsEMBL::Test::MultiTestDB->new("rattus_norvegicus");


my $hs_dba = $homo_sapiens->get_DBAdaptor('core');
my $mm_dba = $mus_musculus->get_DBAdaptor('core');
my $rn_dba = $rattus_norvegicus->get_DBAdaptor('core');
my $compara_dba = $multi->get_DBAdaptor('compara');

$compara_dba->add_db_adaptor($hs_dba);
$compara_dba->add_db_adaptor($mm_dba);
$compara_dba->add_db_adaptor($rn_dba);

my $mouse_name     = $mm_dba->get_MetaContainer->get_Species->binomial;
my $mouse_assembly = $mm_dba->get_CoordSystemAdaptor->fetch_all->[0]->version;
my $human_name     = $hs_dba->get_MetaContainer->get_Species->binomial;
my $human_assembly = $hs_dba->get_CoordSystemAdaptor->fetch_all->[0]->version;
my $rat_name       = $rn_dba->get_MetaContainer->get_Species->binomial;
my $rat_assembly   = $rn_dba->get_CoordSystemAdaptor->fetch_all->[0]->version;

my $dafa = $compara_dba->get_DnaAlignFeatureAdaptor;


#######
#  1  #
#######

my $slice = $hs_dba->get_SliceAdaptor->fetch_by_region('toplevel',14,50000010,50249000);
my $mouse_matches = 
	$dafa->fetch_all_by_Slice($slice, $mouse_name, $mouse_assembly, "BLASTZ_NET");


my $num = scalar(@$mouse_matches);
ok($num == 255);
debug("\ngot $num human-mouse matches\n");

$verbose && &print_matches($mouse_matches);


#######
#  2  #
#######

$slice = $mm_dba->get_SliceAdaptor->fetch_by_region('toplevel',12,66608000,66615600);
my $human_matches = 
	$dafa->fetch_all_by_Slice($slice, $human_name, $human_assembly, "BLASTZ_NET");

$num = scalar(@$human_matches);
ok($num == 10);

debug("\ngot $num mouse-human matches\n");
$verbose && &print_matches($human_matches);


#######
#  3  #
#######

my $rat_matches = $dafa->fetch_all_by_Slice($slice, $rat_name, $rat_assembly, "BLASTZ_NET");
$num = scalar(@$rat_matches);

ok($num == 56);

debug("\ngot $num mouse-rat matches\n");
$verbose && &print_matches($rat_matches);

#######
#  4  #
#######

$slice = $rn_dba->get_SliceAdaptor->fetch_by_region('toplevel',6,92842600, 92852150);
$mouse_matches = 
	$dafa->fetch_all_by_Slice($slice, $mouse_name, $mouse_assembly, "BLASTZ_NET");
$num = scalar(@$mouse_matches);

ok($num == 54);
debug("\ngot $num rat-mouse matches\n");
$verbose && &print_matches($mouse_matches);


#######
#  5  #
#######

#
# transitive alignment...
#
$slice = $hs_dba->get_SliceAdaptor->fetch_by_region('toplevel',14,50000010,50249000);
$rat_matches = $dafa->fetch_all_by_Slice($slice, $rat_name, $rat_assembly,"BLASTZ_NET");
$num = scalar(@$rat_matches);

ok($num == 281);
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

ok($num == 11);
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



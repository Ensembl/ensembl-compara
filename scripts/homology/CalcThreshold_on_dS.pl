#!/usr/local/ensembl/bin/perl -w

use strict;
use Bio::EnsEMBL::Registry;
use Statistics::Descriptive;

my $dbname = shift;

Bio::EnsEMBL::Registry->load_all();

my $dbc = Bio::EnsEMBL::Registry->get_DBAdaptor($dbname, 'compara')->dbc;

my $sql = "select distinct mls.method_link_species_set_id from method_link_species_set mls, method_link ml where mls.method_link_id=ml.method_link_id and ml.type='ENSEMBL_ORTHOLOGUES'";

my $sth = $dbc->prepare($sql);
$sth->execute;
my $method_link_species_set_id;
$sth->bind_columns(\$method_link_species_set_id);

$sql = "select ds from homology where method_link_species_set_id = ? and ds is not NULL";
my $sth2 = $dbc->prepare($sql);

$sql = "update homology set threshold_on_ds = ? where method_link_species_set_id = ?";
my $sth3 = $dbc->prepare($sql);

while ($sth->fetch) {
#  print $method_link_species_set_id,"\n";
  $sth2->execute($method_link_species_set_id);
  my $stats = new Statistics::Descriptive::Full;
  my $dS;
  $sth2->bind_columns(\$dS);
  my $count = 0;
  while ($sth2->fetch) {
#    print $dS,"\n";
    $stats->add_data($dS);
    $count++;
  }
  if ($count) {
    my $median = $stats->median;
    print $method_link_species_set_id,"\t",$median,"\t",2*$median;
    $sth3->execute(2*$median,$method_link_species_set_id);
    print " stored\n";
  }
}

$sth3->finish;
$sth2->finish;
$sth->finish;

#!/usr/bin/env perl

use strict;
use warnings;
use Getopt::Long;
use Bio::EnsEMBL::Compara::DBSQL::DBAdaptor;

my ($method_link_species_set_id, $method_link_id);
my ($source_compara_url, $destination_compara_url);

GetOptions('method_link_species_set_id=i' => \$method_link_species_set_id,
           'method_link_id=i' => \$method_link_id,
           'source=s' => \$source_compara_url,
           'destination=s' => \$destination_compara_url,
);

unless (defined $source_compara_url and defined $destination_compara_url) {
  print STDERR ("You need to specify the source and destination Compara URLs\n");
  exit 1;
}

unless (defined $method_link_id || defined $method_link_species_set_id) {
  print STDERR "You need to define --method_link_id or --method_link_species_set_id\n";
  exit 2;
}

if (defined $method_link_id && defined $method_link_species_set_id) {
  print STDERR "You need to define either --method_link_id OR --method_link_species_set_id not both\n";
  exit 3;
}

my $source_dba      = Bio::EnsEMBL::Compara::DBSQL::DBAdaptor->new(-url => $source_compara_url);
my $destination_dba = Bio::EnsEMBL::Compara::DBSQL::DBAdaptor->new(-url => $destination_compara_url);

my $source_mlssa = $source_dba->get_MethodLinkSpeciesSetAdaptor;
my $source_mla   = $source_dba->get_MethodAdaptor;
my $source_ha    = $source_dba->get_HomologyAdaptor;
my $source_ma    = $source_dba->get_MemberAdaptor;

my $destination_mlssa = $destination_dba->get_MethodLinkSpeciesSetAdaptor;
my $destination_ha    = $destination_dba->get_HomologyAdaptor;
my $destination_ma    = $destination_dba->get_MemberAdaptor;

my $mlss_aref;

if (defined $method_link_id) {
  my $method_link_type = $source_mla->fetch_by_dbID($method_link_id)->type();
  $mlss_aref = $source_mlssa->fetch_all_by_method_link_type($method_link_type);
} elsif (defined $method_link_species_set_id) {
  $mlss_aref = [ $source_mlssa->fetch_by_dbID($method_link_species_set_id) ];
}

print "There is ",scalar @{$mlss_aref}," homology set(s) to tranfer\n";

my $nb_homologies = 0;
my $nb_homologies_loaded = 0;

foreach my $mlss (@{$mlss_aref}) {
  my $homologies = $source_ha->fetch_all_by_MethodLinkSpeciesSet($mlss);

  $mlss->adaptor(undef);
  $mlss->dbID(undef);
  $destination_mlssa->store($mlss);

  $nb_homologies += scalar @{$homologies};
  foreach my $homology (@{$homologies}) {
    $homology->method_link_species_set($mlss);
    print "fetching old homology ",$homology->dbID,"\n";
    my $store = 1;
    foreach my $member (@{$homology->get_all_Members}) {

      my $destination_member = $destination_ma->fetch_by_source_stable_id($member->source_name,$member->stable_id);
      if (defined $destination_member->dbID) {
        $member->dbID($destination_member->dbID);
      } else {
        $store = 0;
        print "member not in db ",$member->source_name,"\n";
      }
    }
    if ($store) {
      print "Loading new homology\n";
      $nb_homologies_loaded++;
      $homology->adaptor(undef);
      $homology->dbID(undef);
      $destination_ha->store($homology);
      if (defined $homology->n) {
        $destination_ha->update_genetic_distance($homology);
      }
    } else {
      print "Homology not loaded ",$homology->dbID,"\n";
    }
  }
}
print "nb_homologies: ",$nb_homologies,"\n";
print "nb_homologies_loaded: ",$nb_homologies_loaded,"\n";


exit 0;

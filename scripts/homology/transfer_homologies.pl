#!/usr/local/ensembl/bin/perl -w

use strict;
use Getopt::Long;
use Bio::EnsEMBL::Registry;

my ($method_link_species_set_id, $method_link_id, $reg_conf);

GetOptions('method_link_species_set_id=i' => \$method_link_species_set_id,
           'method_link_id=i' => \$method_link_id,
           'reg_conf=s' => \$reg_conf);

Bio::EnsEMBL::Registry->load_all($reg_conf);

unless (defined $reg_conf) {
  print STDERR ("You need to specify a registry file with --reg_conf");
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

my $source_mlssa =  Bio::EnsEMBL::Registry->get_adaptor('source_compara','compara','MethodLinkSpeciesSet');
my $source_ha =  Bio::EnsEMBL::Registry->get_adaptor('source_compara','compara','Homology');
my $source_ma =  Bio::EnsEMBL::Registry->get_adaptor('source_compara','compara','Member');

my $destination_mlssa =  Bio::EnsEMBL::Registry->get_adaptor('destination_compara','compara','MethodLinkSpeciesSet');
my $destination_ha =  Bio::EnsEMBL::Registry->get_adaptor('destination_compara','compara','Homology');
my $destination_ma =  Bio::EnsEMBL::Registry->get_adaptor('destination_compara','compara','Member');

my $mlss_aref;

if (defined $method_link_id) {
  my $method_link_type = $source_mlssa->get_method_link_type_from_method_link_id($method_link_id);
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
    foreach my $member_attribute (@{$homology->get_all_Member_Attribute}) {
      my ($member, $attribute) = @{$member_attribute};
      my $peptide_member = $source_ma->fetch_by_dbID($attribute->peptide_member_id);

      my $destination_peptide_member = $destination_ma->fetch_by_source_stable_id($peptide_member->source_name,$peptide_member->stable_id);
      my $destination_member = $destination_ma->fetch_by_source_stable_id($member->source_name,$member->stable_id);
      if (defined $destination_member->dbID) {
        $member->dbID($destination_member->dbID);
        $attribute->peptide_member_id($destination_peptide_member->dbID);
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

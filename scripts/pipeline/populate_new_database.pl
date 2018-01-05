#!/usr/bin/env perl
# Copyright [1999-2015] Wellcome Trust Sanger Institute and the EMBL-European Bioinformatics Institute
# Copyright [2016-2018] EMBL-European Bioinformatics Institute
# 
# Licensed under the Apache License, Version 2.0 (the "License");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at
# 
#      http://www.apache.org/licenses/LICENSE-2.0
# 
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.


use warnings;
use strict;

my $description = q{
###########################################################################
##
## PROGRAM populate_new_database.pl
##
## AUTHORS
##    Javier Herrero
##
## DESCRIPTION
##    This script creates a new database based on the default assemblies
##    in a master database a previous data in an old database.
##
###########################################################################

};

=head1 NAME

populate_new_database.pl

=head1 AUTHORS

 Javier Herrero

=head1 CONTACT

Please email comments or questions to the public Ensembl
developers list at <http://lists.ensembl.org/mailman/listinfo/dev>.

Questions may also be sent to the Ensembl help desk at
<http://www.ensembl.org/Help/Contact>.

=head1 DESCRIPTION

This script populates a new database based on the default assemblies
in a master database a previous data in an old database.

This script does not store the homology/family data as these are completely
rebuild for each release. Only the relevant DNA-DNA alignments and syntenic
regions are copied from the old database.

=head1 SYNOPSIS

perl populate_new_database.pl --help

perl populate_new_database.pl
    [--reg-conf registry_configuration_file]
    [--skip-data]
    --master master_database_name
    --old new_database_name
    --new new_database_name
    [--species human --species mouse...]
    [--mlss 123 --mlss 321]

perl populate_new_database.pl
    [--skip-data]
    --master mysql://user@host/master_db_name
    [--old mysql://user@host/old_db_name]
    --new mysql://user@host/new_db_name
    [--species human --species mouse...]
    [--mlss 123 --mlss 321]

=head1 REQUIREMENTS

This script uses mysql, mysqldump and mysqlimport programs.
It requires at least version 4.1.12 of mysqldump as it uses
the --insert-ignore option.

=head1 ARGUMENTS

=head2 GETTING HELP

=over

=item B<[--help]>

  Prints help message and exits.

=back

=head2 DATABASES

=over

=item B<--master master_compara_db_name>

The master compara database. You can use either the original name or any of the
aliases given in the registry_configuration_file. DEFAULT VALUE: compara_master

Alternatively, you can use an URL for the MySQL database. The URL format is:
mysql://username[:passwd]@host[:port]/db_name

=item B<--old old_compara_db_name>

The old compara database. You can use either the original name or any of the
aliases given in the registry_configuration_file.

Alternatively, you can use an URL for the MySQL database. The URL format is:
mysql://username[:passwd]@host[:port]/db_name

=item B<--new new_compara_db_name>

The new compara database. You can use either the original name or any of the
aliases given in the registry_configuration_file.

Alternatively, you can use an URL for the MySQL database. The URL format is:
mysql://username[:passwd]@host[:port]/db_name

=back

=head2 GENERAL OPTIONS

=over

=item B<[--reg_conf registry_configuration_file]>

The Bio::EnsEMBL::Registry configuration file. If none given,
the one set in ENSEMBL_REGISTRY will be used if defined, if not
~/.ensembl_init will be used.

=back

=head2 DATA

=over

=item B<[--species "Species name"]>

Copy data for this species only. This option can be used several times in order to restrict
the copy to several species.

=item B<[--mlss MLSS_id]>

Copy data for this method-link-species-set only. This option can be used several times in order to restrict
the copy to several MLSS_ids.

=item B<[--collection "Collection name"]>

Copy data for the species of that collection only. This option supersedes --species

=item B<[--[no]skip-data]>

Do not store DNA-DNA alignments nor synteny data.

=item B<--exact_species_name_match>

Used to control the algorithm used to search for species with. Normally a fuzzy
match is allowed letting you give partial species names e.g. homo and still
retrieve the correct species. A more version requiring direct equality
can be turned on if needed & is necessary when working with very closely related
species i.e. strains.

=item B<--filter_by_mlss>

Mainly used by Ensembl Genomes.
This option triggers a copy of genomic_align(_block) based on the method_link_species_set_id
instead of the range of genomic_align_id

=back

=head2 OLD DATA

Sometimes, some alignments are dropped from one release to the other. In order to avoid copying
these data, this script reads the "last_release" fields and skip the related entries (genome_db,
species_set, and method_link_species_set)

=cut

use Bio::EnsEMBL::Compara::DBSQL::DBAdaptor;
use Bio::EnsEMBL::Registry;
use Bio::EnsEMBL::Utils::Exception qw(throw warning);
use Bio::EnsEMBL::Utils::Scalar qw(:assert);
use Bio::EnsEMBL::Compara::Utils::CopyData qw(:table_copy);
use Getopt::Long;
use Data::Dumper;

my $help;

my $reg_conf;
my $skip_data = 0;
my $master = "compara_master";
my $old = undef;
my $new = undef;
my $species = [];
my $mlsss = [];
my $exact_species_name_match = 0;
my $only_show_intentions = 0;
my $cellular_component = 0;
my $collection = undef;
my $filter_by_mlss = 0;
my $alignments_only = 0;

GetOptions(
    "help" => \$help,
    "skip-data" => \$skip_data,
    "reg-conf=s" => \$reg_conf,
    "master=s" => \$master,
    "old=s" => \$old,
    "new=s" => \$new,
    "species=s@" => $species,
    "mlss|method_link_species_sets=s@" => $mlsss,
    'exact_species_name_match' => \$exact_species_name_match,
    'n|intentions' => \$only_show_intentions,
    'cellular_component=i' => \$cellular_component,
    'collection=s' => \$collection,
    'filter_by_mlss' => \$filter_by_mlss,
    'alignments_only' => \$alignments_only,
  );


# Print Help and exit if help is requested
if ($help or !$master or !$new) {
  exec("/usr/bin/env perldoc $0");
}

my %methods_to_skip = map {$_=>1} qw(ENSEMBL_ORTHOLOGUES ENSEMBL_PARALOGUES ENSEMBL_HOMOEOLOGUES);

#################################################
## Get the DBAdaptors from the Registry
Bio::EnsEMBL::Registry->load_all($reg_conf, "verbose", 0, 0, "throw_if_missing") if $reg_conf;

my $master_dba;
if ($master =~ /mysql:\/\//) {
  $master_dba = new Bio::EnsEMBL::Compara::DBSQL::DBAdaptor(-url=>$master);
} else {
  $master_dba = Bio::EnsEMBL::Registry->get_DBAdaptor($master, "compara");
}
die "Cannot connect to master compara database: $master\n" if (!$master_dba);
$master_dba->get_MetaContainer; # tests that the DB exists

my $old_dba;
if ($old) {
  if ($old =~ /mysql:\/\//) {
    $old_dba = new Bio::EnsEMBL::Compara::DBSQL::DBAdaptor(-url=>$old);
  } else {
    $old_dba = Bio::EnsEMBL::Registry->get_DBAdaptor($old, "compara");
  }
  die "Cannot connect to old compara database: $old\n" if (!$old_dba);
  $old_dba->get_MetaContainer; # tests that the DB exists
}

my $new_dba;
if ($new =~ /mysql:\/\//) {
  $new_dba = new Bio::EnsEMBL::Compara::DBSQL::DBAdaptor(-url=>$new);
} else {
  $new_dba = Bio::EnsEMBL::Registry->get_DBAdaptor($new, "compara");
}
die "Cannot connect to new compara database: $new\n" if (!$new_dba);
$new_dba->get_MetaContainer; # tests that the DB exists
#
################################################


#Allow species to be specified as either --species spp1 --species spp2 --species spp3 or --species spp1,spp2,spp3
@$species = split(/,/, join(',', @$species));

#Allow method_link_species_sets to be specified as either --mlss mlss1 --mlss mlss2 --mlss mlss3 or --mlss mlss1,mlss2,mlss3
@$mlsss = split(/,/, join(',', @$mlsss));

# If neither --collection nor --mlss is given, only take current species
my $filter_current = ($collection or scalar(@$mlsss)) ? 0 : 1;

## Get all the genome_dbs with a default assembly
my $all_default_genome_dbs = get_all_default_genome_dbs($master_dba, $species, $mlsss, $collection);

## Get all the MethodLinkSpeciesSet for the default assemblies
my $all_default_method_link_species_sets = get_all_method_link_species_sets($master_dba, $all_default_genome_dbs, $mlsss);

## Get all the SpeciesSets with tags for the default assemblies
my $all_default_species_sets = get_all_species_sets_with_tags($master_dba, $all_default_genome_dbs, $mlsss);

if($only_show_intentions) {
    print "GenomeDB entries to be copied:\n";
    foreach my $genome_db (@$all_default_genome_dbs) {
        print "\t".$genome_db->dbID.": ".$genome_db->_get_unique_name."\n";
    }
    print "MethodLinkSpeciesSet entries to be copied:\n";
    my %counts;
    foreach my $mlss (sort {$a->method->dbID <=> $b->method->dbID} @$all_default_method_link_species_sets) {
        $counts{$mlss->method->type}++;
        print "\t".$mlss->dbID.": ".$mlss->name."\n";
    }
    print "Additional SpeciesSet entries to be copied:\n";
    foreach my $ss (@$all_default_species_sets) {
        print "\t".$ss->dbID.": ".join(', ', map { $_->_get_unique_name} @{$ss->genome_dbs})."\n";
    }
    print "\nSummary:\n";
    print "\t", scalar(@$all_default_genome_dbs), " GenomeDBs\n";
    print "\t", scalar(@$all_default_method_link_species_sets), " MethodLinkSpeciesSets\n";
    printf("\t\t%5d %s\n", $counts{$_}, $_) for sort keys %counts;
    print "\t", scalar(@$all_default_species_sets), " SpeciesSets\n";
    exit 0;
}

## Sets the schema version for the new database
update_schema_version($master_dba, $new_dba);

## Copy taxa and method_link tables
print "Copying taxa and method_link tables...\n";
copy_table($master_dba->dbc, $new_dba->dbc, "ncbi_taxa_node");
copy_table($master_dba->dbc, $new_dba->dbc, "ncbi_taxa_name");
copy_table($master_dba->dbc, $new_dba->dbc, "method_link");

## Store all the genome_dbs in the new DB
store_objects($new_dba->get_GenomeDBAdaptor, $all_default_genome_dbs,
    @$species?"default genome_dbs for ".join(", ", @$species):"all default genome_dbs");

## Store all the MethodLinkSpeciesSet entries in the new DB
store_objects($new_dba->get_MethodLinkSpeciesSetAdaptor, $all_default_method_link_species_sets,
    "all previous valid method_link_species_sets");

## Store all the SpeciesSets with tags in the new DB
store_objects($new_dba->get_SpeciesSetAdaptor, $all_default_species_sets,
    "all previous valid species_sets");

## Copy all the DnaFrags for the default assemblies

copy_all_dnafrags($master_dba, $new_dba, $all_default_genome_dbs, $cellular_component);
$master_dba->dbc->disconnect_if_idle;


if ($old_dba and !$skip_data) {
## Copy all the stable ID mapping entries
  print "Copying the stable_id_history table ...\n";
  copy_table($old_dba->dbc, $new_dba->dbc, "stable_id_history");
## Copy all the MethodLinkSpeciesSetTags for MethodLinkSpeciesSets
  copy_all_mlss_tags($old_dba, $new_dba, $all_default_method_link_species_sets);
## Copy all the SpecieTree entries
  copy_all_species_tres($old_dba, $new_dba, $all_default_method_link_species_sets);

## Copy DNA-DNA alignemnts
  copy_dna_dna_alignements($old_dba, $new_dba, $all_default_method_link_species_sets);
  exit(0) if ( $alignments_only );
## Copy Ancestor dnafrags
  copy_ancestor_dnafrag($old_dba, $new_dba, $all_default_method_link_species_sets);
## Copy Synteny data
  copy_synteny_data($old_dba, $new_dba, $all_default_method_link_species_sets);
## Copy Constrained elements
   copy_constrained_elements($old_dba, $new_dba, $all_default_method_link_species_sets);
## Copy Conservation scores
   copy_conservation_scores($old_dba, $new_dba, $all_default_method_link_species_sets);
}

##END
exit(0);


=head2 store_objects

  Arg[1]      : Bio::EnsEMBL::Compara::DBSQL::ObjectDBAdaptor $object_adaptor
  Arg[2]      : listref Bio::EnsEMBL::... $objects
  Arg[3]      : (optional) string $description
  Description : stores $objects using the store method of the $obejct_adaptor
  Returns     :
  Exceptions  : throw if argument test fails

=cut

sub store_objects {
  my ($object_adaptor, $objects, $description) = @_;

  if ($description) {
    print "Storing $description...\n";
  }

  foreach my $this_object (@$objects) {
    $object_adaptor->store($this_object);
  }
}


=head2 update_schema_version

  Arg[1]      : Bio::EnsEMBL::Compara::DBSQL::DBAdaptor $old_dba
  Arg[2]      : Bio::EnsEMBL::Compara::DBSQL::DBAdaptor $new_dba
  Description : update schema_version in meta table of the new DB
                according to the value in the old DB
  Returns     :
  Exceptions  : throw if argument test fails

=cut

sub update_schema_version {
  my ($old_dba, $new_dba) = @_;

  print "Updating schema_version...\n";
  my ($old_schema_version) = $old_dba->dbc->db_handle->selectrow_array(
      "SELECT meta_value FROM meta WHERE meta_key = 'schema_version'");
  my ($new_schema_version) = $new_dba->dbc->db_handle->selectrow_array(
      "SELECT meta_value FROM meta WHERE meta_key = 'schema_version'");

  if (!$new_schema_version and $old_schema_version =~ /^\d+$/) {
    $new_dba->dbc->do("DELETE FROM meta WHERE meta_key = 'schema_version'");
    $new_dba->dbc->do("INSERT INTO meta (meta_key, meta_value) VALUES ('schema_version', $old_schema_version+1)");
  }
}

=head2 get_all_default_genome_dbs

  Arg[1]      : Bio::EnsEMBL::Compara::DBSQL::DBAdaptor $compara_dba
  Arg[2]      : (optional) listref_of_strings $species_names
  Arg[3]      : (optional) listref_of_ints $MLSS_ids
  Description : get the list of all the default GenomeDBs, i.e. the
                GenomeDBs where the default_assembly is true.
  Returns     : listref of Bio::EnsEMBL::Compara::GenomeDB objects
  Exceptions  : throw if argument test fails

=cut

sub get_all_default_genome_dbs {
  my ($compara_dba, $species_names, $mlss_ids, $collection) = @_;

  assert_ref($compara_dba, 'Bio::EnsEMBL::Compara::DBSQL::DBAdaptor', 'compara_dba');

  my $all_species;

  if ($collection) {
    my $ss_adaptor = $compara_dba->get_SpeciesSetAdaptor();
    my $ss = $ss_adaptor->fetch_collection_by_name($collection);
    return $ss->genome_dbs;
  }

  if (@$mlss_ids) {
    my $method_link_species_set_adaptor = $compara_dba->get_MethodLinkSpeciesSetAdaptor();
    throw("Error while getting Bio::EnsEMBL::Compara::DBSQL::MethodLinkSpeciesSetAdaptor")
        unless ($method_link_species_set_adaptor);
    foreach my $this_mlss_id (@$mlss_ids) {
      my $this_mlss = $method_link_species_set_adaptor->fetch_by_dbID($this_mlss_id);
      foreach my $this_genome_db (@{$this_mlss->species_set->genome_dbs}) {
        $all_species->{$this_genome_db->dbID} = $this_genome_db;
      }
    }
    return [values %$all_species];
  }

  my $genome_db_adaptor = $compara_dba->get_GenomeDBAdaptor();
  throw("Error while getting Bio::EnsEMBL::Compara::DBSQL::GenomeDBAdaptor")
      unless ($genome_db_adaptor);

  foreach my $this_species (@$species_names) {
    if (defined($all_species->{$this_species})) {
      warn (" ** WARNING ** Species <$this_species> defined twice!\n");
    }
    $all_species->{$this_species} = 0;
  }

  my $all_genome_dbs = $filter_current ? $genome_db_adaptor->fetch_all_current() : $genome_db_adaptor->fetch_all();
  $all_genome_dbs = [sort {$a->dbID <=> $b->dbID} @$all_genome_dbs];
  if (@$species_names) {
    for (my $i = 0; $i < @$all_genome_dbs; $i++) {
      my $this_genome_db_name = $all_genome_dbs->[$i]->name;

      if(  ($exact_species_name_match && grep { $this_genome_db_name eq $_ } @$species_names) ||
		   (!$exact_species_name_match && grep { /$this_genome_db_name/ } @$species_names) ) {
         $all_species->{$this_genome_db_name} = 1;
         next;
      }

      ## this_genome_db is not in the list of species_names
      splice(@$all_genome_dbs, $i, 1);
      $i--;
    }
  }

  my $fail = 0;
  foreach my $this_species (@$species_names) {
    if (!$all_species->{$this_species}) {
      print " ** ERROR ** No GenomeDB for species <$this_species>\n";
      $fail = 1;
    }
  }
  die " ** ERROR ** -> Not all the species can be found!\n" if ($fail);

  return $all_genome_dbs;
}


=head2 get_all_method_link_species_sets

  Arg[1]      : Bio::EnsEMBL::Compara::DBSQL::DBAdaptor $compara_dba
  Arg[2]      : listref Bio::EnsEMBL::Compara::GenomeDB $genome_dbs
  Arg[3]      : (optional) listref_of_ints $MLSS_ids
  Description : get the list of all the MethodLinkSpeciesSets which
                contain GenomeDBs from the $genome_dbs list only.
  Returns     : listref of Bio::EnsEMBL::Compara::MethodLinkSpeciesSet objects
  Exceptions  : throw if argument test fails

=cut

sub get_all_method_link_species_sets {
  my ($compara_dba, $genome_dbs, $mlss_ids) = @_;
  my $all_method_link_species_sets = {};

  assert_ref($compara_dba, 'Bio::EnsEMBL::Compara::DBSQL::DBAdaptor', 'compara_dba');

  my $method_link_species_set_adaptor = $compara_dba->get_MethodLinkSpeciesSetAdaptor();
  throw("Error while getting Bio::EnsEMBL::Compara::DBSQL::MethodLinkSpeciesSetAdaptor")
      unless ($method_link_species_set_adaptor);

  if (@$mlss_ids) {
    my $mlsss = [];
    foreach my $this_mlss_id (@$mlss_ids) {
      my $this_mlss = $method_link_species_set_adaptor->fetch_by_dbID($this_mlss_id);
      push(@$mlsss, $this_mlss);
    }
    return $mlsss;
  }

  my $these_genome_dbs = {};
  foreach my $this_genome_db (@$genome_dbs) {
    assert_ref($this_genome_db, 'Bio::EnsEMBL::Compara::GenomeDB', 'this_genome_db');
    $these_genome_dbs->{$this_genome_db->dbID} = $this_genome_db;
  }

  foreach my $this_genome_db (@$genome_dbs) {
    my $these_method_link_species_sets =
        $method_link_species_set_adaptor->fetch_all_by_GenomeDB($this_genome_db);
    foreach my $this_method_link_species_set (@{$these_method_link_species_sets}) {
      next if $filter_current and !$this_method_link_species_set->is_current;
      my $all_included = 1;
      foreach my $this_included_genome_db (@{$this_method_link_species_set->species_set->genome_dbs()}) {
        if (!defined($these_genome_dbs->{$this_included_genome_db->dbID})) {
          $all_included = 0;
          last;
        }
      }
      if ($all_included) {
        $all_method_link_species_sets->{$this_method_link_species_set->dbID} =
            $this_method_link_species_set;
      }
    }
  }

  return [sort {$a->dbID <=> $b->dbID} values %$all_method_link_species_sets];
}


=head2 get_all_species_sets_with_tags

  Arg[1]      : Bio::EnsEMBL::Compara::DBSQL::DBAdaptor $compara_dba
  Arg[2]      : listref Bio::EnsEMBL::Compara::GenomeDB $genome_dbs
  Arg[3]      : (optional) listref_of_ints $MLSS_ids
  Description : get the list of all the SpeciesSets which
                contain GenomeDBs from the $genome_dbs list only.
  Returns     : listref of Bio::EnsEMBL::Compara::MethodLinkSpeciesSet objects
  Exceptions  : throw if argument test fails

=cut

sub get_all_species_sets_with_tags {
  my ($compara_dba, $genome_dbs, $mlss_ids) = @_;
  my $all_species_sets = {};

  assert_ref($compara_dba, 'Bio::EnsEMBL::Compara::DBSQL::DBAdaptor', 'compara_dba');

  my $species_set_adaptor = $compara_dba->get_SpeciesSetAdaptor();
  throw("Error while getting Bio::EnsEMBL::Compara::DBSQL::SpeciesSetAdaptor")
      unless ($species_set_adaptor);

  my $these_genome_dbs = {};
  foreach my $this_genome_db (@$genome_dbs) {
    assert_ref($this_genome_db, 'Bio::EnsEMBL::Compara::GenomeDB', 'this_genome_db');
    $these_genome_dbs->{$this_genome_db->dbID} = $this_genome_db;
  }

  my $these_species_sets = $filter_current ? $species_set_adaptor->fetch_all_current() : $species_set_adaptor->fetch_all();
  foreach my $this_species_set (@{$these_species_sets}) {
    next if (!$this_species_set->get_all_tags and !($this_species_set->name =~ /^collection-/));
    my $all_included = 1;
    foreach my $this_included_genome_db (@{$this_species_set->genome_dbs}) {
      if (!defined($these_genome_dbs->{$this_included_genome_db->dbID})) {
        $all_included = 0;
        last;
      }
    }
    if ($all_included) {
      $all_species_sets->{$this_species_set->dbID} = $this_species_set;
    }
  }

  return [sort {$a->dbID <=> $b->dbID} values %$all_species_sets];
}


=head2 copy_all_dnafrags

  Arg[1]      : Bio::EnsEMBL::Compara::DBSQL::DBAdaptor $from_dba
  Arg[2]      : Bio::EnsEMBL::Compara::DBSQL::DBAdaptor $to_dba
  Arg[3]      : listref Bio::EnsEMBL::Compara::GenomeDB $genome_dbs
  Arg[4]      : string $cellular_component
  Description : copy from $from_dba to $to_dba all the DnaFrags which
                correspond to GenomeDBs from the $genome_dbs list only.
  Returns     :
  Exceptions  : throw if argument test fails

=cut

sub copy_all_dnafrags {
  my ($from_dba, $to_dba, $genome_dbs, $cellular_component) = @_;

  assert_ref($from_dba, 'Bio::EnsEMBL::Compara::DBSQL::DBAdaptor', 'from_dba');
  assert_ref($to_dba, 'Bio::EnsEMBL::Compara::DBSQL::DBAdaptor', 'to_dba');

  # Keys are disabled / enabled only once for the whole loop
  $new_dba->dbc->do("ALTER TABLE `dnafrag` DISABLE KEYS");

  my $n = 0;
  foreach my $this_genome_db (@$genome_dbs) {
    $n++;
    print "Copying ", $this_genome_db->name, "'s DnaFrags ($n/", scalar(@$genome_dbs), ") ...\n";
    my $constraint = "genome_db_id = ".($this_genome_db->dbID);
    copy_table($from_dba->dbc, $to_dba->dbc, 'dnafrag', $constraint.($cellular_component ? " AND cellular_component = '$cellular_component'" : ''), undef, 'skip_disable_keys');
  }

  $new_dba->dbc->do("ALTER TABLE `dnafrag` ENABLE KEYS");
}

=head2 copy_all_mlss_tags

  Arg[1]      : Bio::EnsEMBL::Compara::DBSQL::DBAdaptor $from_dba
  Arg[2]      : Bio::EnsEMBL::Compara::DBSQL::DBAdaptor $to_dba
  Arg[3]      : listref Bio::EnsEMBL::Compara::MethodLinkSpeciesSet $mlsss
  Description : copy from $from_dba to $to_dba all the MethodLinkSpeciesSetTags which
                correspond to MethodLinkSpeciesSets from the $mlsss list only.
  Returns     :
  Exceptions  : throw if argument test fails

=cut

sub copy_all_mlss_tags {
  my ($from_dba, $to_dba, $mlsss) = @_;

  print "Copying all MethodLinkSpeciesSet tags ...\n";
  foreach my $this_mlss (@$mlsss) {
    next if $methods_to_skip{$this_mlss->method->type};
    copy_table($from_dba->dbc, $to_dba->dbc, 'method_link_species_set_tag', "method_link_species_set_id = ".($this_mlss->dbID));
  }
}


=head2 copy_all_species_tres

  Arg[1]      : Bio::EnsEMBL::Compara::DBSQL::DBAdaptor $from_dba
  Arg[2]      : Bio::EnsEMBL::Compara::DBSQL::DBAdaptor $to_dba
  Arg[3]      : listref Bio::EnsEMBL::Compara::MethodLinkSpeciesSet $mlsss
  Description : copy from $from_dba to $to_dba all the SpeciesTree entries which
                correspond to MethodLinkSpeciesSets from the $mlsss list only.
                Species-trees are stored in the species_tree_root and species_tree_node tables
  Returns     :
  Exceptions  : throw if argument test fails

=cut

sub copy_all_species_tres {
  my ($from_dba, $to_dba, $mlsss) = @_;

  print "Copying all species-trees ...\n";
  foreach my $this_mlss (@$mlsss) {
    next unless $this_mlss->method->class =~ /(GenomicAlign(Tree|Block).(tree|ancestral|multiple)_alignment|SpeciesTree.species_tree_root)/;
    my $mlss_filter = "method_link_species_set_id = ".($this_mlss->dbID);
    copy_table($from_dba->dbc, $to_dba->dbc, 'species_tree_root', $mlss_filter);
    copy_data($from_dba->dbc, $to_dba->dbc, 'species_tree_node', "SELECT species_tree_node.* FROM species_tree_node JOIN species_tree_root USING (root_id) WHERE $mlss_filter");
    copy_data($from_dba->dbc, $to_dba->dbc, 'species_tree_node_tag', "SELECT species_tree_node_tag.* FROM species_tree_node_tag JOIN species_tree_node USING (node_id) JOIN species_tree_root USING (root_id) WHERE $mlss_filter");
    copy_data($from_dba->dbc, $to_dba->dbc, 'species_tree_node_attr', "SELECT species_tree_node_attr.* FROM species_tree_node_attr JOIN species_tree_node USING (node_id) JOIN species_tree_root USING (root_id) WHERE $mlss_filter");

  }
}


=head2 copy_dna_dna_alignements

  Arg[1]      : Bio::EnsEMBL::Compara::DBSQL::DBAdaptor $from_dba
  Arg[2]      : Bio::EnsEMBL::Compara::DBSQL::DBAdaptor $to_dba
  Arg[3]      : listref Bio::EnsEMBL::Compara::MethodLinkSpeciesSet $these_mlss
  Description : copy dna-dna alignments for the MethodLinkSpeciesSet listed
                in $these_mlss. Dna-dna alignments are stored in the
                genomic_align_block, genomic_align and genomic_align_tree
                tables.
  Returns     :
  Exceptions  : throw if argument test fails

=cut

sub copy_dna_dna_alignements {
  my ($old_dba, $new_dba, $method_link_species_sets) = @_;

  # Keys are disabled / enabled only once for the whole loop
  $new_dba->dbc->do("ALTER TABLE `genomic_align_block` DISABLE KEYS");
  $new_dba->dbc->do("ALTER TABLE `genomic_align` DISABLE KEYS");
  $new_dba->dbc->do("ALTER TABLE `genomic_align_tree` DISABLE KEYS");

  foreach my $this_method_link_species_set (@$method_link_species_sets) {
    ## For DNA-DNA alignments, the method_link_id is < 100.
    next if ($this_method_link_species_set->method->dbID >= 100);
    ## We ignore LASTZ_PATCH alignments as they should be reloaded fresh every release
    next if ($this_method_link_species_set->method->type eq 'LASTZ_PATCH');
    ## Skip HAL alignments as there's nothing in the db
    next if ($this_method_link_species_set->method->type =~ m/CACTUS_HAL/);

    print "Copying dna-dna alignments for ", $this_method_link_species_set->name,
        " (", $this_method_link_species_set->dbID, "): ";
    my $where = "genomic_align_block_id >= ".
        ($this_method_link_species_set->dbID * 10**10)." AND genomic_align_block_id < ".
        (($this_method_link_species_set->dbID + 1) * 10**10);
    $where = "method_link_species_set_id = ".($this_method_link_species_set->dbID) if $filter_by_mlss;
    copy_table($old_dba->dbc, $new_dba->dbc, 'genomic_align_block', $where, undef, 'skip_disable_keys');
    print ".";
    $where = "genomic_align_id >= ".
        ($this_method_link_species_set->dbID * 10**10)." AND genomic_align_id < ".
        (($this_method_link_species_set->dbID + 1) * 10**10);
    $where = "method_link_species_set_id = ".($this_method_link_species_set->dbID) if $filter_by_mlss;
    copy_table($old_dba->dbc, $new_dba->dbc, 'genomic_align', $where, undef, 'skip_disable_keys');
    print ".";
    $where = "node_id >= ".
        ($this_method_link_species_set->dbID * 10**10)." AND node_id < ".
        (($this_method_link_species_set->dbID + 1) * 10**10);
    copy_table($old_dba->dbc, $new_dba->dbc, 'genomic_align_tree', $where, undef, 'skip_disable_keys');
    print "ok!\n";
  }
  print "re-enabling keys\n";
  $new_dba->dbc->do("ALTER TABLE `genomic_align_block` ENABLE KEYS");
  $new_dba->dbc->do("ALTER TABLE `genomic_align` ENABLE KEYS");
  $new_dba->dbc->do("ALTER TABLE `genomic_align_tree` ENABLE KEYS");
  print "keys enabled!\n";
}

=head2 copy_ancestor_dnafrag

  Arg[1]      : Bio::EnsEMBL::Compara::DBSQL::DBAdaptor $from_dba
  Arg[2]      : Bio::EnsEMBL::Compara::DBSQL::DBAdaptor $to_dba
  Arg[3]      : listref Bio::EnsEMBL::Compara::MethodLinkSpeciesSet $these_mlss
  Description : copy ancestor dnafrags in the dnafrag_id range given by the 
                MethodLinkSpeciesSet listed
  Returns     :
  Exceptions  : throw if argument test fails

=cut

sub copy_ancestor_dnafrag {
  my ($old_dba, $new_dba, $method_link_species_sets) = @_;

  foreach my $this_method_link_species_set (@$method_link_species_sets) {
      ## For ancestral dnafrags, the method_link_id is < 100.
      next if ($this_method_link_species_set->method->dbID >= 100);
      if ($this_method_link_species_set->method->class() eq 
	  "GenomicAlignTree.ancestral_alignment") {
	  print "Copying ancestral dnafrags for ", $this_method_link_species_set->name,
	    " (", $this_method_link_species_set->dbID, "): ";
	  my $where = "dnafrag_id >= ".
	    ($this_method_link_species_set->dbID * 10**10)." AND dnafrag_id < ".
	      (($this_method_link_species_set->dbID + 1) * 10**10);

          copy_table($old_dba->dbc, $new_dba->dbc, 'dnafrag', $where);
	  print "ok!\n";
      }
  }
}

=head2 copy_synteny_data

  Arg[1]      : Bio::EnsEMBL::Compara::DBSQL::DBAdaptor $from_dba
  Arg[2]      : Bio::EnsEMBL::Compara::DBSQL::DBAdaptor $to_dba
  Arg[3]      : listref Bio::EnsEMBL::Compara::MethodLinkSpeciesSet $these_mlss
  Description : copy synteny data for the MethodLinkSpeciesSet listed
                in $these_mlss. Synteny data are stored in the
                synteny_region and dnafrag_region tables.
  Returns     :
  Exceptions  : throw if argument test fails

=cut

sub copy_synteny_data {
  my ($old_dba, $new_dba, $method_link_species_sets) = @_;

  # Keys are disabled / enabled only once for the whole loop
  $new_dba->dbc->do("ALTER TABLE `synteny_region` DISABLE KEYS");
  $new_dba->dbc->do("ALTER TABLE `dnafrag_region` DISABLE KEYS");

  foreach my $this_mlss (@$method_link_species_sets) {
    next unless $this_mlss->method->class eq 'SyntenyRegion.synteny';
    my $mlss_filter = "method_link_species_set_id = ".($this_mlss->dbID);
    copy_table($old_dba->dbc, $new_dba->dbc, 'synteny_region', $mlss_filter);
    copy_data($old_dba->dbc, $new_dba->dbc, 'dnafrag_region', "SELECT dnafrag_region.* FROM dnafrag_region JOIN synteny_region USING (synteny_region_id) WHERE $mlss_filter");
  }

  $new_dba->dbc->do("ALTER TABLE `synteny_region` ENABLE KEYS");
  $new_dba->dbc->do("ALTER TABLE `dnafrag_region` ENABLE KEYS");
}


=head2 copy_constrained_elements

  Arg[1]      : Bio::EnsEMBL::Compara::DBSQL::DBAdaptor $from_dba
  Arg[2]      : Bio::EnsEMBL::Compara::DBSQL::DBAdaptor $to_dba
  Arg[3]      : listref Bio::EnsEMBL::Compara::MethodLinkSpeciesSet $these_mlss
  Description : copy constrained_elements for the MethodLinkSpeciesSet listed
                in $these_mlss. Constrained_elements are stored in the
                constrained_element table.
  Returns     :
  Exceptions  : throw if argument test fails

=cut

sub copy_constrained_elements {
  my ($old_dba, $new_dba, $method_link_species_sets) = @_;

  # Keys are disabled / enabled only once for the whole loop
  $new_dba->dbc->do("ALTER TABLE `constrained_element` DISABLE KEYS");

  foreach my $this_method_link_species_set (@$method_link_species_sets) {
    my $constrained_element_fetch_sth = $old_dba->dbc->prepare("SELECT * FROM constrained_element".
	" WHERE method_link_species_set_id = ? LIMIT 1");
    $constrained_element_fetch_sth->execute($this_method_link_species_set->dbID);
    my $all_rows = $constrained_element_fetch_sth->fetchall_arrayref;
    if (!@$all_rows) {
      next;
    }

    print "Copying constrained elements for ", $this_method_link_species_set->name,
	" (", $this_method_link_species_set->dbID, "): ";

    my $where = "constrained_element_id >= ".
    ($this_method_link_species_set->dbID * 10**10)." AND constrained_element_id < ".
    (($this_method_link_species_set->dbID + 1) * 10**10);
    copy_table($old_dba->dbc, $new_dba->dbc, 'constrained_element', $where, undef, 'skip_disable_keys');
    print "ok!\n";
  }
  $new_dba->dbc->do("ALTER TABLE `constrained_element` ENABLE KEYS");
}

=head2 copy_conservation_scores

  Arg[1]      : Bio::EnsEMBL::Compara::DBSQL::DBAdaptor $from_dba
  Arg[2]      : Bio::EnsEMBL::Compara::DBSQL::DBAdaptor $to_dba
  Arg[3]      : listref Bio::EnsEMBL::Compara::MethodLinkSpeciesSet $these_mlss
  Description : copy conservation_scores for the range of genomic_align_block_ids
                (generated from $these_mlss). Conservations scores are stored in the
                conservation_score table.
  Returns     :
  Exceptions  : throw if argument test fails

=cut

sub copy_conservation_scores {
  my ($old_dba, $new_dba, $method_link_species_sets) = @_;

  # Keys are disabled / enabled only once for the whole loop
  $new_dba->dbc->do("ALTER TABLE `conservation_score` DISABLE KEYS");
  my $conservation_score_fetch_sth = $old_dba->dbc->prepare("SELECT * FROM conservation_score".
      " WHERE genomic_align_block_id >= ? AND genomic_align_block_id < ? LIMIT 1");

  foreach my $this_method_link_species_set (@$method_link_species_sets) {
    my $lower_gab_id = $this_method_link_species_set->dbID * 10**10;
    my $upper_gab_id = ($this_method_link_species_set->dbID + 1) * 10**10;
    $conservation_score_fetch_sth->execute($lower_gab_id, $upper_gab_id);
    my $all_rows = $conservation_score_fetch_sth->fetchall_arrayref;
    if (!@$all_rows) {
      next;
    }

    my $where = "genomic_align_block_id >= $lower_gab_id AND genomic_align_block_id < $upper_gab_id";
    print "Copying conservation scores for ", $this_method_link_species_set->name,
	" (", $this_method_link_species_set->dbID, "): ";
    copy_table($old_dba->dbc, $new_dba->dbc, 'conservation_score', $where, undef, "skip_disable_keys");
    print "ok!\n";
  }

  $new_dba->dbc->do("ALTER TABLE `conservation_score` ENABLE KEYS");
}


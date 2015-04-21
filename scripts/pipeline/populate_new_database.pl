#!/usr/bin/env perl
# Copyright [1999-2015] Wellcome Trust Sanger Institute and the EMBL-European Bioinformatics Institute
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
these data, this script looks for "skip_mlss" entries in the meta table of the master database
and skip the method_link_species_sets corresponding to these IDs.

=cut

use Bio::EnsEMBL::Compara::DBSQL::DBAdaptor;
use Bio::EnsEMBL::Registry;
use Bio::EnsEMBL::Utils::Exception qw(throw warning);
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
my $MT_only = 0;
my $collection = undef;
my $filter_by_mlss = 0;

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
    'MT_only=i' => \$MT_only,
    'collection=s' => \$collection,
    'filter_by_mlss' => \$filter_by_mlss,
  );


# Print Help and exit if help is requested
if ($help or !$master or !$new) {
  exec("/usr/bin/env perldoc $0");
}


#################################################
## Get the DBAdaptors from the Registry
Bio::EnsEMBL::Registry->load_all($reg_conf, 1);

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

## Get all the genome_dbs with a default assembly
my $all_default_genome_dbs = get_all_default_genome_dbs($master_dba, $species, $mlsss, $collection);

## Get all the MethodLinkSpeciesSet for the default assemblies
my $all_default_method_link_species_sets = get_all_method_link_species_sets($master_dba, $all_default_genome_dbs, $mlsss);

## Get all the SpeciesSets with tags for the default assemblies
my $all_default_species_sets = get_all_species_sets_with_tags($master_dba, $all_default_genome_dbs, $mlsss);

if($only_show_intentions) {
    print "GenomeDB entries to be copied:\n";
    foreach my $genome_db (@$all_default_genome_dbs) {
        print "\t".$genome_db->dbID.": ".$genome_db->name."\n";
    }
    print "MethodLinkSpeciesSet entries to be copied:\n";
    foreach my $mlss (sort {$a->method->dbID <=> $b->method->dbID} @$all_default_method_link_species_sets) {
        print "\t".$mlss->dbID.": ".$mlss->name."\n";
    }
    print "SpeciesSet entries to be copied:\n";
    foreach my $ss (@$all_default_species_sets) {
        print "\t".$ss->dbID.": ".join(', ', map { $_->name } @{$ss->genome_dbs})."\n";
    }
    exit 0;
}

## Sets the schema version for the new database
update_schema_version($master_dba, $new_dba);

## Copy taxa and method_link tables
copy_table($master_dba, $new_dba, "ncbi_taxa_node");
copy_table($master_dba, $new_dba, "ncbi_taxa_name");
copy_table($master_dba, $new_dba, "method_link");

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

copy_all_dnafrags($master_dba, $new_dba, $all_default_genome_dbs, $MT_only);


if ($old_dba and !$skip_data) {
## Copy all the MethodLinkSpeciesSetTags for MethodLinkSpeciesSets
  copy_all_mlss_tags($old_dba, $new_dba, $all_default_method_link_species_sets);

## Copy DNA-DNA alignemnts
  copy_dna_dna_alignements($old_dba, $new_dba, $all_default_method_link_species_sets);
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


=head2 copy_table

  Arg[1]      : Bio::EnsEMBL::Compara::DBSQL::DBAdaptor $from_dba
  Arg[2]      : Bio::EnsEMBL::Compara::DBSQL::DBAdaptor $to_dba
  Arg[3]      : string $table_name
  Description : copy content of table $table_name from database
                $from_db to database $to_db
  Returns     :
  Exceptions  : throw if argument test fails

=cut

sub copy_table {
  my ($from_dba, $to_dba, $table_name) = @_;

  print "Copying table $table_name...\n";
  throw("[$from_dba] should be a Bio::EnsEMBL::Compara::DBSQL::DBAdaptor")
      unless (UNIVERSAL::isa($from_dba, "Bio::EnsEMBL::Compara::DBSQL::DBAdaptor"));

  throw("[$to_dba] should be a Bio::EnsEMBL::Compara::DBSQL::DBAdaptor")
      unless (UNIVERSAL::isa($to_dba, "Bio::EnsEMBL::Compara::DBSQL::DBAdaptor"));

  my $user = $to_dba->dbc->username;
  my $pass = $to_dba->dbc->password;
  my $host = $to_dba->dbc->host;
  my $port = $to_dba->dbc->port;
  my $dbname = $to_dba->dbc->dbname;

  my $sth = $from_dba->dbc->prepare("SELECT * FROM $table_name");
  $sth->execute();
  my $all_rows = $sth->fetchall_arrayref();
  $sth->finish;
  my $filename = "/tmp/$table_name.populate_new_database.$$.txt";
  open(TEMP, ">$filename") or die;
  foreach my $this_row (@$all_rows) {
    print TEMP join("\t", @$this_row), "\n";
  }
  close(TEMP);
  if ($pass) {
    system("mysqlimport", "-u$user", "-p$pass", "-h$host", "-P$port", "-L", "-l", "-i", $dbname, $filename);
  } else {
    system("mysqlimport", "-u$user", "-h$host", "-P$port", "-L", "-l", "-i", $dbname, $filename);
  }
  unlink("$filename");
}


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

  throw("[$compara_dba] should be a Bio::EnsEMBL::Compara::DBSQL::DBAdaptor")
      unless (UNIVERSAL::isa($compara_dba, "Bio::EnsEMBL::Compara::DBSQL::DBAdaptor"));

  my $all_species;

  if ($collection) {
    my $ss_adaptor = $compara_dba->get_SpeciesSetAdaptor();
    my $ss = $ss_adaptor->fetch_all_by_tag_value("name", "collection-$collection");
    die "Cannot find the collection '$collection'" unless scalar(@$ss);
    die "There are several collections '$collection'" if scalar(@$ss) > 1;
    return $ss->[0]->genome_dbs;
  }

  if (@$mlss_ids) {
    my $method_link_species_set_adaptor = $compara_dba->get_MethodLinkSpeciesSetAdaptor();
    throw("Error while getting Bio::EnsEMBL::Compara::DBSQL::MethodLinkSpeciesSetAdaptor")
        unless ($method_link_species_set_adaptor);
    foreach my $this_mlss_id (@$mlss_ids) {
      my $this_mlss = $method_link_species_set_adaptor->fetch_by_dbID($this_mlss_id);
      foreach my $this_genome_db (@{$this_mlss->species_set_obj->genome_dbs}) {
        $all_species->{$this_genome_db->name} = $this_genome_db;
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

  my $all_genome_dbs = $genome_db_adaptor->fetch_all();
  $all_genome_dbs = [sort {$a->dbID <=> $b->dbID} grep {$_->assembly_default} @$all_genome_dbs];
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

  throw("[$compara_dba] should be a Bio::EnsEMBL::Compara::DBSQL::DBAdaptor")
      unless (UNIVERSAL::isa($compara_dba, "Bio::EnsEMBL::Compara::DBSQL::DBAdaptor"));

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

  ## Get the list of MLSS to skip from the meta table of the master DB
  my $meta_container = $compara_dba->get_MetaContainer();
  throw("Error while getting the MetaContainer") unless ($meta_container);
  my $skip_mlss;
  foreach my $this_skip_mlss (@{$meta_container->list_value_by_key("skip_mlss")}) {
    $skip_mlss->{$this_skip_mlss} = 1;
  }

  my $these_genome_dbs = {};
  foreach my $this_genome_db (@$genome_dbs) {
    throw("[$this_genome_db] should be a Bio::EnsEMBL::Compara::GenomeDB")
        unless (UNIVERSAL::isa($this_genome_db, "Bio::EnsEMBL::Compara::GenomeDB"));
    $these_genome_dbs->{$this_genome_db->dbID} = $this_genome_db;
  }

  foreach my $this_genome_db (@$genome_dbs) {
    my $these_method_link_species_sets =
        $method_link_species_set_adaptor->fetch_all_by_GenomeDB($this_genome_db);
    foreach my $this_method_link_species_set (@{$these_method_link_species_sets}) {
      next if ($skip_mlss->{$this_method_link_species_set->dbID});
      my $all_included = 1;
      foreach my $this_included_genome_db (@{$this_method_link_species_set->species_set_obj->genome_dbs()}) {
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

  throw("[$compara_dba] should be a Bio::EnsEMBL::Compara::DBSQL::DBAdaptor")
      unless (UNIVERSAL::isa($compara_dba, "Bio::EnsEMBL::Compara::DBSQL::DBAdaptor"));

  my $species_set_adaptor = $compara_dba->get_SpeciesSetAdaptor();
  throw("Error while getting Bio::EnsEMBL::Compara::DBSQL::SpeciesSetAdaptor")
      unless ($species_set_adaptor);

  ## Get the list of MLSS to skip from the meta table of the master DB
  my $meta_container = $compara_dba->get_MetaContainer();
  throw("Error while getting the MetaContainer") unless ($meta_container);
  my $skip_ss;
  foreach my $this_skip_ss (@{$meta_container->list_value_by_key("skip_ss")}) {
    $skip_ss->{$this_skip_ss} = 1;
  }

  my $these_genome_dbs = {};
  foreach my $this_genome_db (@$genome_dbs) {
    throw("[$this_genome_db] should be a Bio::EnsEMBL::Compara::GenomeDB")
        unless (UNIVERSAL::isa($this_genome_db, "Bio::EnsEMBL::Compara::GenomeDB"));
    $these_genome_dbs->{$this_genome_db->dbID} = $this_genome_db;
  }

  my $these_species_sets = $species_set_adaptor->fetch_all();
  foreach my $this_species_set (@{$these_species_sets}) {
    next if ($skip_ss->{$this_species_set->dbID});
    next if (!$this_species_set->get_all_tags);
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
  Arg[4]      : boolean $MT_only
  Description : copy from $from_dba to $to_dba all the DnaFrags which
                correspond to GenomeDBs from the $genome_dbs list only.
  Returns     :
  Exceptions  : throw if argument test fails

=cut

sub copy_all_dnafrags {
  my ($from_dba, $to_dba, $genome_dbs, $MT_only) = @_;

  throw("[$from_dba] should be a Bio::EnsEMBL::Compara::DBSQL::DBAdaptor")
      unless (UNIVERSAL::isa($from_dba, "Bio::EnsEMBL::Compara::DBSQL::DBAdaptor"));

  throw("[$to_dba] should be a Bio::EnsEMBL::Compara::DBSQL::DBAdaptor")
      unless (UNIVERSAL::isa($to_dba, "Bio::EnsEMBL::Compara::DBSQL::DBAdaptor"));

  my $user = $new_dba->dbc->username;
  my $pass = $new_dba->dbc->password;
  my $host = $new_dba->dbc->host;
  my $port = $new_dba->dbc->port;
  my $dbname = $new_dba->dbc->dbname;

  my $dnafrag_fetch_MT_sth = $from_dba->dbc->prepare("SELECT * FROM dnafrag".
     " WHERE genome_db_id = ? AND name = \"MT\""); 
  my $dnafrag_fetch_sth = $from_dba->dbc->prepare("SELECT * FROM dnafrag".
     " WHERE genome_db_id = ?");

  foreach my $this_genome_db (@$genome_dbs) {
    my $all_rows;
    if ( $MT_only ) {
        #Try first getting just MT
        $dnafrag_fetch_MT_sth->execute($this_genome_db->dbID);
        $all_rows = $dnafrag_fetch_MT_sth->fetchall_arrayref;
        #If getting just MT fails, get all the dnafrags to catch cases where the mitochondrion is not called MT
    }
    
    if (!$all_rows || !@$all_rows) {
        $dnafrag_fetch_sth->execute($this_genome_db->dbID);
        $all_rows = $dnafrag_fetch_sth->fetchall_arrayref;
    }
    if (!@$all_rows) {
      next;
    }
    my $filename = "/tmp/dnafrag.populate_new_database.".$this_genome_db->dbID.".$$.txt";
    open(TEMP, ">$filename") or die;
    foreach my $this_row (@$all_rows) {
      print TEMP join("\t", @$this_row), "\n";
    }
    close(TEMP);
    print "Copying dnafrag for ", $this_genome_db->name, ":\n . ";
    if ($pass) {
      system("mysqlimport", "-u$user", "-p$pass", "-h$host", "-P$port", "-L", "-l", "-i", $dbname, $filename);
    } else {
      system("mysqlimport", "-u$user", "-h$host", "-P$port", "-L", "-l", "-i", $dbname, $filename);
    }
    unlink("$filename");
  }
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

  throw("[$from_dba] should be a Bio::EnsEMBL::Compara::DBSQL::DBAdaptor")
      unless (UNIVERSAL::isa($from_dba, "Bio::EnsEMBL::Compara::DBSQL::DBAdaptor"));

  throw("[$to_dba] should be a Bio::EnsEMBL::Compara::DBSQL::DBAdaptor")
      unless (UNIVERSAL::isa($to_dba, "Bio::EnsEMBL::Compara::DBSQL::DBAdaptor"));

  my $user = $new_dba->dbc->username;
  my $pass = $new_dba->dbc->password;
  my $host = $new_dba->dbc->host;
  my $port = $new_dba->dbc->port;
  my $dbname = $new_dba->dbc->dbname;

  my $mlss_tag_fetch_sth = $from_dba->dbc->prepare("SELECT * FROM method_link_species_set_tag".
      " WHERE method_link_species_set_id = ? AND tag != 'threshold_on_ds'");
  foreach my $this_mlss (@$mlsss) {
    $mlss_tag_fetch_sth->execute($this_mlss->dbID);
    my $all_rows = $mlss_tag_fetch_sth->fetchall_arrayref;
    if (!@$all_rows) {
      next;
    }
    my $filename = "/tmp/method_link_species_set_tag.populate_new_database.".$this_mlss->dbID.".$$.txt";
    open(TEMP, ">$filename") or die;
    foreach my $this_row (@$all_rows) {
      print TEMP join("\t", @$this_row), "\n";
    }
    close(TEMP);
    print "Copying method_link_species_set_tag for ", $this_mlss->name, ":\n . ";

    if ($pass) {
      system("mysqlimport", "-u$user", "-p$pass", "-h$host", "-P$port", "-L", "-l", "-i", $dbname, $filename);
    } else {
      system("mysqlimport", "-u$user", "-h$host", "-P$port", "-L", "-l", "-i", $dbname, $filename);
    }
    unlink("$filename");
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

  my $old_user = $old_dba->dbc->username;
  my $old_pass = $old_dba->dbc->password?"-p".$old_dba->dbc->password:"";
  my $old_host = $old_dba->dbc->host;
  my $old_port = $old_dba->dbc->port;
  my $old_dbname = $old_dba->dbc->dbname;

  my $new_user = $new_dba->dbc->username;
  my $new_pass = $new_dba->dbc->password?"-p".$new_dba->dbc->password:"";
  my $new_host = $new_dba->dbc->host;
  my $new_port = $new_dba->dbc->port;
  my $new_dbname = $new_dba->dbc->dbname;

  my $mysqldump = "mysqldump -u$old_user $old_pass -h$old_host -P$old_port".
      " --skip-disable-keys --insert-ignore -t $old_dbname";
  my $mysql = "mysql -u$new_user $new_pass -h$new_host -P$new_port $new_dbname";

  $new_dba->dbc->do("ALTER TABLE `genomic_align_block` DISABLE KEYS");
  $new_dba->dbc->do("ALTER TABLE `genomic_align` DISABLE KEYS");
  $new_dba->dbc->do("ALTER TABLE `genomic_align_tree` DISABLE KEYS");
  foreach my $this_method_link_species_set (@$method_link_species_sets) {
    ## For DNA-DNA alignments, the method_link_id is < 100.
    next if ($this_method_link_species_set->method->dbID >= 100);
    print "Copying dna-dna alignments for ", $this_method_link_species_set->name,
        " (", $this_method_link_species_set->dbID, "): ";
    my $where = "genomic_align_block_id >= ".
        ($this_method_link_species_set->dbID * 10**10)." AND genomic_align_block_id < ".
        (($this_method_link_species_set->dbID + 1) * 10**10);
    $where = "method_link_species_set_id = ".($this_method_link_species_set->dbID) if $filter_by_mlss;
    my $pipe = "$mysqldump -w \"$where\" genomic_align_block | $mysql";
    system($pipe);
    print ".";
    $where = "genomic_align_id >= ".
        ($this_method_link_species_set->dbID * 10**10)." AND genomic_align_id < ".
        (($this_method_link_species_set->dbID + 1) * 10**10);
    $where = "method_link_species_set_id = ".($this_method_link_species_set->dbID) if $filter_by_mlss;
    $pipe = "$mysqldump -w \"$where\" genomic_align | $mysql";
    system($pipe);
    print ".";
    #$where = "node_id >= ".
    #    ($this_method_link_species_set->dbID * 10**10)." AND node_id < ".
    #    (($this_method_link_species_set->dbID + 1) * 10**10);
    #$pipe = "$mysqldump -w \"$where\" genomic_align_group | $mysql";
    #system($pipe);
    $where = "node_id >= ".
        ($this_method_link_species_set->dbID * 10**10)." AND node_id < ".
        (($this_method_link_species_set->dbID + 1) * 10**10);
    $pipe = "$mysqldump -w \"$where\" genomic_align_tree | $mysql";
    system($pipe);
    print "ok!\n";
  }
  $new_dba->dbc->do("ALTER TABLE `genomic_align_block` ENABLE KEYS");
  $new_dba->dbc->do("ALTER TABLE `genomic_align` ENABLE KEYS");
  $new_dba->dbc->do("ALTER TABLE `genomic_align_tree` ENABLE KEYS");
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

  my $old_user = $old_dba->dbc->username;
  my $old_pass = $old_dba->dbc->password?"-p".$old_dba->dbc->password:"";
  my $old_host = $old_dba->dbc->host;
  my $old_port = $old_dba->dbc->port;
  my $old_dbname = $old_dba->dbc->dbname;

  my $new_user = $new_dba->dbc->username;
  my $new_pass = $new_dba->dbc->password?"-p".$new_dba->dbc->password:"";
  my $new_host = $new_dba->dbc->host;
  my $new_port = $new_dba->dbc->port;
  my $new_dbname = $new_dba->dbc->dbname;

  my $mysqldump = "mysqldump -u$old_user $old_pass -h$old_host -P$old_port".
      " --skip-disable-keys --insert-ignore -t $old_dbname";
  my $mysql = "mysql -u$new_user $new_pass -h$new_host -P$new_port $new_dbname";

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

	  my $pipe = "$mysqldump -w \"$where\" dnafrag | $mysql";
	  system($pipe);
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

  my $user = $new_dba->dbc->username;
  my $pass = $new_dba->dbc->password;
  my $host = $new_dba->dbc->host;
  my $port = $new_dba->dbc->port;
  my $dbname = $new_dba->dbc->dbname;

  my $synteny_region_fetch_sth = $old_dba->dbc->prepare("SELECT * FROM synteny_region".
      " WHERE method_link_species_set_id = ?");
  my $dnafrag_region_fetch_sth = $old_dba->dbc->prepare("SELECT dnafrag_region.* FROM synteny_region".
      " LEFT JOIN dnafrag_region using (synteny_region_id) WHERE method_link_species_set_id = ?");
  foreach my $this_method_link_species_set (@$method_link_species_sets) {
    $synteny_region_fetch_sth->execute($this_method_link_species_set->dbID);
    my $all_rows = $synteny_region_fetch_sth->fetchall_arrayref;
    if (!@$all_rows) {
      next;
    }
    my $filename = "/tmp/synteny_region.populate_new_database.".$this_method_link_species_set->dbID.".$$.txt";
    open(TEMP, ">$filename") or die;
    foreach my $this_row (@$all_rows) {
      print TEMP join("\t", @$this_row), "\n";
    }
    close(TEMP);
    print "Copying dna-dna alignments for ", $this_method_link_species_set->name, ":\n . ";
    if ($pass) {
      system("mysqlimport", "-u$user", "-p$pass", "-h$host", "-P$port", "-L", "-l", "-i", $dbname, $filename);
    } else {
      system("mysqlimport", "-u$user", "-h$host", "-P$port", "-L", "-l", "-i", $dbname, $filename);
    }
    unlink("$filename");

    $dnafrag_region_fetch_sth->execute($this_method_link_species_set->dbID);
    $all_rows = $dnafrag_region_fetch_sth->fetchall_arrayref;
    if (!@$all_rows) {
      next;
    }
    $filename = "/tmp/dnafrag_region.populate_new_database.".$this_method_link_species_set->dbID.".$$.txt";
    open(TEMP, ">$filename") or die;
    foreach my $this_row (@$all_rows) {
      print TEMP join("\t", @$this_row), "\n";
    }
    close(TEMP);
    print " . ";
    if ($pass) {
      system("mysqlimport", "-u$user", "-p$pass", "-h$host", "-P$port", "-L", "-l", "-i", $dbname, $filename);
    } else {
      system("mysqlimport", "-u$user", "-h$host", "-P$port", "-L", "-l", "-i", $dbname, $filename);
    }
    unlink("$filename");
  }
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

  my $old_user = $old_dba->dbc->username;
  my $old_pass = $old_dba->dbc->password?"-p".$old_dba->dbc->password:"";
  my $old_host = $old_dba->dbc->host;
  my $old_port = $old_dba->dbc->port;
  my $old_dbname = $old_dba->dbc->dbname;

  my $new_user = $new_dba->dbc->username;
  my $new_pass = $new_dba->dbc->password?"-p".$new_dba->dbc->password:"";
  my $new_host = $new_dba->dbc->host;
  my $new_port = $new_dba->dbc->port;
  my $new_dbname = $new_dba->dbc->dbname;

  my $mysqldump = "mysqldump -u$old_user $old_pass -h$old_host -P$old_port".
	" --skip-disable-keys --insert-ignore -t $old_dbname";
  my $mysql = "mysql -u$new_user $new_pass -h$new_host -P$new_port $new_dbname";

  $new_dba->dbc->do("ALTER TABLE `constrained_element` DISABLE KEYS");

  my $constrained_element_fetch_sth = $old_dba->dbc->prepare("SELECT * FROM constrained_element".
      " WHERE method_link_species_set_id = ? LIMIT 1");
  foreach my $this_method_link_species_set (@$method_link_species_sets) {
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
    my $pipe = "$mysqldump -w \"$where\" constrained_element | $mysql";
    system($pipe);
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

  my $old_user = $old_dba->dbc->username;
  my $old_pass = $old_dba->dbc->password?"-p".$old_dba->dbc->password:"";
  my $old_host = $old_dba->dbc->host;
  my $old_port = $old_dba->dbc->port;
  my $old_dbname = $old_dba->dbc->dbname;

  my $new_user = $new_dba->dbc->username;
  my $new_pass = $new_dba->dbc->password?"-p".$new_dba->dbc->password:"";
  my $new_host = $new_dba->dbc->host;
  my $new_port = $new_dba->dbc->port;
  my $new_dbname = $new_dba->dbc->dbname;

  $new_dba->dbc->do("ALTER TABLE `conservation_score` DISABLE KEYS");
  my $conservation_score_fetch_sth = $old_dba->dbc->prepare("SELECT * FROM conservation_score".
      " WHERE genomic_align_block_id >= ? AND genomic_align_block_id < ? LIMIT 1");

  my $mysqldump = "mysqldump -u$old_user $old_pass -h$old_host -P$old_port".
	" --skip-disable-keys --insert-ignore -t $old_dbname";
  my $mysql = "mysql -u$new_user $new_pass -h$new_host -P$new_port $new_dbname";

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
    my $pipe = "$mysqldump -w \"$where\" conservation_score | $mysql";
    system($pipe);
    print "ok!\n";
  }
  $new_dba->dbc->do("ALTER TABLE `conservation_score` ENABLE KEYS");
}


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


use strict;
use warnings;

=head1 NAME

update_genome.pl

=head1 AUTHORS

 Javier Herrero et al.

=head1 CONTACT

Please email comments or questions to the public Ensembl
developers list at <http://lists.ensembl.org/mailman/listinfo/dev>.

Questions may also be sent to the Ensembl help desk at
<http://www.ensembl.org/Help/Contact>.

=head1 DESCRIPTION

This script's main purpose is to take the new core DB and a compara DB
in production phase and update it in several steps:
 - It updates the genome_db table
 - It updates all the dnafrags for the given genome_db
 - It updates all the collections for the given genome_db

It can also edit a few properties like:
 - Turn assembly_default to 0 for a genome_db
 - Add a genome_db to a collection species set
 - Remove a genome_db from a collection species set

=head1 SYNOPSIS

  perl update_genome.pl --help

  perl update_genome.pl
    [--reg_conf registry_configuration_file]
    --compara compara_db_name_or_alias
    --species new_species_db_name_or_alias
    [--species_name "Species name"]
    [--taxon_id 1234]
    [--[no]force]
    [--offset 1000]
    [--collection "collection name"]
    [--remove_from_collection | --add_to_collection | --set_non_default]

=head1 OPTIONS

=head2 GETTING HELP

=over

=item B<[--help]>

Prints help message and exits.

=back

=head2 GENERAL CONFIGURATION

=over

=item B<[--reg_conf registry_configuration_file]>

The Bio::EnsEMBL::Registry configuration file. If none given,
the one set in ENSEMBL_REGISTRY will be used if defined, if not
~/.ensembl_init will be used.

=back

=head2 DATABASES

=over

=item B<--compara compara_db_name_or_alias>

The compara database to update. You can use either the original name or any of the
aliases given in the registry_configuration_file

=item B<--species new_species_db_name_or_alias>

The core database of the species to update. You can use either the original name or
any of the aliases given in the registry_configuration_file

=back

=head2 OPTIONS

=over

=item B<[--species_name "Species name"]>

Set up the species name. This is needed when the core database
misses this information

=item B<[--taxon_id 1234]>

Set up the NCBI taxon ID. This is needed when the core database
misses this information

=item B<[--[no]force]>

This scripts fails if the genome_db table of the compara DB
already matches the new species DB. This options allows you
to overcome this. USE ONLY IF YOU REALLY KNOW WHAT YOU ARE
DOING!

=item B<[--offset 1000]>

This allows you to offset identifiers assigned to Genome DBs by a given
amount. If not specified we assume we will use the autoincrement key
offered by the Genome DB table. If given then IDs will start
from that number (and we will assign according to the current number
of Genome DBs exceeding the offset). First ID will be equal to the
offset+1

=item B<[--collection "Collection name"]>

Adds the new / updated genome_db_id to the collection. This option
can be used multiple times

=item B<[--remove_from_collection | --add_to_collection || --set_non_default]>

(exclusive) options to respectively remove the species from its
collections, add the species to more collections, and set the
species as non-default

=back

=head1 INTERNAL METHODS

=cut

use Bio::EnsEMBL::Registry;
use Bio::EnsEMBL::Utils::Exception qw(throw warning verbose);
use Bio::EnsEMBL::Utils::SqlHelper;

use Bio::EnsEMBL::Compara::Utils::CoreDBAdaptor;

use Getopt::Long;

my $help;
my $reg_conf;
my $compara;
my $species = "";
my $species_name;
my $taxon_id;
my $force = 0;
my $offset = 0;
my @collection = ();
my $action_remove_from_collection = 0;
my $action_add_to_collection = 0;
my $action_set_non_default = 0;

GetOptions(
    "help" => \$help,
    "reg_conf=s" => \$reg_conf,
    "compara=s" => \$compara,
    "species=s" => \$species,
    "species_name=s" => \$species_name,
    "taxon_id=i" => \$taxon_id,
    "force!" => \$force,
    'offset=i' => \$offset,
    "collection=s@" => \@collection,
    "remove_from_collection!" => \$action_remove_from_collection,
    "add_to_collection!" => \$action_add_to_collection,
    "set_non_default!" => \$action_set_non_default,
  );

$| = 0;

# Print Help and exit if help is requested
if ($help or !$species or !$compara) {
    use Pod::Usage;
    pod2usage({-exitvalue => 0, -verbose => 2});
}

die "'remove_from_collection', 'add_to_collection', and 'set_non_default' are exclusive options\n" if
    ($action_set_non_default and ($action_remove_from_collection or $action_add_to_collection))
    or ($action_remove_from_collection and $action_add_to_collection);

my $species_no_underscores = $species;
$species_no_underscores =~ s/\_/\ /;

##
## Configure the Bio::EnsEMBL::Registry
## Uses $reg_conf if supplied. Uses ENV{ENSMEBL_REGISTRY} instead if defined. Uses
## ~/.ensembl_init if all the previous fail.
##
Bio::EnsEMBL::Registry->load_all($reg_conf);

my $species_db = Bio::EnsEMBL::Registry->get_DBAdaptor($species, "core");
if(! $species_db) {
    $species_db = Bio::EnsEMBL::Registry->get_DBAdaptor($species_no_underscores, "core");
}
throw ("Cannot connect to database [${species_no_underscores} or ${species}]") if (!$species_db);

my $compara_db = Bio::EnsEMBL::Registry->get_DBAdaptor($compara, "compara");
throw ("Cannot connect to database [$compara]") if (!$compara_db);
my $helper = Bio::EnsEMBL::Utils::SqlHelper->new(-DB_CONNECTION => $compara_db->dbc);

$helper->transaction( -CALLBACK => sub {
    if ($action_set_non_default or $action_remove_from_collection or $action_add_to_collection) {
        my $genome_db_adaptor = $compara_db->get_GenomeDBAdaptor();
        my $genome_db = $genome_db_adaptor->fetch_by_core_DBAdaptor($species_db);

        if ($action_set_non_default) {
            $genome_db_adaptor->set_non_default($genome_db);
            remove_species_from_collections($compara_db, $genome_db, \@collection);
        } elsif ($action_remove_from_collection) {
            remove_species_from_collections($compara_db, $genome_db, \@collection);
        } else {
            add_to_collections($compara_db, [$genome_db], \@collection);
        }
        return;
    }
    my $genome_db = update_genome_db($species_db, $compara_db, $force);
    #delete_genomic_align_data($compara_db, $genome_db);
    #delete_syntenic_data($compara_db, $genome_db);
    update_dnafrags($compara_db, $genome_db, $species_db);
    my $component_genome_dbs = update_component_genome_dbs($genome_db, $species_db, $compara_db);
    foreach my $component_gdb (@$component_genome_dbs) {
        update_dnafrags($compara_db, $component_gdb, $species_db);
    }
    add_to_collections($compara_db, [$genome_db, @$component_genome_dbs], \@collection);
    print_method_link_species_sets_to_update($compara_db, $genome_db);
} );

exit(0);


=head2 update_genome_db

  Arg[1]      : Bio::EnsEMBL::DBSQL::DBAdaptor $species_dba
  Arg[2]      : Bio::EnsEMBL::Compara::DBSQL::DBAdaptor $compara_dba
  Arg[3]      : bool $force
  Description : This method takes all the information needed from the
                species database in order to update the genome_db table
                of the compara database
  Returns     : The new Bio::EnsEMBL::Compara::GenomeDB object
  Exceptions  : throw if the genome_db table is up-to-date unless the
                --force option has been activated

=cut

sub update_genome_db {
  my ($species_dba, $compara_dba, $force) = @_;

  my $genome_db_adaptor = $compara_dba->get_GenomeDBAdaptor();
  my $genome_db = eval {$genome_db_adaptor->fetch_by_core_DBAdaptor($species_dba)};

  if ($genome_db and $genome_db->dbID) {
    if (not $force) {
      my $species_production_name = $genome_db->name;
      my $this_assembly = $genome_db->assembly;
      throw "GenomeDB with this name [$species_production_name] and assembly".
        " [$this_assembly] is already in the compara DB [$compara]\n".
        "You can use the --force option IF YOU REALLY KNOW WHAT YOU ARE DOING!!";
    }
  } elsif ($force) {
    print "GenomeDB with this name [$species_name] and the correct assembly".
        " is not in the compara DB [$compara]\n".
        "You don't need the --force option!!";
    print "Press [Enter] to continue or Ctrl+C to cancel...";
    <STDIN>;
  }


  if ($genome_db) {

    print "GenomeDB before update: ", $genome_db->toString, "\n";

    # Get fresher information from the core database
    $genome_db->db_adaptor($species_dba, 1);
    $genome_db->assembly_default(1);

    # And store it back in Compara
    $genome_db_adaptor->update($genome_db);

    print "GenomeDB after update: ", $genome_db->toString, "\n\n";

  }
  ## New genome or new assembly!!
  else {

    $genome_db = Bio::EnsEMBL::Compara::GenomeDB->new(
        -DB_ADAPTOR => $species_dba,

        -TAXON_ID   => $taxon_id,
        -NAME       => $species_name,
    );

    if (!defined($genome_db->taxon_id)) {
      throw "Cannot find species.taxonomy_id in meta table for $species_name.\n".
          "   You can use the --taxon_id option";
    }
    print "New GenomeDB for Compara: ", $genome_db->toString, "\n";

    #New ID search if $offset is true

    if($offset) {
        my ($max_id) = $compara_dba->dbc->db_handle->selectrow_array('select max(genome_db_id) from genome_db where genome_db_id > ?', undef, $offset);
    	if(!$max_id) {
    		$max_id = $offset;
    	}
      $genome_db->dbID($max_id + 1);
    }

    $genome_db_adaptor->store($genome_db);
    print " -> Successfully stored with genome_db_id=".$genome_db->dbID."\n\n";
    printf("You can add a new 'ensembl alias name' entry in scripts/taxonomy/ensembl_aliases.sql to map the taxon_id %d to '%s'\n", $genome_db->taxon_id, $species_dba->get_MetaContainer->get_common_name());

  }
  return $genome_db;
}


=head2 update_component_genome_dbs

  Description : Updates all the genome components (only for polyploid genomes)
  Returns     : -none-
  Exceptions  : none

=cut

sub update_component_genome_dbs {
    my ($principal_genome_db, $species_dba, $compara_dba) = @_;

    my @gdbs = ();
    my $genome_db_adaptor = $compara_dba->get_GenomeDBAdaptor();
    foreach my $c (@{$species_dba->get_GenomeContainer->get_genome_components}) {
        my $copy_genome_db = $principal_genome_db->make_component_copy($c);
        $genome_db_adaptor->store($copy_genome_db);
        push @gdbs, $copy_genome_db;
        print "Component '$c' genome_db: ", $copy_genome_db->toString(), "\n";
    }
    return \@gdbs;
}


=head2 add_to_collections

  Arg[1]      : Bio::EnsEMBL::Compara::DBSQL::DBAdaptor $compara_dba
  Arg[2]      : Arrayref of Bio::EnsEMBL::Compara::GenomeDB $genome_db
  Arg[3]      : Array reference of strings (the collections to add the species to)
  Description : This method updates all the collection species sets to
                include the new genome_dbs (they are supposed to all have the same name)
  Returns     : -none-
  Exceptions  : throw if any SQL statment fails

=cut

sub add_to_collections {
  my ($compara_dba, $genome_dbs, $all_collections) = @_;

  my $gdb_name = $genome_dbs->[0]->name;
  # Gets all the collections with that genome_db
  my $ssa = $compara_dba->get_SpeciesSetAdaptor;
  my $sss = $ssa->fetch_all_collections_by_genome($gdb_name);
  push @$sss, @{_fetch_all_collections_by_name($ssa, $all_collections)};

  my %seen = ();
  foreach my $ss (@$sss) {
      next if $seen{$ss->dbID};
      $seen{$ss->dbID} = 1;
      my $new_genome_dbs = [grep {$_->name ne $gdb_name} @{$ss->genome_dbs}];
      push @$new_genome_dbs, @$genome_dbs;
      my $new_ss = $ssa->update_collection($ss, $new_genome_dbs);
      printf("%s added to the collection '%s' (species_set_id=%d)\n", $gdb_name, $ss->get_value_for_tag('name'), $new_ss->dbID);
  }
}

=head2 remove_species_from_collections

  Arg[1]      : Bio::EnsEMBL::Compara::DBSQL::DBAdaptor $compara_dba
  Arg[2]      : Bio::EnsEMBL::Compara::GenomeDB $genome_db
  Arg[3]      : arrayref of string $all_collection_names (optional)
  Description : This method updates the collection species sets to
                exclude the given $genome_db. Updates them all unless
                $all_collection_names is given
  Returns     : -none-
  Exceptions  : throw if any SQL statment fails

=cut

sub remove_species_from_collections {
    my ($compara_dba, $genome_db, $all_collection_names) = @_;

    my $sss;
    my $ssa = $compara_dba->get_SpeciesSetAdaptor;

    if ($all_collection_names and scalar(@$all_collection_names)) {
        $sss = _fetch_all_collections_by_name($ssa, $all_collection_names);
    } else {
        $sss = $ssa->fetch_all_collections_by_genome($genome_db->dbID);
    }

    foreach my $ss (@$sss) {
        my $new_genome_dbs = [grep {$_->dbID != $genome_db->dbID} @{$ss->genome_dbs}];
        next if scalar(@$new_genome_dbs) == scalar(@{$ss->genome_dbs});
        my $new_ss = $ssa->update_collection($ss, $new_genome_dbs);
        printf("%s removed from the collection '%s' (species_set_id=%d)\n", $genome_db->name, $ss->get_value_for_tag('name'), $new_ss->dbID);
    }
}

# Wrapper around Bio::EnsEMBL::Compara::DBSQL::SpeciesSetAdaptor::fetch_collection_by_name
sub _fetch_all_collections_by_name {
    my ($ssa, $all_collection_names) = @_;

    my @sss;
    foreach my $collection (@{$all_collection_names || []}) {
        my $c = $ssa->fetch_collection_by_name($collection);
        push @sss, $c if $c;
    }
    return \@sss;
}

=head2 delete_genomic_align_data

  Arg[1]      : Bio::EnsEMBL::Compara::DBSQL::DBAdaptor $compara_dba
  Arg[2]      : Bio::EnsEMBL::Compara::GenomeDB $genome_db
  Description : This method deletes from the genomic_align and 
                genomic_align_block tables
                all the rows that refer to the species identified
                by the $genome_db_id
  Returns     : -none-
  Exceptions  : throw if any SQL statment fails

=cut

sub delete_genomic_align_data {
  my ($compara_dba, $genome_db) = @_;

  print "Getting the list of genomic_align_block_id to remove... ";
  my $rows = $compara_dba->dbc->do(qq{
      CREATE TABLE list AS
          SELECT genomic_align_block_id
          FROM genomic_align_block, method_link_species_set
          WHERE genomic_align_block.method_link_species_set_id = method_link_species_set.method_link_species_set_id
          AND genome_db_id = $genome_db->{dbID}
    });
  throw $compara_dba->dbc->errstr if (!$rows);
  print "$rows elements found.\n";

  print "Deleting corresponding genomic_align and genomic_align_block rows...";
  $rows = $compara_dba->dbc->do(qq{
      DELETE
        genomic_align, genomic_align_block
      FROM
        list
        LEFT JOIN genomic_align_block USING (genomic_align_block_id)
        LEFT JOIN genomic_align USING (genomic_align_block_id)
      WHERE
        list.genomic_align_block_id = genomic_align.genomic_align_block_id
    });
  throw $compara_dba->dbc->errstr if (!$rows);
  print " ok!\n";

  print "Droping the list of genomic_align_block_ids...";
  $rows = $compara_dba->dbc->do(qq{DROP TABLE list});
  throw $compara_dba->dbc->errstr if (!$rows);
  print " ok!\n\n";
}

=head2 delete_syntenic_data

  Arg[1]      : Bio::EnsEMBL::Compara::DBSQL::DBAdaptor $compara_dba
  Arg[2]      : Bio::EnsEMBL::Compara::GenomeDB $genome_db
  Description : This method deletes from the dnafrag_region
                and synteny_region tables all the rows that refer
                to the species identified by the $genome_db_id
  Returns     : -none-
  Exceptions  : throw if any SQL statment fails

=cut

sub delete_syntenic_data {
  my ($compara_dba, $genome_db) = @_;

  print "Deleting dnafrag_region and synteny_region rows...";
  my $rows = $compara_dba->dbc->do(qq{
      DELETE
        dnafrag_region, synteny_region
      FROM
        dnafrag_region
        LEFT JOIN synteny_region USING (synteny_region_id)
        LEFT JOIN method_link_species_set USING (method_link_species_set_id)
      WHERE genome_db_id = $genome_db->{dbID}
    });
  throw $compara_dba->dbc->errstr if (!$rows);
  print " ok!\n\n";
}

=head2 update_dnafrags

  Arg[1]      : Bio::EnsEMBL::Compara::DBSQL::DBAdaptor $compara_dba
  Arg[2]      : Bio::EnsEMBL::Compara::GenomeDB $genome_db
  Arg[3]      : Bio::EnsEMBL::DBSQL::DBAdaptor $species_dba
  Description : This method fetches all the dnafrag in the compara DB
                corresponding to the $genome_db. It also gets the list
                of top_level seq_regions from the species core DB and
                updates the list of dnafrags in the compara DB.
  Returns     : -none-
  Exceptions  :

=cut

sub update_dnafrags {
  my ($compara_dba, $genome_db, $species_dba) = @_;

  my $dnafrag_adaptor = $compara_dba->get_adaptor("DnaFrag");
  my $old_dnafrags = $dnafrag_adaptor->fetch_all_by_GenomeDB_region($genome_db);
  my $old_dnafrags_by_id;
  foreach my $old_dnafrag (@$old_dnafrags) {
    $old_dnafrags_by_id->{$old_dnafrag->dbID} = $old_dnafrag;
  }

  my $gdb_slices = $genome_db->genome_component
    ? $species_dba->get_SliceAdaptor->fetch_all_by_genome_component($genome_db->genome_component)
    : $species_dba->get_SliceAdaptor->fetch_all('toplevel', undef, 1, 1, 1);
  die "Could not fetch any toplevel slices from ".$genome_db->name() unless(scalar(@$gdb_slices));

  my $current_verbose = verbose();
  verbose('EXCEPTION');

  foreach my $slice (@$gdb_slices) {
    my $length = $slice->seq_region_length;
    my $name = $slice->seq_region_name;
    my $coordinate_system_name = $slice->coord_system_name;

    #Find out if region is_reference or not
    my $is_reference = $slice->is_reference;

    my $new_dnafrag = new Bio::EnsEMBL::Compara::DnaFrag(
            -genome_db => $genome_db,
            -coord_system_name => $coordinate_system_name,
            -name => $name,
            -length => $length,
            -is_reference => $is_reference
        );
    my $dnafrag_id = $dnafrag_adaptor->update($new_dnafrag);
    delete($old_dnafrags_by_id->{$dnafrag_id});
    throw() if ($old_dnafrags_by_id->{$dnafrag_id});
  }
  verbose($current_verbose);
  print "Deleting ", scalar(keys %$old_dnafrags_by_id), " former DnaFrags...";
  foreach my $deprecated_dnafrag_id (keys %$old_dnafrags_by_id) {
    $compara_dba->dbc->do("DELETE FROM dnafrag WHERE dnafrag_id = ".$deprecated_dnafrag_id) ;
  }
  print "  ok!\n\n";
}

=head2 print_method_link_species_sets_to_update

  Arg[1]      : Bio::EnsEMBL::Compara::DBSQL::DBAdaptor $compara_dba
  Arg[2]      : Bio::EnsEMBL::Compara::GenomeDB $genome_db
  Description : This method prints all the genomic MethodLinkSpeciesSet
                that need to be updated (those which correspond to the
                $genome_db).
                NB: Only method_link with a dbID <200 are taken into
                account (they should be the genomic ones)
  Returns     : -none-
  Exceptions  :

=cut

sub print_method_link_species_sets_to_update {
  my ($compara_dba, $genome_db) = @_;

  my $method_link_species_set_adaptor = $compara_dba->get_adaptor("MethodLinkSpeciesSet");
  my $genome_db_adaptor = $compara_dba->get_adaptor("GenomeDB");

  my $method_link_species_sets;
  foreach my $this_genome_db (@{$genome_db_adaptor->fetch_all()}) {
    next if ($this_genome_db->name ne $genome_db->name);
    foreach my $this_method_link_species_set (@{$method_link_species_set_adaptor->fetch_all_by_GenomeDB($this_genome_db)}) {
      $method_link_species_sets->{$this_method_link_species_set->method->dbID}->
          {join("-", sort map {$_->name} @{$this_method_link_species_set->species_set_obj->genome_dbs})} = $this_method_link_species_set;
    }
  }

  print "List of Bio::EnsEMBL::Compara::MethodLinkSpeciesSet to update:\n";
  foreach my $this_method_link_id (sort {$a <=> $b} keys %$method_link_species_sets) {
    last if ($this_method_link_id > 200); # Avoid non-genomic method_link_species_set
    foreach my $this_method_link_species_set (values %{$method_link_species_sets->{$this_method_link_id}}) {
      printf "%8d: ", $this_method_link_species_set->dbID,;
      print $this_method_link_species_set->method->type, " (",
          join(",", map {$_->name} @{$this_method_link_species_set->species_set_obj->genome_dbs}), ")\n";
    }
  }

}

=head2 create_new_method_link_species_sets

  Arg[1]      : Bio::EnsEMBL::Compara::DBSQL::DBAdaptor $compara_dba
  Arg[2]      : Bio::EnsEMBL::Compara::GenomeDB $genome_db
  Description : This method creates all the genomic MethodLinkSpeciesSet
                that are needed for the new assembly.
                NB: Only method_link with a dbID <200 are taken into
                account (they should be the genomic ones)
  Returns     : -none-
  Exceptions  :

=cut

sub create_new_method_link_species_sets {
  my ($compara_dba, $genome_db) = @_;

  my $method_link_species_set_adaptor = $compara_dba->get_adaptor("MethodLinkSpeciesSet");
  my $genome_db_adaptor = $compara_dba->get_adaptor("GenomeDB");

  my $method_link_species_sets;
  my $all_genome_dbs = $genome_db_adaptor->fetch_all();
  foreach my $this_genome_db (@$all_genome_dbs) {
    next if ($this_genome_db->name ne $genome_db->name);
    foreach my $this_method_link_species_set (@{$method_link_species_set_adaptor->fetch_all_by_GenomeDB($this_genome_db)}) {
      $method_link_species_sets->{$this_method_link_species_set->method->dbID}->
          {join("-", sort map {$_->name} @{$this_method_link_species_set->species_set_obj->genome_dbs})} = $this_method_link_species_set;
    }
  }

  print "List of Bio::EnsEMBL::Compara::MethodLinkSpeciesSet to update:\n";
  foreach my $this_method_link_id (sort {$a <=> $b} keys %$method_link_species_sets) {
    last if ($this_method_link_id > 200); # Avoid non-genomic method_link_species_set
    foreach my $this_method_link_species_set (values %{$method_link_species_sets->{$this_method_link_id}}) {
      printf "%8d: ", $this_method_link_species_set->dbID,;
      print $this_method_link_species_set->method->type, " (",
          join(",", map {$_->name} @{$this_method_link_species_set->species_set_obj->genome_dbs}), ")\n";
    }
  }

}

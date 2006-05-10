#!/usr/bin/env perl

use warnings;
use strict;

my $description = q{
###########################################################################
##
## PROGRAM populate_new_database.pl
##
## AUTHORS
##    Javier Herrero (jherrero@ebi.ac.uk)
##
## COPYRIGHT
##    This script is part of the Ensembl project http://www.ensembl.org
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

 Javier Herrero (jherrero@ebi.ac.uk)

=head1 COPYRIGHT

This script is part of the Ensembl project http://www.ensembl.org

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
    --master new_database_name
    --old new_database_name
    --new new_database_name

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
aliases given in the registry_configuration_file. DEFAULT VALUE: compara-master

=item B<--old old_compara_db_name>

The old compara database. You can use either the original name or any of the
aliases given in the registry_configuration_file.

=item B<--new new_compara_db_name>

The new compara database. You can use either the original name or any of the
aliases given in the registry_configuration_file.

=back

=head2 GENERAL OPTIONS

=over

=item B<[--reg_conf registry_configuration_file]>

The Bio::EnsEMBL::Registry configuration file. If none given,
the one set in ENSEMBL_REGISTRY will be used if defined, if not
~/.ensembl_init will be used.

=back

=item B<[--[no]skip-data]>

Do not store DNA-DNA alignments nor synteny data.

=back

=cut

use Bio::EnsEMBL::Registry;
use Bio::EnsEMBL::Utils::Exception qw(throw warning);
use Getopt::Long;

my $help;

my $reg_conf;
my $skip_data = 0;
my $master = "compara-master";
my $old = undef;
my $new = undef;

GetOptions(
    "help" => \$help,
    "skip-data" => \$skip_data,
    "reg-conf=s" => \$reg_conf,
    "master=s" => \$master,
    "old=s" => \$old,
    "new=s" => \$new,
  );


# Print Help and exit if help is requested
if ($help or !$master or !$new) {
  exec("/usr/bin/env perldoc $0");
}

#################################################
## Get the DBAdaptors from the Registry
Bio::EnsEMBL::Registry->load_all($reg_conf);

my $master_dba = Bio::EnsEMBL::Registry->get_DBAdaptor($master, "compara");
$master_dba->get_MetaContainer; # tests that the DB exists

my $old_dba;
if ($old) {
  $old_dba = Bio::EnsEMBL::Registry->get_DBAdaptor($old, "compara");
  $old_dba->get_MetaContainer; # tests that the DB exists
}

my $new_dba = Bio::EnsEMBL::Registry->get_DBAdaptor($new, "compara");
$new_dba->get_MetaContainer; # tests that the DB exists
##
#################################################

## Sets the schema version for the new database
update_schema_version($master_dba, $new_dba);

## Copy taxa and method_link tables
copy_table($master_dba, $new_dba, "ncbi_taxa_names");
copy_table($master_dba, $new_dba, "ncbi_taxa_nodes");
copy_table($master_dba, $new_dba, "method_link");

## Get all the genome_dbs with a default assembly
my $all_default_genome_dbs = get_all_default_genome_dbs($master_dba);

## Store them in the new DB
store_objects($new_dba->get_GenomeDBAdaptor, $all_default_genome_dbs, "all default genome_dbs");

## Get all the MethodLinkSpeciesSet for the default assemblies
my $all_default_method_link_species_sets = get_all_method_link_species_sets($master_dba, $all_default_genome_dbs);

## Store them in the new DB
store_objects($new_dba->get_MethodLinkSpeciesSetAdaptor, $all_default_method_link_species_sets,
    "all previous valid method_link_species_sets");

## Copy all the DnaFrags for the default assemblies
copy_all_dnafrags($master_dba, $new_dba, $all_default_genome_dbs);

if ($old_dba and !$skip_data) {
  ## Copy DNA-DNA alignemnts
  copy_dna_dna_alignements($old_dba, $new_dba, $all_default_method_link_species_sets);

  ## Copy Synteny data
  copy_synteny_data($old_dba, $new_dba, $all_default_method_link_species_sets);
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

  my $sth = $from_dba->dbc->prepare("SELECT * FROM $table_name");
  $sth->execute();
  my $all_rows = $sth->fetchall_arrayref();
  $sth->finish;
  my $number_of_rows = scalar(@{$all_rows->[0]});
  $to_dba->dbc->do("TRUNCATE $table_name");
  $to_dba->dbc->do("ALTER TABLE $table_name DISABLE KEYS");
  $sth = $to_dba->dbc->prepare("INSERT INTO $table_name VALUES (?".(",?"x($number_of_rows-1)).")");
  foreach my $this_row (@$all_rows) {
    $sth->execute(@$this_row);
  }
  $sth->finish;
  $to_dba->dbc->do("ALTER TABLE $table_name ENABLE KEYS");
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
  my ($new_schema_version) = $old_dba->dbc->db_handle->selectrow_array(
      "SELECT meta_value FROM meta WHERE meta_key = 'schema_version'");

  if (!$new_schema_version and $old_schema_version =~ /^\d+$/) {
    $new_dba->dbc->do("DELETE FROM meta WHERE meta_key = 'schema_version'");
    $new_dba->dbc->do("INSERT INTO meta (meta_key, meta_value) VALUES ('schema_version', $old_schema_version+1)");
  }
}

=head2 get_all_default_genome_dbs

  Arg[1]      : Bio::EnsEMBL::Compara::DBSQL::DBAdaptor $compara_dba
  Description : get the list of all the default GenomeDBs, i.e. the
                GenomeDBs where the default_assembly is true.
  Returns     : listref of Bio::EnsEMBL::Compara::GenomeDB objects
  Exceptions  : throw if argument test fails

=cut

sub get_all_default_genome_dbs {
  my ($compara_dba) = @_;

  throw("[$compara_dba] should be a Bio::EnsEMBL::Compara::DBSQL::DBAdaptor")
      unless (UNIVERSAL::isa($compara_dba, "Bio::EnsEMBL::Compara::DBSQL::DBAdaptor"));

  my $genome_db_adaptor = $compara_dba->get_GenomeDBAdaptor();
  throw("Error while getting Bio::EnsEMBL::Compara::DBSQL::GenomeDBAdaptor")
      unless ($genome_db_adaptor);

  my $all_genome_dbs = $genome_db_adaptor->fetch_all();
  return [sort {$a->dbID <=> $b->dbID} grep {$_->assembly_default} @$all_genome_dbs];
}


=head2 get_all_method_link_species_sets

  Arg[1]      : Bio::EnsEMBL::Compara::DBSQL::DBAdaptor $compara_dba
  Arg[2]      : listref Bio::EnsEMBL::Compara::GenomeDB $genome_dbs
  Description : get the list of all the MethodLinkSpeciesSets which
                contain GenomeDBs from the $genome_dbs list only.
  Returns     : listref of Bio::EnsEMBL::Compara::MethodLinkSpeciesSet objects
  Exceptions  : throw if argument test fails

=cut

sub get_all_method_link_species_sets {
  my ($compara_dba, $genome_dbs) = @_;
  my $all_method_link_species_sets = {};

  throw("[$compara_dba] should be a Bio::EnsEMBL::Compara::DBSQL::DBAdaptor")
      unless (UNIVERSAL::isa($compara_dba, "Bio::EnsEMBL::Compara::DBSQL::DBAdaptor"));

  my $method_link_species_set_adaptor = $compara_dba->get_MethodLinkSpeciesSetAdaptor();
  throw("Error while getting Bio::EnsEMBL::Compara::DBSQL::MethodLinkSpeciesSetAdaptor")
      unless ($method_link_species_set_adaptor);

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
      my $all_included = 1;
      foreach my $this_included_genome_db (@{$this_method_link_species_set->species_set}) {
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


=head2 copy_all_dnafrags

  Arg[1]      : Bio::EnsEMBL::Compara::DBSQL::DBAdaptor $from_dba
  Arg[2]      : Bio::EnsEMBL::Compara::DBSQL::DBAdaptor $to_dba
  Arg[3]      : listref Bio::EnsEMBL::Compara::GenomeDB $genome_dbs
  Description : copy from $from_dba to $to_dba all the DnaFrags which
                correspond to GenomeDBs from the $genome_dbs list only.
  Returns     :
  Exceptions  : throw if argument test fails

=cut

sub copy_all_dnafrags {
  my ($from_dba, $to_dba, $genome_dbs) = @_;

  throw("[$from_dba] should be a Bio::EnsEMBL::Compara::DBSQL::DBAdaptor")
      unless (UNIVERSAL::isa($from_dba, "Bio::EnsEMBL::Compara::DBSQL::DBAdaptor"));

  throw("[$to_dba] should be a Bio::EnsEMBL::Compara::DBSQL::DBAdaptor")
      unless (UNIVERSAL::isa($to_dba, "Bio::EnsEMBL::Compara::DBSQL::DBAdaptor"));

  $new_dba->dbc->do("ALTER TABLE dnafrag DISABLE KEYS");
  my $dnafrag_fetch_sth = $from_dba->dbc->prepare("SELECT * FROM dnafrag".
      " WHERE genome_db_id = ?");
  foreach my $this_genome_db (@$genome_dbs) {
    $dnafrag_fetch_sth->execute($this_genome_db->dbID);
    my $rows = $dnafrag_fetch_sth->fetchrow_arrayref;
    if (!$rows) {
      next;
    }
    print "Copying dnafrag for ", $this_genome_db->name, "...\n";
    my $sth_insert = $to_dba->dbc->prepare("INSERT IGNORE INTO dnafrag VALUES (?".(",?"x(@$rows - 1)).")");
    do {
      $sth_insert->execute(@$rows);
    } while ($rows = $dnafrag_fetch_sth->fetchrow_arrayref);
  }
  print "Rebuilding indexes...\n";
  $new_dba->dbc->do("ALTER TABLE dnafrag ENABLE KEYS");
}


=head2 copy_dna_dna_alignements

  Arg[1]      : Bio::EnsEMBL::Compara::DBSQL::DBAdaptor $from_dba
  Arg[2]      : Bio::EnsEMBL::Compara::DBSQL::DBAdaptor $to_dba
  Arg[3]      : listref Bio::EnsEMBL::Compara::MethodLinkSpeciesSet $these_mlss
  Description : copy dna-dna alignments for the MethodLinkSpeciesSet listed
                in $these_mlss. Dna-dna alignments are stored in the
                genomic_aling_block, genomic_align and genomic_align_group
                tables.
  Returns     :
  Exceptions  : throw if argument test fails

=cut

sub copy_dna_dna_alignements {
  my ($old_dba, $new_dba, $method_link_species_sets) = @_;

  $new_dba->dbc->do("ALTER TABLE genomic_align_block DISABLE KEYS");
  $new_dba->dbc->do("ALTER TABLE genomic_align DISABLE KEYS");
  $new_dba->dbc->do("ALTER TABLE genomic_align_group DISABLE KEYS");
  foreach my $this_method_link_species_set (@$method_link_species_sets) {
    my $sql = "SELECT * FROM genomic_align_block WHERE genomic_align_block_id >= ".
        ($this_method_link_species_set->dbID * 10**10)." AND genomic_align_block_id < ".
        (($this_method_link_species_set->dbID + 1) * 10**10);
    my $sth_fetch = $old_dba->dbc->prepare($sql);
    $sth_fetch->execute();
    my $rows = $sth_fetch->fetchrow_arrayref;
    if (!$rows) {
      next;
    }
    print "Copying dna-dna alignments for ", $this_method_link_species_set->name, "...\n";
    my $sth_insert = $new_dba->dbc->prepare("INSERT IGNORE INTO genomic_align_block VALUES (?".(",?"x(@$rows - 1)).")");
    do {
      $sth_insert->execute(@$rows);
    } while ($rows = $sth_fetch->fetchrow_arrayref);

    $sql = "SELECT * FROM genomic_align WHERE genomic_align_id >= ".
        ($this_method_link_species_set->dbID * 10**10)." AND genomic_align_id < ".
        (($this_method_link_species_set->dbID + 1) * 10**10);
    $sth_fetch = $old_dba->dbc->prepare($sql);
    $sth_fetch->execute();
    $rows = $sth_fetch->fetchrow_arrayref;
    if (!$rows) {
      next;
    }
    $sth_insert = $new_dba->dbc->prepare("INSERT IGNORE INTO genomic_align VALUES (?".(",?"x(@$rows - 1)).")");
    do {
      $sth_insert->execute(@$rows);
    } while ($rows = $sth_fetch->fetchrow_arrayref);

    $sql = "SELECT * FROM genomic_align_group WHERE group_id >= ".
        ($this_method_link_species_set->dbID * 10**10)." AND group_id < ".
        (($this_method_link_species_set->dbID + 1) * 10**10);
    $sth_fetch = $old_dba->dbc->prepare($sql);
    $sth_fetch->execute();
    $rows = $sth_fetch->fetchrow_arrayref;
    if (!$rows) {
      next;
    }
    $sth_insert = $new_dba->dbc->prepare("INSERT IGNORE INTO genomic_align_group VALUES (?".(",?"x(@$rows - 1)).")");
    do {
      $sth_insert->execute(@$rows);
    } while ($rows = $sth_fetch->fetchrow_arrayref);
  }
  print "Rebuilding indexes...\n";
  $new_dba->dbc->do("ALTER TABLE genomic_align_block ENABLE KEYS");
  $new_dba->dbc->do("ALTER TABLE genomic_align ENABLE KEYS");
  $new_dba->dbc->do("ALTER TABLE genomic_align_group ENABLE KEYS");
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

  $new_dba->dbc->do("ALTER TABLE synteny_region DISABLE KEYS");
  $new_dba->dbc->do("ALTER TABLE dnafrag_region DISABLE KEYS");
  my $synteny_region_fetch_sth = $old_dba->dbc->prepare("SELECT * FROM synteny_region".
      " WHERE method_link_species_set_id = ?");
  my $dnafrag_region_fetch_sth = $old_dba->dbc->prepare("SELECT dnafrag_region.* FROM synteny_region".
      " LEFT JOIN dnafrag_region using (synteny_region_id) WHERE method_link_species_set_id = ?");
  foreach my $this_method_link_species_set (@$method_link_species_sets) {
    $synteny_region_fetch_sth->execute($this_method_link_species_set->dbID);
    my $rows = $synteny_region_fetch_sth->fetchrow_arrayref;
    if (!$rows) {
      next;
    }
    print "Copying synteny data for ", $this_method_link_species_set->name, "...\n";
    my $sth_insert = $new_dba->dbc->prepare("INSERT IGNORE INTO synteny_region VALUES (?".(",?"x(@$rows - 1)).")");
    do {
      $sth_insert->execute(@$rows);
    } while ($rows = $synteny_region_fetch_sth->fetchrow_arrayref);

    $dnafrag_region_fetch_sth->execute($this_method_link_species_set->dbID);
    $rows = $dnafrag_region_fetch_sth->fetchrow_arrayref;
    if (!$rows) {
      next;
    }
    $sth_insert = $new_dba->dbc->prepare("INSERT IGNORE INTO dnafrag_region VALUES (?".(",?"x(@$rows - 1)).")");
    do {
      $sth_insert->execute(@$rows);
    } while ($rows = $dnafrag_region_fetch_sth->fetchrow_arrayref);
  }
  print "Rebuilding indexes...\n";
  $new_dba->dbc->do("ALTER TABLE synteny_region ENABLE KEYS");
  $new_dba->dbc->do("ALTER TABLE dnafrag_region ENABLE KEYS");
}


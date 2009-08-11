# Copyright EnsEMBL 2004
#
# Ensembl module for Bio::EnsEMBL::DBSQL::MethodLinkSpeciesAdaptor
#
# POD documentation - main docs before the code
#

=head1 NAME

Bio::EnsEMBL::DBSQL::MethodLinkSpeciesSetAdaptor - Object to access data in the method_link_species_set
and method_link tables

=head1 SYNOPSIS

=head2 Connecting to the database using the old way:

  use Bio::EnsEMBL::Compara::DBSQL::DBAdaptor;
  my $db = new Bio::EnsEMBL::Compara::DBSQL::DBAdaptor (
      -host => $host,
      -user => $dbuser,
      -pass => $dbpass,
      -port => $port,
      -dbname => $dbname,
      -conf_file => $conf_file);

  my $mlssa = $db->get_MethodLinkSpeciesSetAdaptor();

=head2 Connecting to the database using the new way (recommended):

  use Bio::EnsEMBL::Registry;
  Bio::EnsEMBL::Registry->load_all($conf_file); # $conf_file can be undef

  use Bio::EnsEMBL::Registry;
  Bio::EnsEMBL::Registry->load_all($conf_file); # $conf_file can be undef

  Bio::EnsEMBL::Registry->load_all();

  my $mlssa = Bio::EnsEMBL::Registry->get_adaptor(
      $compara_db_name, "compara", "MethodLinkSpeciesSet");

=head2 Store/Delete data from the database

  $mlssa->store($method_link_species_set);

=head2 Retrieve data from the database

  my $method_link_species_sets = $mlssa->fetch_all;

  my $method_link_species_set = $mlssa->fetch_by_dbID(1);

  my $method_link_species_set = $mlssa->fetch_by_method_link_type_registry_aliases(
        "BLASTZ_NET", ["human", "Mus musculus"]);

  my $method_link_species_sets = $mlssa->fetch_all_by_method_link_type("BLASTZ_NET");

  my $method_link_species_sets = $mlssa->fetch_all_by_GenomeDB($genome_db);

  my $method_link_species_sets = $mlssa->fetch_all_by_method_link_type_GenomeDB(
        "PECAN", $gdb1);

  my $method_link_species_set = $mlssa->fetch_by_method_link_type_GenomeDBs(
        "TRANSLATED_BLAT", [$gdb1, $gdb2]);

=head1 DESCRIPTION

This object is intended for accessing data in the method_link and method_link_species_set tables.

=head1 INHERITANCE

This class inherits all the methods and attributes from Bio::EnsEMBL::DBSQL::BaseAdaptor

=head1 SEE ALSO

 - Bio::EnsEMBL::Registry
 - Bio::EnsEMBL::DBSQL::BaseAdaptor
 - Bio::EnsEMBL::BaseAdaptor
 - Bio::EnsEMBL::Compara::MethodLinkSpeciesSet
 - Bio::EnsEMBL::Compara::GenomeDB
 - Bio::EnsEMBL::Compara::DBSQL::GenomeDBAdaptor

=head1 AUTHOR

Javier Herrero (jherrero@ebi.ac.uk)

This modules is part of the Ensembl project http://www.ensembl.org

=head1 COPYRIGHT

Copyright (c) 2004. EnsEMBL Team

This modules is part of the EnsEMBL project (http://www.ensembl.org). You may distribute
it under the same terms as EnsEMBL itself.

=head1 CONTACT

Questions can be posted to the ensembl-dev mailing list: ensembl-dev@ebi.ac.uk

=head1 APPENDIX

The rest of the documentation details each of the object methods. Internal methods are usually preceded with a _

=cut


# Let the code begin...


package Bio::EnsEMBL::Compara::DBSQL::MethodLinkSpeciesSetAdaptor;
use vars qw(@ISA);
use strict;

use Bio::EnsEMBL::Registry;
use Bio::EnsEMBL::Compara::MethodLinkSpeciesSet;
use Bio::EnsEMBL::Utils::Exception;

@ISA = qw(Bio::EnsEMBL::DBSQL::BaseAdaptor);

my $DEFAULT_MAX_ALIGNMENT = 20000;

sub new {
  my $class = shift;

  my $self = $class->SUPER::new(@_);

  return $self;
}


=head2 store

  Arg  1     : Bio::EnsEMBL::Compara::MethodLinkSpeciesSet object
  Example    : $mlssa->store($method_link_species_set)
  Description: Stores a Bio::EnsEMBL::Compara::MethodLinkSpeciesSet object into
               the database if it does not exist yet. It also stores or updates
               accordingly the meta table if this object has a
               max_alignment_length attribute.
  Returntype : Bio::EnsEMBL::Compara::MethodLinkSpeciesSet object
  Exception  : Thrown if the argument is not a
               Bio::EnsEMBL::Compara::MethodLinkSpeciesSet object
  Exception  : Thrown if the corresponding method_link is not in the
               database
  Caller     :

=cut

sub store {
  my ($self, $method_link_species_set) = @_;

  throw("method_link_species_set must be a Bio::EnsEMBL::Compara::MethodLinkSpeciesSet\n")
    unless ($method_link_species_set && ref $method_link_species_set &&
        $method_link_species_set->isa("Bio::EnsEMBL::Compara::MethodLinkSpeciesSet"));

  $method_link_species_set->adaptor($self);

  my $method_link_sql = qq{SELECT 1 FROM method_link WHERE method_link_id = ?};
  my $method_link_type_sql   = qq{SELECT method_link_id from method_link where type = ?};
  my $method_link_insert_sql = qq{INSERT INTO method_link (type, class) VALUES(?, ?)};

  my $method_link_species_set_sql = qq{
        INSERT IGNORE INTO method_link_species_set (
          method_link_species_set_id,
          method_link_id,
          species_set_id,
          name,
          source,
          url)
        VALUES (?, ?, ?, ?, ?, ?)
    };

  my $method_link_id   = $method_link_species_set->method_link_id;
  my $method_link_type = $method_link_species_set->method_link_type;
  my $method_link_class = ($method_link_species_set->method_link_class or "");
  my $species_set = $method_link_species_set->species_set;



  ## If we have method_link_type but no method_link_id
  if( $method_link_type and ! $method_link_id ){
    # Is the type in the DB?
    my $sth = $self->prepare($method_link_type_sql);
    $sth->execute( $method_link_type );
    ($method_link_id) = $sth->fetchrow_array;
    $sth->finish();
    if( ! $method_link_id ) {
      # Insert new
      $sth = $self->prepare($method_link_insert_sql);
      $sth->execute( $method_link_type, $method_link_class );
      $method_link_id = $sth->{'mysql_insertid'};
      $sth->finish();
    }
    # Update the object
    $method_link_species_set->method_link_id($method_link_id);
  }

  ## Checks if method_link_id already exists in the database
  my $sth = $self->prepare($method_link_sql);
  $sth->execute($method_link_id);
  my ($has_ml) = $sth->fetchrow_array();
  $sth->finish();
  if (!$has_ml) {
    throw("method_link_id $method_link_id is not in the database!\n");
  }

  ## Fetch genome_db_ids from Bio::EnsEMBL::Compara::GenomeDB objects
  my @genome_db_ids;
  foreach my $species (@$species_set) {
    push(@genome_db_ids, $species->dbID);
  }

  my $dbID;
  my $already_existing_method_link_species_set =
      $self->fetch_by_method_link_type_GenomeDBs($method_link_type,$species_set, 1);
  if ($already_existing_method_link_species_set) {
    $dbID = $already_existing_method_link_species_set->dbID;
  }

  if (!$dbID) {
    ## Lock the table in order to avoid a concurrent process to store the same object with a different dbID
    # from mysql documentation 13.4.5 :
    #   "If your queries refer to a table using an alias, then you must lock the table using that same alias.
    #   "It will not work to lock the table without specifying the alias"
    #Thus we need to lock method_link_species_set as a, method_link_species_set as b, and method_link_species_set

		my $original_dwi = $self->dbc()->disconnect_when_inactive();
  	$self->dbc()->disconnect_when_inactive(0);

    $self->dbc->do(qq{ LOCK TABLES method_link WRITE,
                       method_link_species_set as mlss WRITE,
                       method_link_species_set as mlss1 WRITE,
                       method_link_species_set as mlss2 WRITE,
                       method_link as ml WRITE,
                       species_set WRITE,
                       species_set as ss WRITE,
                       species_set as ss1 WRITE,
                       species_set as ss2 WRITE,
                       method_link_species_set WRITE });

    # Now, check if the object has not been stored before (tables are locked)
    $already_existing_method_link_species_set =
        $self->fetch_by_method_link_type_GenomeDBs($method_link_type,$species_set, 1);
    if ($already_existing_method_link_species_set) {
      $dbID = $already_existing_method_link_species_set->dbID;
    }

    # If the object still does not exist in the DB, store it
    if (!$dbID) {
      $dbID = $method_link_species_set->dbID();
      if (!$dbID) {
        ## Use convetion rule for getting a new dbID. At the moment, we yse the following
        ## ranges:
        ##
        ## dna-dna alignments: method_link_id E [1-100], method_link_species_set_id E [1-10000]
        ## synteny:            method_link_id E [101-100], method_link_species_set_id E [10001-20000]
        ## homology:           method_link_id E [201-300], method_link_species_set_id E [20001-30000]
        ## families:           method_link_id E [301-400], method_link_species_set_id E [30001-40000]
        ##
        ## => the method_link_species_set_id must be between 10000 times the hundreds in the
        ## method_link_id and the next hundred.
        my $sth2 = $self->prepare("SELECT
            MAX(mlss1.method_link_species_set_id + 1)
            FROM method_link_species_set mlss1 LEFT JOIN method_link_species_set mlss2
              ON (mlss2.method_link_species_set_id = mlss1.method_link_species_set_id + 1)
            WHERE mlss2.method_link_species_set_id IS NULL
              AND mlss1.method_link_species_set_id > 10000 * ($method_link_id DIV 100)
              AND mlss1.method_link_species_set_id < 10000 * (1 + $method_link_id DIV 100)
            ");
        $sth2->execute();
        ($dbID) = $sth2->fetchrow_array();
        $dbID = 10000 * int($method_link_id / 100) + 1 if (!defined($dbID));
        $sth2->finish();
      }
      my $species_set_id;
      if ($method_link_species_set->species_set_id) {
        $species_set_id = $method_link_species_set->species_set_id;
        my $sth2 = $self->prepare("INSERT IGNORE INTO species_set VALUES (?, ?)");
        foreach my $genome_db_id (@genome_db_ids) {
          $sth2->execute($species_set_id, $genome_db_id);
        }
        $sth2->finish();
      } else {
        $species_set_id = $self->_get_species_set_id_from_species_set($species_set);
      }
      if (!$species_set_id) {
        my $sth2 = $self->prepare("INSERT INTO species_set VALUES (?, ?)");
        foreach my $genome_db_id (@genome_db_ids) {
          $sth2->execute(($species_set_id or "NULL"), $genome_db_id);
          $species_set_id = $sth2->{'mysql_insertid'};
        }
        $sth2->finish();
      }
      my $sth2 = $self->prepare($method_link_species_set_sql);
      $sth2->execute(($dbID or "NULL"), $method_link_id, $species_set_id,
          ($method_link_species_set->name or "NULL"), ($method_link_species_set->source or "NULL"),
          ($method_link_species_set->url or ""));
      $dbID = $sth2->{'mysql_insertid'};
      $sth2->finish();
    }

    ## Unlock tables
    $self->dbc->do("UNLOCK TABLES");
    $self->dbc()->disconnect_when_inactive($original_dwi);
  }

  ## If this MethodLinkSpeciesSet object has a max_alignment_length attribute.
  ## We have to use the attribute and not the method here as the method is used
  ## for lazy-loading data from the meta table and could use default values if
  ## none has been specified. As some method_link_species_sets do not have any
  ## max_alignment_length, using the method here would result in adding a default
  ## max_alignment_length to those method_link_species_sets!
  if (defined($method_link_species_set->{max_alignment_length})) {
    my $values = $self->db->get_MetaContainer->list_value_by_key("max_align_$dbID");
    if (@$values) {
      if ($values->[0] != $method_link_species_set->max_alignment_length){
        #... update it if it was already defined and it is different from current one
        $self->db->get_MetaContainer->update_key_value("max_align_$dbID",
            $method_link_species_set->max_alignment_length);
      }
    } else {
        #... store it if it was not defined yet
      $self->db->get_MetaContainer->store_key_value("max_align_$dbID",
          $method_link_species_set->max_alignment_length)
    }
  }

  $method_link_species_set->dbID($dbID);

  return $method_link_species_set;
}


=head2 delete

  Arg  1     : integer $method_link_species_set_id
  Example    : $mlssa->delete(23)
  Description: Deletes a Bio::EnsEMBL::Compara::MethodLinkSpeciesSet entry from
               the database.
  Returntype : none
  Exception  :
  Caller     :

=cut

sub delete {
  my ($self, $method_link_species_set_id) = @_;
  my $sth;

  my $method_link_species_set_sql = qq{
          DELETE FROM
            method_link_species_set
          WHERE
            method_link_species_set_id = ?
      };
  $sth = $self->prepare($method_link_species_set_sql);
  $sth->execute($method_link_species_set_id);
  $sth->finish();

  ## Delete corresponding entry in meta table
  $self->db->get_MetaContainer->delete_key("max_align_$method_link_species_set_id");
}


=head2 fetch_all

  Arg  1     : none
  Example    : my $method_link_species_sets = $mlssa->fetch_all
  Description: Retrieve all possible Bio::EnsEMBL::Compara::MethodLinkSpeciesSet
               objects
  Returntype : listref of Bio::EnsEMBL::Compara::MethodLinkSpeciesSet objects
  Exceptions : none
  Caller     :

=cut

sub fetch_all {
  my ($self) = @_;
  my $method_link_species_sets = [];

  my $sql = qq{
          SELECT
            method_link_species_set_id,
            method_link_species_set.method_link_id,
            name,
            source,
            url,
            method_link_species_set.species_set_id,
            genome_db_id,
            type,
            class
          FROM
            method_link_species_set
            LEFT JOIN method_link USING (method_link_id),
            species_set
          WHERE
            method_link_species_set.species_set_id = species_set.species_set_id
      };

  my $sth = $self->prepare($sql);
  $sth->execute();
  my $all_method_link_species_sets;
  my $gdba = $self->db->get_GenomeDBAdaptor;

  while (my ($method_link_species_set_id, $method_link_id, $name, $source, $url,
      $species_set_id, $genome_db_id, $type, $class) = $sth->fetchrow_array()) {
    $all_method_link_species_sets->{$method_link_species_set_id}->{'METHOD_LINK_ID'} = $method_link_id;
    $all_method_link_species_sets->{$method_link_species_set_id}->{'NAME'} = $name;
    $all_method_link_species_sets->{$method_link_species_set_id}->{'SOURCE'} = $source;
    $all_method_link_species_sets->{$method_link_species_set_id}->{'URL'} = $url;
    $all_method_link_species_sets->{$method_link_species_set_id}->{'SPECIES_SET_ID'} = $species_set_id;
    $all_method_link_species_sets->{$method_link_species_set_id}->{'METHOD_LINK_TYPE'} = $type;
    $all_method_link_species_sets->{$method_link_species_set_id}->{'METHOD_LINK_CLASS'} = $class;
    push(@{$all_method_link_species_sets->{$method_link_species_set_id}->{'SPECIES_SET'}},
        $gdba->fetch_by_dbID($genome_db_id));
  }

  $sth->finish();

  foreach my $method_link_species_set_id (keys %$all_method_link_species_sets) {
    my $this_method_link_species_set;
    eval { $this_method_link_species_set = new Bio::EnsEMBL::Compara::MethodLinkSpeciesSet(
            -adaptor => $self,
            -dbID => $method_link_species_set_id,
            -method_link_id =>
                $all_method_link_species_sets->{$method_link_species_set_id}->{'METHOD_LINK_ID'},
            -method_link_type =>
                $all_method_link_species_sets->{$method_link_species_set_id}->{'METHOD_LINK_TYPE'},
            -method_link_class =>
                $all_method_link_species_sets->{$method_link_species_set_id}->{'METHOD_LINK_CLASS'},
            -name =>
                $all_method_link_species_sets->{$method_link_species_set_id}->{'NAME'},
            -source =>
                $all_method_link_species_sets->{$method_link_species_set_id}->{'SOURCE'},
            -url =>
                $all_method_link_species_sets->{$method_link_species_set_id}->{'URL'},
            -species_set_id =>
                $all_method_link_species_sets->{$method_link_species_set_id}->{'SPECIES_SET_ID'},
            -species_set =>
                $all_method_link_species_sets->{$method_link_species_set_id}->{'SPECIES_SET'},
        );
    };
    push(@$method_link_species_sets, $this_method_link_species_set) if (defined($this_method_link_species_set));
  }

  return $method_link_species_sets;
}


=head2 fetch_by_dbID

  Arg  1     : integer $method_link_species_set_id
  Example    : my $method_link_species_set_id = $mlssa->fetch_by_dbID(1)
  Description: Retrieve the correspondig
               Bio::EnsEMBL::Compara::MethodLinkSpeciesSet object
  Returntype : Bio::EnsEMBL::Compara::MethodLinkSpeciesSet object
  Exceptions : Returns undef if no matching
               Bio::EnsEMBL::Compara::MethodLinkSpeciesSet object can be retrieved
  Caller     : none

=cut

sub fetch_by_dbID {
  my ($self, $dbID) = @_;
  my $method_link_species_set; # returned object

  my $gdba = $self->db->get_GenomeDBAdaptor;
  my $sql = qq{
          SELECT
            method_link_species_set_id,
            mlss.method_link_id,
            name,
            source,
            url,
            mlss.species_set_id,
            genome_db_id,
            type
          FROM
            method_link_species_set mlss
            LEFT JOIN method_link ml USING (method_link_id),
            species_set ss
          WHERE
            mlss.species_set_id = ss.species_set_id
            AND method_link_species_set_id = ?
	};

  my $sth = $self->prepare($sql);
  $sth->execute($dbID);

  my $this_method_link_species_set;

  ## Get all rows corresponding to this method_link_species_set
  while (my ($method_link_species_set_id, $method_link_id, $name, $source, $url,
      $species_set_id, $genome_db_id, $type, $class) = $sth->fetchrow_array()) {
    $this_method_link_species_set->{'METHOD_LINK_ID'} = $method_link_id;
    $this_method_link_species_set->{'METHOD_LINK_TYPE'} = $type;
    $this_method_link_species_set->{'METHOD_LINK_CLASS'} = $class;
    $this_method_link_species_set->{'NAME'} = $name;
    $this_method_link_species_set->{'SOURCE'} = $source;
    $this_method_link_species_set->{'URL'} = $url;
    push(@{$this_method_link_species_set->{'SPECIES_SET'}}, $gdba->fetch_by_dbID($genome_db_id));
  }

  $sth->finish();

  return undef if (!defined($this_method_link_species_set));

  ## Create the object
  $method_link_species_set = new Bio::EnsEMBL::Compara::MethodLinkSpeciesSet(
          -adaptor => $self,
          -dbID => $dbID,
          -method_link_id => $this_method_link_species_set->{'METHOD_LINK_ID'},
          -method_link_type => $this_method_link_species_set->{'METHOD_LINK_TYPE'},
          -method_link_class => $this_method_link_species_set->{'METHOD_LINK_CLASS'},
          -name => $this_method_link_species_set->{'NAME'},
          -source => $this_method_link_species_set->{'SOURCE'},
          -url => $this_method_link_species_set->{'URL'},
          -species_set_id => $this_method_link_species_set->{'SPECIES_SET_ID'},
          -species_set => $this_method_link_species_set->{'SPECIES_SET'}
      );
  if (!$method_link_species_set) {
    warning("No Bio::EnsEMBL::Compara::MethodLinkSpeciesSet with id = $dbID found");
  }

  return $method_link_species_set;
}


=head2 fetch_all_by_method_link_type

  Arg  1     : string method_link_type
  Example    : my $method_link_species_sets =
                     $mlssa->fetch_all_by_method_link_type("BLASTZ_NET")
  Description: Retrieve all the Bio::EnsEMBL::Compara::MethodLinkSpeciesSet objects
               corresponding to the given method_link_type
  Returntype : listref of Bio::EnsEMBL::Compara::MethodLinkSpeciesSet objects
  Exceptions : none
  Caller     :

=cut

sub fetch_all_by_method_link_type {
  my ($self, $method_link_type) = @_;
  my $method_link_species_sets = [];

  return [] if (!defined($method_link_type));

  my $all_method_link_species_sets = $self->fetch_all();
  foreach my $this_method_link_species_set (@$all_method_link_species_sets) {
    if ($this_method_link_species_set->method_link_type eq $method_link_type) {
      push(@$method_link_species_sets, $this_method_link_species_set);
    }
  }

  return $method_link_species_sets;
}


=head2 fetch_all_by_GenomeDB

  Arg  1     : Bio::EnsEMBL::Compara::GenomeDB $genome_db
  Example    : my $method_link_species_sets = $mlssa->fetch_all_by_genome_db($genome_db)
  Description: Retrieve all the Bio::EnsEMBL::Compara::MethodLinkSpeciesSet objects
               which includes the genome defined by the Bio::EnsEMBL::Compara::GenomeDB
               object or the genome_db_id in the species_set
  Returntype : listref of Bio::EnsEMBL::Compara::MethodLinkSpeciesSet objects
  Exceptions : wrong argument throws
  Caller     :

=cut

sub fetch_all_by_GenomeDB {
  my ($self, $genome_db) = @_;
  my $method_link_species_sets = [];

  throw "[$genome_db] must be a Bio::EnsEMBL::Compara::GenomeDB object"
      unless ($genome_db and $genome_db->isa("Bio::EnsEMBL::Compara::GenomeDB"));
  my $genome_db_id = $genome_db->dbID;
  throw "[$genome_db] must have a dbID" if (!$genome_db_id);

  my $all_method_link_species_sets = $self->fetch_all;

  foreach my $this_method_link_species_set (@$all_method_link_species_sets) {
    foreach my $this_genome_db (@{$this_method_link_species_set->species_set}) {
      if ($this_genome_db->dbID == $genome_db_id) {
        push (@$method_link_species_sets, $this_method_link_species_set);
        last;
      }
    }
  }

  return $method_link_species_sets;
}


=head2 fetch_all_by_method_link_type_GenomeDB

  Arg  1     : string method_link_type
  Arg  2     : Bio::EnsEMBL::Compara::GenomeDB $genome_db
  Example    : my $method_link_species_sets =
                     $mlssa->fetch_all_by_method_link_type_GenomeDB("BLASTZ_NET", $rat_genome_db)
  Description: Retrieve all the Bio::EnsEMBL::Compara::MethodLinkSpeciesSet objects
               corresponding to the given method_link_type and which include the
               given Bio::EnsEBML::Compara::GenomeDB
  Returntype : listref of Bio::EnsEMBL::Compara::MethodLinkSpeciesSet objects
  Exceptions : none
  Caller     :

=cut

sub fetch_all_by_method_link_type_GenomeDB {
  my ($self, $method_link_type, $genome_db) = @_;
  my $method_link_species_sets = [];

  throw "[$genome_db] must be a Bio::EnsEMBL::Compara::GenomeDB object or the corresponding dbID"
      unless ($genome_db and $genome_db->isa("Bio::EnsEMBL::Compara::GenomeDB"));
  my $genome_db_id = $genome_db->dbID;
  throw "[$genome_db] must have a dbID" if (!$genome_db_id);

  my $all_method_link_species_sets = $self->fetch_all();
  foreach my $this_method_link_species_set (@$all_method_link_species_sets) {
    if ($this_method_link_species_set->method_link_type eq $method_link_type and
        grep (/^$genome_db_id$/, map {$_->dbID} @{$this_method_link_species_set->species_set})) {
      push(@$method_link_species_sets, $this_method_link_species_set);
    }
  }

  return $method_link_species_sets;
}


=head2 fetch_by_method_link_type_GenomeDBs

  Arg  1     : string $method_link_type
  Arg 2      : listref of Bio::EnsEMBL::Compara::GenomeDB objects [$gdb1, $gdb2, $gdb3]
  Arg 3      : (optional) bool $no_warning
  Example    : my $method_link_species_set =
                   $mlssa->fetch_by_method_link_type_GenomeDBs("MULTIZ",
                       [$human_genome_db,
                       $rat_genome_db,
                       $mouse_genome_db])
  Description: Retrieve the Bio::EnsEMBL::Compara::MethodLinkSpeciesSet object
               corresponding to the given method_link and the given set of
               Bio::EnsEMBL::Compara::GenomeDB objects
  Returntype : Bio::EnsEMBL::Compara::MethodLinkSpeciesSet object
  Exceptions : Returns undef if no Bio::EnsEMBL::Compara::MethodLinkSpeciesSet
               object is found. It also send a warning message unless the
               $no_warning option is on
  Caller     :

=cut

sub fetch_by_method_link_type_GenomeDBs {
  my ($self, $method_link_type, $genome_dbs, $no_warning) = @_;
  my $method_link_species_set;

  my $genome_db_ids;
  foreach my $genome_db (@$genome_dbs) {
    throw "[$genome_db] must be a Bio::EnsEMBL::Compara::GenomeDB object or the corresponding dbID"
        unless ($genome_db and $genome_db->isa("Bio::EnsEMBL::Compara::GenomeDB"));
    my $genome_db_id = $genome_db->dbID;
    throw "[$genome_db] must have a dbID" if (!$genome_db_id);
    push (@$genome_db_ids, $genome_db_id);
  }
  my $method_link_id = ($self->get_method_link_id_from_method_link_type($method_link_type) || 0);

  $method_link_species_set = $self->_run_query_from_method_link_id_genome_db_ids($method_link_id, $genome_db_ids);
  if (!$method_link_species_set and !$no_warning) {
    my $warning = "No Bio::EnsEMBL::Compara::MethodLinkSpeciesSet found for\n".
        "  <$method_link_type> and ".
        join(", ", map {$_->name."(".$_->assembly.")"} @$genome_dbs);
    warning($warning);
  }
  return $method_link_species_set;
}


=head2 fetch_by_method_link_type_genome_db_ids

  Arg  1     : string $method_link_type
  Arg 2      : listref of int [$gdbid1, $gdbid2, $gdbid3]
  Example    : my $method_link_species_set =
                   $mlssa->fetch_by_method_link_type_genome_db_id("MULTIZ",
                       [$human_genome_db->dbID,
                       $rat_genome_db->dbID,
                       $mouse_genome_db->dbID])
  Description: Retrieve the Bio::EnsEMBL::Compara::MethodLinkSpeciesSet object
               corresponding to the given method_link and the given set of
               Bio::EnsEMBL::Compara::GenomeDB objects defined by the set of
               $genome_db_ids
  Returntype : Bio::EnsEMBL::Compara::MethodLinkSpeciesSet object
  Exceptions : Returns undef if no Bio::EnsEMBL::Compara::MethodLinkSpeciesSet
               object is found
  Caller     :

=cut

sub fetch_by_method_link_type_genome_db_ids {
  my ($self, $method_link_type, $genome_db_ids) = @_;
  my $method_link_species_set;

  my $method_link_id = ($self->get_method_link_id_from_method_link_type($method_link_type) || 0);

  return $self->_run_query_from_method_link_id_genome_db_ids($method_link_id, $genome_db_ids)
}


=head2 fetch_by_method_link_type_registry_aliases

  Arg  1     : string $method_link_type
  Arg 2      : listref of core database aliases [$human, $mouse, $rat]
  Example    : my $method_link_species_set =
                   $mlssa->fetch_by_method_link_type_registry_aliases("MULTIZ",
                       ["human","mouse","rat"])
  Description: Retrieve the Bio::EnsEMBL::Compara::MethodLinkSpeciesSet object
               corresponding to the given method_link and the given set of
               core database aliases defined in the Bio::EnsEMBL::Registry
  Returntype : Bio::EnsEMBL::Compara::MethodLinkSpeciesSet object
  Exceptions : Returns undef if no Bio::EnsEMBL::Compara::MethodLinkSpeciesSet
               object is found
  Caller     :

=cut

sub fetch_by_method_link_type_registry_aliases {
  my ($self,$method_link_type, $registry_aliases) = @_;

  my $gdba = $self->db->get_GenomeDBAdaptor;
  my @genome_dbs;

  foreach my $alias (@{$registry_aliases}) {
    if (Bio::EnsEMBL::Registry->alias_exists($alias)) {
      my ($binomial, $gdb);
      try {
        $binomial = Bio::EnsEMBL::Registry->get_alias($alias);
        $gdb = $gdba->fetch_by_name_assembly($binomial);
      } catch {
        my $meta_c = Bio::EnsEMBL::Registry->get_adaptor($alias, 'core', 'MetaContainer');
        $binomial=$gdba->get_species_name_from_core_MetaContainer($meta_c);
        $gdb = $gdba->fetch_by_name_assembly($binomial);
      };
      push @genome_dbs, $gdb;
    } else {
      throw("Database alias $alias is not known\n");
    }
  }

  return $self->fetch_by_method_link_type_GenomeDBs($method_link_type,\@genome_dbs);
}


=head2 get_max_alignment_length

  Arg 1      : Bio::EnsEMBL::Compara::MethodLinkSpeciesSet $mlss
  Example    :
  Description: Retrieve the maximum length for this type of alignments.
               This method is used for genomic (dna/dna) alignments only.
               This method sets and returns this attribute for this object
  Returntype : integer
  Exceptions :
  Caller     : Bio::EnsEMBL::Compara::DBSQL::GenomicAlignBlockAdaptor

=cut

sub get_max_alignment_length {
  my ($self, $method_link_species_set) = @_;

  my $method_link_species_set_id = ($method_link_species_set->dbID or 0);
  my $values = $self->db->get_MetaContainer->list_value_by_key(
      "max_align_$method_link_species_set_id");
  if ($values && @$values) {
    return $method_link_species_set->max_alignment_length($values->[0]);
  } else {
    $values = $self->db->get_MetaContainer->list_value_by_key("max_alignment_length");
    if($values && @$values) {
      warning("Meta table key 'max_align_$method_link_species_set_id' not defined\n" .
          " -> using old meta table key 'max_alignment_length' [".$values->[0]."]");
      return $method_link_species_set->max_alignment_length($values->[0]);
    } else {
      warning("Meta table key 'max_align_$method_link_species_set_id' not defined and\n" .
          "old meta table key 'max_alignment_length' not defined\n" .
          " -> using default value [$DEFAULT_MAX_ALIGNMENT]");
      return $method_link_species_set->max_alignment_length($DEFAULT_MAX_ALIGNMENT);
    }
  }
}


=head2 _run_query_from_method_link_id_genome_db_ids

  Arg  1     : int $method_link_id
  Arg 2      : listref of int [$gdbid1, $gdbid2, $gdbid3]
  Example    : my $method_link_species_set =
                   $mlssa->_run_query_from_method_link_id_genome_db_ids(1,
                       [$human_genome_db->dbID,
                       $mouse_genome_db->dbID])
  Description: Retrieve the Bio::EnsEMBL::Compara::MethodLinkSpeciesSet object
               corresponding to the given method_link_id and the given set of
               Bio::EnsEMBL::Compara::GenomeDB objects defined by the set of
               $genome_db_ids
  Returntype : Bio::EnsEMBL::Compara::MethodLinkSpeciesSet object
  Exceptions : Returns undef if no Bio::EnsEMBL::Compara::MethodLinkSpeciesSet
               object is found
  Caller     :

=cut

sub _run_query_from_method_link_id_genome_db_ids {
  my ($self, $method_link_id, $genome_db_ids) = @_;
  my $method_link_species_set;

  my $species_set_id = $self->_get_species_set_id_from_genome_db_ids($genome_db_ids);

  if ($species_set_id) {
    my $sql = qq{
            SELECT
              method_link_species_set_id
            FROM
              method_link_species_set mlss
            WHERE
              species_set_id = \"$species_set_id\"
              AND method_link_id = \"$method_link_id\"
            };
    my $sth = $self->prepare($sql);
    $sth->execute();
    my ($dbID) = $sth->fetchrow_array();
    $sth->finish();
    $method_link_species_set = $self->fetch_by_dbID($dbID);
  }

  return $method_link_species_set;
}


=head2 _get_method_link_class_from_id

  Arg  1     : none
  Example    : my $method_link_class = $mlssa->_get_method_link_class_from_id()
  Description: Retrieve method_link_class corresponding to the method_link_id
  Returntype : string $method_link_class
  Exceptions : none
  Caller     :

=cut

sub _get_method_link_class_from_id {
  my ($self, $method_link_id) = @_;
	my $attributes = $self->_get_ml_attributes_from_ml_id($method_link_id);
	return $attributes->{class};
}


=head2 get_method_link_type_from_method_link_id

  Arg  1     : none
  Example    : my $method_link_type = $mlssa->get_method_link_type_from_method_link_id()
  Description: Retrieve method_link_type corresponding to the method_link_id
  Returntype : string $method_link_type
  Exceptions : none
  Caller     :

=cut

sub get_method_link_type_from_method_link_id {
  my ($self, $method_link_id) = @_;
	my $attributes = $self->_get_ml_attributes_from_ml_id($method_link_id);
	return $attributes->{type};
}


=head2 get_method_link_id_from_method_link_type

  Arg  1     : string $method_link_type
  Example    : my $method_link_id = $mlssa->get_method_link_id_from_method_link_type("BLASTZ_NET")
  Description: Retrieve method_link_id corresponding to the method_link_type
  Returntype : integer $method_link_id
  Exceptions : warns when no method_link matches the $method_link_type
  Caller     :

=cut

sub get_method_link_id_from_method_link_type {
  my ($self, $method_link_type) = @_;

  my $sql = q{
		SELECT method_link_id
		FROM method_link
		WHERE type = ?
	};

  my $sth = $self->prepare($sql);
  $sth->execute($method_link_type);

  my ($dbID) = $sth->fetchrow_array();
  $sth->finish;

  if (!$dbID) {
    warning("No method_link matches <$method_link_type>");
  }

  return $dbID;
}

=head2 _get_ml_attributes_from_ml_id

  Arg  1     : int $method_link_id
  Example    : my $values = $mlssa->_get_ml_values_from_ml_id(1)
  Description: Retrieve attributes for a given Method Link ID
  Returntype : HashRef keyed by type and class
  Exceptions : warns when no method_link matches the $method_link_id
  Caller     : Internal

=cut

sub _get_ml_attributes_from_ml_id {
	my ($self, $method_link_id) = @_;

	my $sql = qq{
		SELECT type, class
		FROM method_link
		WHERE method_link_id = ?
	};

  my $sth = $self->prepare($sql);
  $sth->execute($method_link_id);

  my ($type, $class) = $sth->fetchrow_array();
  $sth->finish();

	my %attributes;
	$attributes{type}  = $type if defined $type;
	$attributes{class} = $class if defined $class;

  return \%attributes;
}

=head2 _get_species_set_id_from_species_set

  Arg  1     : listref of Bio::EnsEMBL::Compara::GenomeDB obejcts $species_set
  Example    : my $species_set_id = $mlssa->_get_species_set_id_from_species_set($mlss->species_set);
  Description: Retrieve species_set_id corresponding to this set of species
  Returntype : integer $species_set_id
  Exceptions :
  Caller     :

=cut

sub _get_species_set_id_from_species_set {
  my ($self, $species_set) = @_;
  my $genome_db_ids = [];

  foreach my $this_genome_db (@$species_set) {
    if (UNIVERSAL::isa($this_genome_db, "Bio::EnsEMBL::Compara::GenomeDB") and $this_genome_db->dbID) {
      push(@$genome_db_ids, $this_genome_db->dbID);
    } else {
      throw("[$this_genome_db] is not a Bio::EnsEMBL::Compara::GenomeDB or has no dbID");
    }
  }
  return $self->_get_species_set_id_from_genome_db_ids([map {$_->dbID} @$species_set]);
}

=head2 _get_species_set_id_from_genome_db_ids

  Arg  1     : listref of Bio::EnsEMBL::Compara::GenomeDB obejcts $species_set
  Example    : my $species_set_id = $mlssa->_get_species_set_id_from_species_set($mlss->species_set);
  Description: Retrieve species_set_id corresponding to this set of species
  Returntype : integer $species_set_id
  Exceptions :
  Caller     :

=cut

sub _get_species_set_id_from_genome_db_ids {
  my ($self, $genome_db_ids) = @_;
  my $species_set_id;

  ## Fetch all the species_set which contain all these species_set_ids
  my $sql = qq{
          SELECT
            species_set_id,
            COUNT(*) as count
          FROM
            species_set
          WHERE
            genome_db_id in (}.join(",", @$genome_db_ids).qq{)
          GROUP BY species_set_id
          HAVING count = }.(scalar(@$genome_db_ids));
  my $sth = $self->prepare($sql);
  $sth->execute();
  my $all_rows = $sth->fetchall_arrayref();
  $sth->finish();

  if (!@$all_rows) {
    return undef;
  }
  my $species_set_ids = [map {$_->[0]} @$all_rows];

  ## Keep only the species_set which does not contain any other genome_db_id
  $sql = qq{
          SELECT
            species_set_id,
            COUNT(*) as count
          FROM
            species_set
          WHERE
            species_set_id in (}.join(",", @$species_set_ids).qq{)
          GROUP BY species_set_id
          HAVING count = }.(scalar(@$genome_db_ids));
  $sth = $self->prepare($sql);
  $sth->execute();

  $all_rows = $sth->fetchall_arrayref();

  $sth->finish();

  if (!@$all_rows) {
    return undef;
  } elsif (@$all_rows > 1) {
    warning("Several species_set_ids have been found for genome_db_ids (".
        join(",", @$genome_db_ids)."): ".join(",", map {$_->[0]} @$all_rows));
  }
  $species_set_id = $all_rows->[0]->[0];

  return $species_set_id;
}


=head2 fetch_all_by_method_link_id

  DEPRECATED: Use the fetch_all_by_method_link_type method instead

=cut

sub fetch_all_by_method_link_id {
  my ($self, $method_link_id) = @_;

  deprecate("Use the fetch_all_by_method_link_type method instead");

  my $method_link_type = $self->get_method_link_type_from_method_link_id($method_link_id);
  return $self->fetch_all_by_method_link_type($method_link_type);
}


=head2 fetch_all_by_genome_db_id

  DEPRECATED: Use the fetch_all_by_GenomeDB methodsinstead

=cut

sub fetch_all_by_genome_db_id {
  my ($self, $genome_db_id) = @_;
  my $method_link_species_sets = [];

  deprecate("Use the fetch_all_by_GenomeDB method instead");

  my $all_method_link_species_sets = $self->fetch_all;

  foreach my $this_method_link_species_set (@$all_method_link_species_sets) {
    foreach my $this_genome_db (@{$this_method_link_species_set->species_set}) {
      if ($this_genome_db->dbID == $genome_db_id) {
        push (@$method_link_species_sets, $this_method_link_species_set);
        last;
      }
    }
  }

  return $method_link_species_sets;
}


=head2 fetch_all_by_method_link_id_GenomeDB

  DEPRECATED: Use the fetch_all_by_method_link_type_GenomeDB method instead

=cut

sub fetch_all_by_method_link_id_GenomeDB {
  my ($self, $method_link_id, $genome_db) = @_;
  my $method_link_species_sets = [];

  deprecate("Use the fetch_all_by_method_link_type_GenomeDB method instead");

  my $method_link_type = $self->get_method_link_type_from_method_link_id($method_link_id);
  return $self->fetch_all_by_method_link_type_GenomeDB ($method_link_type, $genome_db);
}


=head2 fetch_all_by_method_link_id_genome_db_id

  DEPRECATED: Use the fetch_all_by_method_link_type_GenomeDB method instead

=cut

sub fetch_all_by_method_link_id_genome_db_id {
  my ($self, $method_link_id, $genome_db_id) = @_;

  deprecate("Use the fetch_all_by_method_link_type_GenomeDB method instead");
  my $method_link_type = $self->get_method_link_type_from_method_link_id($method_link_id);
  my $genome_db = $self->db->get_GenomeDBAdaptor->fetch_by_dbID($genome_db_id);

  return $self->fetch_all_by_method_link_type_GenomeDB($method_link_type, $genome_db);
}


=head2 fetch_all_by_method_link_type_genome_db_id

  DEPRECATED: Use the fetch_all_by_method_link_type_GenomeDB method instead

=cut

sub fetch_all_by_method_link_type_genome_db_id {
  my ($self, $method_link_type, $genome_db_id) = @_;

  deprecate("Use the fetch_all_by_method_link_type_GenomeDB method instead");
  my $genome_db = $self->db->get_GenomeDBAdaptor->fetch_by_dbID($genome_db_id);

  return $self->fetch_all_by_method_link_type_GenomeDB($method_link_type, $genome_db);
}


=head2 fetch_by_method_link_id_GenomeDBs

  DEPRECATED: Use the fetch_by_method_link_type_GenomeDBs method instead!

=cut

sub fetch_by_method_link_id_GenomeDBs {
  my ($self, $method_link_id, $genome_dbs) = @_;

  deprecate("Use the fetch_by_method_link_type_GenomeDBs method instead");
  my $method_link_type = $self->get_method_link_type_from_method_link_id($method_link_id);

  return $self->fetch_by_method_link_type_GenomeDBs($method_link_type, $genome_dbs);
}


=head2 fetch_by_method_link_id_genome_db_ids

  DEPRECATED: Use the fetch_by_method_link_type_GenomeDBs method instead

=cut

sub fetch_by_method_link_id_genome_db_ids {
  my ($self, $method_link_id, $genome_db_ids) = @_;
  my $method_link_species_set;

  deprecate("Use the fetch_by_method_link_type_GenomeDBs method instead");
  my $method_link_type = $self->get_method_link_type_from_method_link_id($method_link_id);
  my $genome_db_adaptor = $self->db->get_GenomeDBAdaptor();
  my $genome_dbs;
  foreach my $this_genome_db_id (@$genome_db_ids) {
    push(@$genome_dbs, $genome_db_adaptor->fetch_by_dbID($this_genome_db_id ));
  }

  return $self->fetch_by_method_link_type_GenomeDBs($method_link_type, $genome_dbs);
}


1;

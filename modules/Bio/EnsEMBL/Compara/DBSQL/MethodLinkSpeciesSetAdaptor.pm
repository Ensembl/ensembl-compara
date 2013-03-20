=head1 LICENSE

  Copyright (c) 1999-2013 The European Bioinformatics Institute and
  Genome Research Limited.  All rights reserved.

  This software is distributed under a modified Apache license.
  For license details, please see

    http://www.ensembl.org/info/about/code_licence.html

=head1 CONTACT

  Please email comments or questions to the public Ensembl
  developers list at <dev@ensembl.org>.

  Questions may also be sent to the Ensembl help desk at
  <helpdesk@ensembl.org>.

=cut

=head1 NAME

Bio::EnsEMBL::DBSQL::MethodLinkSpeciesSetAdaptor - Object to access data in the method_link_species_set
and method_link tables

=head1 SYNOPSIS

=head2 Retrieve data from the database

  my $method_link_species_sets = $mlssa->fetch_all;

  my $method_link_species_set = $mlssa->fetch_by_dbID(1);

  my $method_link_species_set = $mlssa->fetch_by_method_link_type_registry_aliases(
        "BLASTZ_NET", ["human", "Mus musculus"]);

  my $method_link_species_set = $mlssa->fetch_by_method_link_type_species_set_name(
        "EPO", "mammals")
  
  my $method_link_species_sets = $mlssa->fetch_all_by_method_link_type("BLASTZ_NET");

  my $method_link_species_sets = $mlssa->fetch_all_by_GenomeDB($genome_db);

  my $method_link_species_sets = $mlssa->fetch_all_by_method_link_type_GenomeDB(
        "PECAN", $gdb1);
  
  my $method_link_species_set = $mlssa->fetch_by_method_link_type_GenomeDBs(
        "TRANSLATED_BLAT", [$gdb1, $gdb2]);

=head2 Store/Delete data from the database

  $mlssa->store($method_link_species_set);

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

=head1 APPENDIX

The rest of the documentation details each of the object methods. Internal methods are usually preceded with a _

=cut


package Bio::EnsEMBL::Compara::DBSQL::MethodLinkSpeciesSetAdaptor;

use strict;

use Bio::EnsEMBL::Registry;
use Bio::EnsEMBL::Compara::Method;
use Bio::EnsEMBL::Compara::MethodLinkSpeciesSet;
use Bio::EnsEMBL::Utils::Exception;

use base ('Bio::EnsEMBL::Compara::DBSQL::BaseAdaptor', 'Bio::EnsEMBL::Compara::DBSQL::TagAdaptor');


sub object_class {
    return 'Bio::EnsEMBL::Compara::MethodLinkSpeciesSet';
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
  my ($self, $mlss, $store_components_first) = @_;

  throw("method_link_species_set must be a Bio::EnsEMBL::Compara::MethodLinkSpeciesSet\n")
    unless ($mlss && ref $mlss &&
        $mlss->isa("Bio::EnsEMBL::Compara::MethodLinkSpeciesSet"));

  my $method            = $mlss->method()           or die "No Method defined, cannot store";
  $self->db->get_MethodAdaptor->store( $method );   # will only store if the object needs storing (type is missing) and reload the dbID otherwise

  my $species_set_obj   = $mlss->species_set_obj()  or die "No SpeciesSet defined, cannot store";
  $self->db->get_SpeciesSetAdaptor->store( $species_set_obj, $store_components_first );

  my $dbID;
  if(my $already_stored_method_link_species_set = $self->fetch_by_method_link_id_species_set_id($method->dbID, $species_set_obj->dbID, 1) ) {
    $dbID = $already_stored_method_link_species_set->dbID;
  }

  if (!$dbID) {
    ## Lock the table in order to avoid a concurrent process to store the same object with a different dbID
    # from mysql documentation 13.4.5 :
    #   "If your queries refer to a table using an alias, then you must lock the table using that same alias.
    #   "It will not work to lock the table without specifying the alias"
    #Thus we need to lock method_link_species_set as a, method_link_species_set as b, and method_link_species_set

	my $original_dwi = $self->dbc()->disconnect_when_inactive();
  	$self->dbc()->disconnect_when_inactive(0);

    $self->dbc->do(qq{ LOCK TABLES
                        method_link_species_set WRITE,
                        method_link_species_set as mlss WRITE,
                        method_link_species_set as mlss1 WRITE,
                        method_link_species_set as mlss2 WRITE,
                        method_link WRITE,
                        method_link as m WRITE,
                        method_link as ml WRITE
   });

        # check again if the object has not been stored in the meantime (tables are locked)
    if(my $already_stored_method_link_species_set = $self->fetch_by_method_link_id_species_set_id($method->dbID, $species_set_obj->dbID, 1) ) {
        $dbID = $already_stored_method_link_species_set->dbID;
    }

    # If the object still does not exist in the DB, store it
    if (!$dbID) {
      $dbID = $mlss->dbID();
      if (!$dbID) {
        ## Use conversion rule for getting a new dbID. At the moment, we use the following ranges:
        ##
        ## dna-dna alignments: method_link_id E [1-100], method_link_species_set_id E [1-10000]
        ## synteny:            method_link_id E [101-100], method_link_species_set_id E [10001-20000]
        ## homology:           method_link_id E [201-300], method_link_species_set_id E [20001-30000]
        ## families:           method_link_id E [301-400], method_link_species_set_id E [30001-40000]
        ##
        ## => the method_link_species_set_id must be between 10000 times the hundreds in the
        ## method_link_id and the next hundred.

        my $method_link_id    = $method->dbID;
        my $sth2 = $self->prepare("SELECT
            MAX(mlss1.method_link_species_set_id + 1)
            FROM method_link_species_set mlss1 LEFT JOIN method_link_species_set mlss2
              ON (mlss2.method_link_species_set_id = mlss1.method_link_species_set_id + 1)
            WHERE mlss2.method_link_species_set_id IS NULL
              AND mlss1.method_link_species_set_id > 10000 * ($method_link_id DIV 100)
              AND mlss1.method_link_species_set_id < 10000 * (1 + $method_link_id DIV 100)
            ");
        $sth2->execute();
        my $count;
        ($dbID) = $sth2->fetchrow_array();
        #If we got no dbID i.e. we have exceeded the bounds of the range then
        #assign to the next available identifeir
        if (!defined($dbID)) {
          $sth2->finish();
          $sth2 = $self->prepare("SELECT MAX(mlss1.method_link_species_set_id + 1) FROM method_link_species_set mlss1");
          $sth2->execute();
          ($dbID) = $sth2->fetchrow_array();
        }
        $sth2->finish();
      }

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

      my $sth3 = $self->prepare($method_link_species_set_sql);
      $sth3->execute(($dbID or undef), $method->dbID, $species_set_obj->dbID,
          ($mlss->name or undef), ($mlss->source or undef),
          ($mlss->url or ""));
      $dbID = $sth3->{'mysql_insertid'};
      $sth3->finish();
    }

    ## Unlock tables
    $self->dbc->do("UNLOCK TABLES");
    $self->dbc()->disconnect_when_inactive($original_dwi);
  }

  $self->attach( $mlss, $dbID);

  $self->sync_tags_to_database( $mlss );

  $self->{'_cache'}->{$dbID} = $mlss;

  return $mlss;
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

    my $method_link_species_set_sql = 'DELETE mlsst, mlss FROM method_link_species_set mlss LEFT JOIN method_link_species_set_tag mlsst USING (method_link_species_set_id) WHERE method_link_species_set_id = ?';
    my $sth = $self->prepare($method_link_species_set_sql);
    $sth->execute($method_link_species_set_id);
    $sth->finish();

    delete $self->{'_cache'}->{$method_link_species_set_id};
}


=head2 cache_all

  Arg [1]    : none
  Example    : none
  Description: Caches all the MLSS entries hashed by dbID; loads from db when necessary or asked
  Returntype : Hash of {mlss_id -> mlss}
  Exceptions : none
  Caller     : internal
  Status     : Stable

=cut

sub cache_all {
    my ($self, $force_reload) = @_;

    if(!$self->{'_cache'} or $force_reload) {

        $self->{'_cache'} = {};

        my $method_hash       = { map { $_->dbID => $_} @{ $self->db->get_MethodAdaptor()->fetch_all()} };
        my $species_set_hash  = { map { $_->dbID => $_} @{ $self->db->get_SpeciesSetAdaptor()->fetch_all()} };

        my $sql = 'SELECT method_link_species_set_id, method_link_id, species_set_id, name, source, url FROM method_link_species_set';
        my $sth = $self->prepare($sql);
        $sth->execute();

        while( my ($dbID, $method_link_id, $species_set_id, $name, $source, $url) = $sth->fetchrow_array()) {
            my $method          = $method_hash->{$method_link_id} or warning "Could not fetch Method with dbID=$method_link_id for MLSS with dbID=$dbID";
            my $species_set_obj = $species_set_hash->{$species_set_id} or warning "Could not fetch SpeciesSet with dbID=$species_set_id for MLSS with dbID=$dbID";

            if($method and $species_set_obj) {
                my $mlss = Bio::EnsEMBL::Compara::MethodLinkSpeciesSet->new(
                    -adaptor            => $self,
                    -dbID               => $dbID,
                    
                    -method             => $method,
                    -species_set_obj    => $species_set_obj,

                    -name               => $name,
                    -source             => $source,
                    -url                => $url,
                );

                $self->{'_cache'}->{$dbID} = $mlss;
            }
        }
        $sth->finish();
    }

    return $self->{'_cache'};
}

=head2 fetch_by_dbID

  Arg [1]    : int $dbid
  Example    : my $this_mlss = $mlssa->fetch_by_dbID(12345);
  Description: Retrieves a MethodLinkSpeciesSet object via its internal identifier
  Returntype : Bio::EnsEMBL::Compara::MethodLinkSpeciesSet
  Exceptions : none
  Caller     : general
  Status     : Stable

=cut

sub fetch_by_dbID {
    my ($self, $dbid) = @_;

    throw("dbID must be defined and nonzero") unless($dbid);

    return $self->cache_all->{$dbid};
}


=head2 fetch_all

  Args       : none
  Example    : my $method_link_species_sets = $mlssa->fetch_all();
  Description: Retrieve all possible Bio::EnsEMBL::Compara::MethodLinkSpeciesSet objects
  Returntype : listref of Bio::EnsEMBL::Compara::MethodLinkSpeciesSet objects
  Exceptions : none
  Caller     : general
  Status     : Stable

=cut

sub fetch_all {
    my ($self) = @_;

    return [ values %{ $self->cache_all } ];
}


=head2 fetch_by_method_link_id_species_set_id

  Arg 1      : int $method_link_id
  Arg 2      : int $species_set_id
  Example    : my $method_link_species_set =
                   $mlssa->fetch_by_method_link_id_species_set_id(1, 1234)
  Description: Retrieve the Bio::EnsEMBL::Compara::MethodLinkSpeciesSet object
               corresponding to the given method_link_id and species_set_id
  Returntype : Bio::EnsEMBL::Compara::MethodLinkSpeciesSet object
  Exceptions : Returns undef if no Bio::EnsEMBL::Compara::MethodLinkSpeciesSet
               object is found
  Caller     :

=cut

sub fetch_by_method_link_id_species_set_id {
    my ($self, $method_link_id, $species_set_id, $no_warning) = @_;

    if($method_link_id && $species_set_id) {
        foreach my $mlss (@{ $self->fetch_all() }) {
            if ($mlss->method->dbID() eq $method_link_id
            and $mlss->species_set_obj->dbID() == $species_set_id) {
                return $mlss;
            }
        }
    }

    unless($no_warning) {
        warning("Unable to find method_link_species_set with method_link_id='$method_link_id' and species_set_id='$species_set_id'");
    }
    return undef;
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

    my @good_mlsss = ();

    if($method_link_type) {
        foreach my $mlss (@{ $self->fetch_all() }) {
            if ($mlss->method->type() eq $method_link_type) {
                push @good_mlsss, $mlss;
            }
        }
    } else {
        warning "method_link_type was not defined, returning an empty list";
    }

    return \@good_mlsss;
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

    throw "[$genome_db] must be a Bio::EnsEMBL::Compara::GenomeDB object"
        unless ($genome_db and $genome_db->isa("Bio::EnsEMBL::Compara::GenomeDB"));

    my $genome_db_id = $genome_db->dbID
        or throw "[$genome_db] must have a dbID";

    my @good_mlsss = ();
    foreach my $mlss (@{ $self->fetch_all() }) {
        foreach my $this_genome_db (@{$mlss->species_set_obj->genome_dbs}) {
            if ($this_genome_db->dbID == $genome_db_id) {
                push @good_mlsss, $mlss;
                last;
            }
        }
    }

    return \@good_mlsss;
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
    if ($this_method_link_species_set->method->type eq $method_link_type and
        grep (/^$genome_db_id$/, map {$_->dbID} @{$this_method_link_species_set->species_set_obj->genome_dbs})) {
      push(@$method_link_species_sets, $this_method_link_species_set);
    }
  }

  return $method_link_species_sets;
}


=head2 fetch_by_method_link_type_GenomeDBs

  Arg 1      : string $method_link_type
  Arg 2      : listref of Bio::EnsEMBL::Compara::GenomeDB objects [$gdb1, $gdb2, $gdb3]
  Arg 3      : (optional) bool $no_warning
  Example    : my $method_link_species_set =
                   $mlssa->fetch_by_method_link_type_GenomeDBs('MULTIZ',
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

    my $method = $self->db->get_MethodAdaptor->fetch_by_type($method_link_type)
        or die "Could not fetch Method with type='$method_link_type'";
    my $method_link_id = $method->dbID;
    my $species_set_id = $self->db->get_SpeciesSetAdaptor->find_species_set_id_by_GenomeDBs_mix( $genome_dbs );

    my $method_link_species_set = $self->fetch_by_method_link_id_species_set_id($method_link_id, $species_set_id);
    if (!$method_link_species_set and !$no_warning) {
        my $warning = "No Bio::EnsEMBL::Compara::MethodLinkSpeciesSet found for\n".
            "  <$method_link_type> and ".  join(", ", map {$_->name."(".$_->assembly.")"} @$genome_dbs);
        warning($warning);
    }
    return $method_link_species_set;
}


=head2 fetch_by_method_link_type_genome_db_ids

  Arg  1     : string $method_link_type
  Arg 2      : listref of int [$gdbid1, $gdbid2, $gdbid3]
  Example    : my $method_link_species_set =
                   $mlssa->fetch_by_method_link_type_genome_db_id('MULTIZ',
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

    my $method = $self->db->get_MethodAdaptor->fetch_by_type($method_link_type)
        or die "Could not fetch Method with type='$method_link_type'";
    my $method_link_id = $method->dbID;
    my $species_set_id = $self->db->get_SpeciesSetAdaptor->find_species_set_id_by_GenomeDBs_mix( $genome_db_ids );

    return $self->fetch_by_method_link_id_species_set_id($method_link_id, $species_set_id);
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


=head2 fetch_by_method_link_type_species_set_name

  Arg  1     : string method_link_type
  Arg  2     : string species_set_name
  Example    : my $method_link_species_set =
                     $mlssa->fetch_by_method_link_type_species_set_name("EPO", "mammals")
  Description: Retrieve the Bio::EnsEMBL::Compara::MethodLinkSpeciesSet object
               corresponding to the given method_link_type and and species_set_tag value
  Returntype : Bio::EnsEMBL::Compara::MethodLinkSpeciesSet object
  Exceptions : Returns undef if no Bio::EnsEMBL::Compara::MethodLinkSpeciesSet
               object is found
  Caller     :

=cut

sub fetch_by_method_link_type_species_set_name {
  my ($self, $method_link_type, $species_set_name) = @_;
  my $method_link_species_set;

  my $all_method_link_species_sets = $self->fetch_all();
  my $species_set_adaptor = $self->db->get_SpeciesSetAdaptor;

  my $all_species_sets = $species_set_adaptor->fetch_all_by_tag_value('name', $species_set_name);
  foreach my $this_method_link_species_set (@$all_method_link_species_sets) {
      foreach my $this_species_set (@$all_species_sets) {
          if ($this_method_link_species_set->method->type eq $method_link_type && $this_method_link_species_set->species_set_obj->dbID == $this_species_set->dbID) {
              return $this_method_link_species_set;
          }
      }
  }
  warning("Unable to find method_link_species_set with method_link_type of $method_link_type and species_set_tag value of $species_set_name\n");
  return undef;
}


###################################
#
# tagging 
#
###################################

sub _tag_capabilities {
    return ("method_link_species_set_tag", undef, "method_link_species_set_id", "dbID");
}


1;

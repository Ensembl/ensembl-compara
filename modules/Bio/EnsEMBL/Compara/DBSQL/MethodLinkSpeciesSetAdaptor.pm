=head1 LICENSE

Copyright [1999-2014] Wellcome Trust Sanger Institute and the EMBL-European Bioinformatics Institute

Licensed under the Apache License, Version 2.0 (the "License");
you may not use this file except in compliance with the License.
You may obtain a copy of the License at

     http://www.apache.org/licenses/LICENSE-2.0

Unless required by applicable law or agreed to in writing, software
distributed under the License is distributed on an "AS IS" BASIS,
WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
See the License for the specific language governing permissions and
limitations under the License.

=cut


=head1 CONTACT

  Please email comments or questions to the public Ensembl
  developers list at <http://lists.ensembl.org/mailman/listinfo/dev>.

  Questions may also be sent to the Ensembl help desk at
  <http://www.ensembl.org/Help/Contact>.

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
use warnings;

use Bio::EnsEMBL::Registry;
use Bio::EnsEMBL::Compara::Method;
use Bio::EnsEMBL::Compara::MethodLinkSpeciesSet;
use Bio::EnsEMBL::Utils::Exception;
use Bio::EnsEMBL::Utils::SqlHelper;
use Bio::EnsEMBL::Utils::Scalar qw(:assert);

use base ('Bio::EnsEMBL::Compara::DBSQL::BaseFullCacheAdaptor', 'Bio::EnsEMBL::Compara::DBSQL::TagAdaptor');



#############################################################
# Implements Bio::EnsEMBL::Compara::RunnableDB::ObjectStore #
#############################################################

sub object_class {
    return 'Bio::EnsEMBL::Compara::MethodLinkSpeciesSet';
}



##################
# store* methods #
##################

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

  assert_ref($mlss, 'Bio::EnsEMBL::Compara::MethodLinkSpeciesSet');

  my $method            = $mlss->method()           or die "No Method defined, cannot store\n";
  $self->db->get_MethodAdaptor->store( $method );   # will only store if the object needs storing (type is missing) and reload the dbID otherwise

  my $species_set_obj   = $mlss->species_set_obj()  or die "No SpeciesSet defined, cannot store\n";
  $self->db->get_SpeciesSetAdaptor->store( $species_set_obj, $store_components_first );

  my $dbID;
  if(my $already_stored_method_link_species_set = $self->fetch_by_method_link_id_species_set_id($method->dbID, $species_set_obj->dbID, 1) ) {
    $dbID = $already_stored_method_link_species_set->dbID;
  }

  if (!$dbID) {

      my $columns = '(method_link_species_set_id, method_link_id, species_set_id, name, source, url)';
      my $mlss_placeholders = '?, ?, ?, ?, ?';
      my @mlss_data = ($method->dbID, $species_set_obj->dbID, $mlss->name || '', $mlss->source || '', $mlss->url || '');

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

        my $mlss_id_factor = int($method->dbID / 100);
        my $min_mlss_id = 10000 * $mlss_id_factor + 1;
        my $max_mlss_id = 10000 * ($mlss_id_factor + 1);

        my $helper = Bio::EnsEMBL::Utils::SqlHelper->new( -DB_CONNECTION => $self->dbc );
        my $val = $helper->transaction(
            -RETRY => 3,
            -CALLBACK => sub {
                #eval {$self->dbc->do('SET TRANSACTION ISOLATION LEVEL READ UNCOMMITTED')};
                #die $@ if $@ and not $@ =~ m/row-based logging/;
                my $sth2 = $self->prepare("INSERT INTO method_link_species_set $columns SELECT
                    IF(
                        MAX(method_link_species_set_id) = $max_mlss_id,
                        NULL,
                        IFNULL(
                            MAX(method_link_species_set_id) + 1,
                            $min_mlss_id
                        )
                    ), $mlss_placeholders
                    FROM method_link_species_set
                    WHERE method_link_species_set_id BETWEEN $min_mlss_id AND $max_mlss_id
                    ");
                my $r = $sth2->execute(@mlss_data);
                $dbID = $sth2->{'mysql_insertid'};
                $sth2->finish();
                return $r;
            }
        );
      } else {

      my $method_link_species_set_sql = qq{INSERT INTO method_link_species_set $columns VALUES (?, $mlss_placeholders)};

      my $sth3 = $self->prepare($method_link_species_set_sql);
      $sth3->execute($dbID, @mlss_data);
      $sth3->finish();
    }
    $self->_id_cache->put($dbID, $mlss);
  }
  $self->attach( $mlss, $dbID);
  $self->sync_tags_to_database( $mlss );

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

    $self->_id_cache->remove($method_link_species_set_id);
}


########################################################
# Implements Bio::EnsEMBL::Compara::DBSQL::BaseAdaptor #
########################################################

sub _objs_from_sth {
    my ($self, $sth) = @_;

    my @mlss_list = ();

    my $method_adaptor = $self->db->get_MethodAdaptor;
    my $species_set_adaptor = $self->db->get_SpeciesSetAdaptor;

    my $method_hash = $self->db->get_MethodAdaptor()->_id_cache;
    my $species_set_hash = $self->db->get_SpeciesSetAdaptor()->_id_cache;

    my ($dbID, $method_link_id, $species_set_id, $name, $source, $url);
    $sth->bind_columns(\$dbID, \$method_link_id, \$species_set_id, \$name, \$source, \$url);
    while ($sth->fetch()) {

            my $method          = $method_hash->get($method_link_id) or warning "Could not fetch Method with dbID=$method_link_id for MLSS with dbID=$dbID";
            my $species_set_obj = $species_set_hash->get($species_set_id) or warning "Could not fetch SpeciesSet with dbID=$species_set_id for MLSS with dbID=$dbID";

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
                push @mlss_list, $mlss;
            }
    }
    $sth->finish();
    $self->_load_tagvalues_multiple(\@mlss_list, 1);
    return \@mlss_list;
}

sub _tables {

    return (['method_link_species_set', 'm'])
}

sub _columns {
    return qw(
        m.method_link_species_set_id
        m.method_link_id
        m.species_set_id
        m.name
        m.source
        m.url
    )
}


sub _unique_attributes {
    return qw(
        method_link_id
        species_set_id
    )
}


###################
# fetch_* methods #
###################

=head2 fetch_all_by_species_set_id

  Arg 1       : int $species_set_id
  Example     : my $method_link_species_set =
                  $mlss_adaptor->fetch_all_by_species_set_id($ss->dbID)
  Description : Retrieve the Bio::EnsEMBL::Compara::MethodLinkSpeciesSet objects
                corresponding to the given species_set_id
  Returntype  : Bio::EnsEMBL::Compara::MethodLinkSpeciesSet
  Exceptions  : none

=cut

sub fetch_all_by_species_set_id {
    my ($self, $species_set_id, $no_warning) = @_;

    my $mlss = $self->_id_cache->get_all_by_additional_lookup('species_set_id', $species_set_id);
    if (not $mlss and not $no_warning) {
        warning("Unable to find method_link_species_set with species_set='$species_set_id'");
    }
    return $mlss;
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

    my $mlss = $self->_id_cache->get_by_additional_lookup('method_species_set', sprintf('%d_%d', $method_link_id, $species_set_id));

    if (not $mlss and not $no_warning) {
        warning("Unable to find method_link_species_set with method_link_id='$method_link_id' and species_set_id='$species_set_id'");
    }
    return $mlss;
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
    my ($self, $method_link_type, $no_warning) = @_;

    my $method = $self->db->get_MethodAdaptor->fetch_by_type($method_link_type);

    unless ($method) {
        warning("Unable to find any method_link_species_sets with method_link_type='$method_link_type, returning an empty list'") unless ($no_warning);
        my $empty_mlsss = [];
        return $empty_mlsss;
    }

    return $self->_id_cache->get_all_by_additional_lookup('method', $method->dbID);
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

    assert_ref($genome_db, 'Bio::EnsEMBL::Compara::GenomeDB');

    my $genome_db_id = $genome_db->dbID
        or throw "[$genome_db] must have a dbID";

    return $self->_id_cache->get_all_by_additional_lookup(sprintf('genome_db_%d', $genome_db_id), 1);
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

  assert_ref($genome_db, 'Bio::EnsEMBL::Compara::GenomeDB');
  my $genome_db_id = $genome_db->dbID;
  throw "[$genome_db] must have a dbID" if (!$genome_db_id);

  return $self->_id_cache->get_all_by_additional_lookup(sprintf('genome_db_%d_method_%s', $genome_db_id, uc $method_link_type), 1);
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

    my $method = $self->db->get_MethodAdaptor->fetch_by_type($method_link_type);
    if (not defined $method) {
        # Do not complain if ENSEMBL_HOMOEOLOGUES does not exist
        return undef if $method_link_type eq 'ENSEMBL_HOMOEOLOGUES';
        die "Could not fetch Method with type='$method_link_type'";
    }
    my $method_link_id = $method->dbID;
    my $species_set = $self->db->get_SpeciesSetAdaptor->fetch_by_GenomeDBs( $genome_dbs );
    unless ($species_set) {
        warning("No Bio::EnsEMBL::Compara::SpeciesSet found for: ".join(", ", map {$_->name."(".$_->assembly.")"} @$genome_dbs)) unless $no_warning;
        return undef;
    }

    my $method_link_species_set = $self->fetch_by_method_link_id_species_set_id($method_link_id, $species_set->dbID, $no_warning);
    if (not $method_link_species_set and not $no_warning) {
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

    my $method = $self->db->get_MethodAdaptor->fetch_by_type($method_link_type);
    if (not defined $method) {
        # Do not complain if ENSEMBL_HOMOEOLOGUES does not exist
        return undef if $method_link_type eq 'ENSEMBL_HOMOEOLOGUES';
        die "Could not fetch Method with type='$method_link_type'";
    }
    my $method_link_id = $method->dbID;
    my $species_set = $self->db->get_SpeciesSetAdaptor->fetch_by_GenomeDBs( $genome_db_ids );

    return undef unless $species_set;
    return $self->fetch_by_method_link_id_species_set_id($method_link_id, $species_set->dbID);
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
        $gdb = $gdba->fetch_by_name_assembly($meta_c->get_production_name());
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

    my $species_set_adaptor = $self->db->get_SpeciesSetAdaptor;
    my $all_species_sets = $species_set_adaptor->fetch_all_by_tag_value('name', $species_set_name);

    my $method = $self->db->get_MethodAdaptor->fetch_by_type($method_link_type);

    if ($method) {
        foreach my $this_species_set (@$all_species_sets) {
            my $mlss = $self->fetch_by_method_link_id_species_set_id($method->dbID, $this_species_set->dbID, 1);  # final 1, before we don't want a warning here if any is missing
            return $mlss if $mlss;
        }
    }
    warning("Unable to find method_link_species_set with method_link_type of $method_link_type and species_set_tag value of $species_set_name\n");
    return undef
}


###################################
#
# tagging 
#
###################################

sub _tag_capabilities {
    return ("method_link_species_set_tag", undef, "method_link_species_set_id", "dbID");
}


############################################################
# Implements Bio::EnsEMBL::Compara::DBSQL::BaseFullAdaptor #
############################################################


sub _build_id_cache {
    my $self = shift;
    return Bio::EnsEMBL::DBSQL::Cache::MethodLinkSpeciesSet->new($self);
}


package Bio::EnsEMBL::DBSQL::Cache::MethodLinkSpeciesSet;


use base qw/Bio::EnsEMBL::DBSQL::Support::FullIdCache/;
use strict;
use warnings;


sub support_additional_lookups {
    return 1;
}

sub compute_keys {
    my ($self, $mlss) = @_;
    return {
        method => sprintf('%d', $mlss->method->dbID),
        method_species_set => sprintf('%d_%d', $mlss->method->dbID, $mlss->species_set_obj->dbID),
        (map {sprintf('genome_db_%d', $_->dbID) => 1} @{$mlss->species_set_obj->genome_dbs()}),
        (map {sprintf('genome_db_%d_method_%s', $_->dbID, uc $mlss->method->type) => 1} @{$mlss->species_set_obj->genome_dbs()}),
    }
}


1;

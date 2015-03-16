=head1 LICENSE

Copyright [1999-2015] Wellcome Trust Sanger Institute and the EMBL-European Bioinformatics Institute

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

=head1 NAME

Bio::EnsEMBL::Compara::DBSQL::DnaFragAdaptor 

=head1 SYNOPSIS

  use Bio::EnsEMBL::Registry;

  my $reg = "Bio::EnsEMBL::Registry";

  $reg->load_registry_from_db(-host=>"ensembldb.ensembl.org", -user=>"anonymous");

  my $dnafrag_adaptor = $reg->get_adaptor("Multi", "compara", "DnaFrag");

  $dnafrag_adaptor->store($dnafrag);
  
  $dnafrag = $dnafrag_adaptor->fetch_by_dbID(905406);
  $dnafrag = $dnafrag_adaptor->fetch_by_GenomeDB_and_name($human_genome_db, 'X');
  $dnafrags = $dnafrag_adaptor->fetch_all_by_GenomeDB_region(
                                $human_genome_db, 'chromosome')

  $dnafrag = $dnafrag_adaptor->fetch_by_Slice($slice);
  $all_dnafrags = $dnafrag_adaptor->fetch_all();

=head1 DESCRIPTION

This module is intended to access data in the dnafrag table. The dnafrag table stores information on the toplevel sequences such as the name, coordinate system, length and species.

=head1 APPENDIX

The rest of the documentation details each of the object methods. Internal methods are usually preceded with a _

=cut


# Let the code begin...


package Bio::EnsEMBL::Compara::DBSQL::DnaFragAdaptor;

use strict;
use warnings;

use Bio::EnsEMBL::DBSQL::BaseAdaptor;
use Bio::EnsEMBL::Compara::DnaFrag;
use Bio::EnsEMBL::Utils::Exception qw( throw warning verbose );

use Bio::EnsEMBL::DBSQL::Support::LruIdCache;

use base qw(Bio::EnsEMBL::Compara::DBSQL::BaseAdaptor);


#
# Virtual / overriden methods from Bio::EnsEMBL::DBSQL::BaseAdaptor
######################################################################

sub ignore_cache_override {
    return 1;
}

sub _build_id_cache {
    my $self = shift;
    my $cache = Bio::EnsEMBL::DBSQL::Support::LruIdCache->new($self, 3000);
    $cache->build_cache();
    return $cache;
}



#
# FETCH methods
#####################


=head2 fetch_by_GenomeDB_and_name

  Arg [1]    : integer $genome_db_id
                  - or -
               Bio::EnsEMBL::Compara::DBSQL::GenomeDB
  Arg [2]    : string $name
  Example    : my $dnafrag = $dnafrag_adaptor->fetch_by_GenomeDB_and_name($human_genome_db, 'X');
  Example    : my $dnafrag = $dnafrag_adaptor->fetch_by_GenomeDB_and_name(1, 'X');
  Description: Returns the Bio::EnsEMBL::Compara::DnaFrag object corresponding to the
               Bio::EnsEMBL::Compara::GenomeDB and name given. $genome_db can
               be a valid $genome_db_id instead.
  Returntype : Bio::EnsEMBL::Compara::DnaFrag
  Exceptions : throw when genome_db_id cannot be retrieved
  Exceptions : warns and returns undef when no DnaFrag matches the query
  Caller     : $dnafrag_adaptor->fetch_by_GenomeDB_and_name
  Status     : Stable

=cut


sub fetch_by_GenomeDB_and_name {
  my ($self, $genome_db, $name) = @_;
  my $dnafrag; # Returned value
  
  my $genome_db_id;
  if ($genome_db =~ /^\d+$/) {
    $genome_db_id = $genome_db;
  } elsif ($genome_db && ref $genome_db && 
      $genome_db->isa('Bio::EnsEMBL::Compara::GenomeDB')) {
    $genome_db_id = $genome_db->dbID;
    if (!$genome_db_id) {
      throw("[$genome_db] does not have a dbID");
    }
  } else {
    throw("[$genome_db] must be Bio::EnsEMBL::Compara::GenomeDB\n");
  }


  $self->bind_param_generic_fetch($genome_db_id, SQL_INTEGER);
  $self->bind_param_generic_fetch($name, SQL_VARCHAR);
  $dnafrag = $self->generic_fetch_one('df.genome_db_id = ? AND df.name = ?');

  if (!$dnafrag) {
    $genome_db = sprintf('%s (%s)', $genome_db->name, $genome_db->assembly) if ref($genome_db);
#    warning("No Bio::EnsEMBL::Compara::DnaFrag found for $genome_db and chromosome $name");
  }
  return $dnafrag;
}


=head2 fetch_all_by_GenomeDB_region

  Arg [1]    : Bio::EnsEMBL::Compara::DBSQL::GenomeDB
  Arg [2]    : (optional) string $coord_system_name
  Arg [3]    : (optional) string $name
  Arg [4]    : (optional) boolean $is_reference
  Example    : my $human_chr_dnafrags = $dnafrag_adaptor->
                   fetch_all_by_GenomeDB_region(
                     $human_genome_db, 'chromosome')
  Description: Returns the Bio::EnsEMBL::Compara::DnaFrag object corresponding to the
               Bio::EnsEMBL::Compara::GenomeDB and region given.
  Returntype : listref of Bio::EnsEMBL::Compara::DnaFrag objects
  Exceptions : throw unless $genome_db is a Bio::EnsEMBL::Compara::GenomeDB
  Caller     : 
  Status     : Stable

=cut

sub fetch_all_by_GenomeDB_region {
  my ($self, $genome_db, $coord_system_name, $name, $is_reference) = @_;

  unless($genome_db && ref $genome_db && 
	 $genome_db->isa('Bio::EnsEMBL::Compara::GenomeDB')) {
    $self->throw("genome_db arg must be Bio::EnsEMBL::Compara::GenomeDB".
		 " not [$genome_db]\n")
  }

  my $gdb_id = $genome_db->dbID;

  unless($gdb_id) {
    $self->throw('GenomeDB does not have a dbID. Is it stored in the db?');
  }

#  unless($dnafrag_type) {
#    $self->throw('dnafrag_type argument must be defined');
#  }

  my $sql = "df.genome_db_id = ?";
  $self->bind_param_generic_fetch($gdb_id, SQL_INTEGER);

  if(defined $coord_system_name) {
   unless ($coord_system_name eq "toplevel"){
    $sql .= ' AND df.coord_system_name = ?';
    $self->bind_param_generic_fetch($coord_system_name, SQL_VARCHAR);
   }
  }

  if(defined $name) {
    $sql .= ' AND df.name = ?';
    $self->bind_param_generic_fetch($name, SQL_VARCHAR);
  }

  if(defined $is_reference) {
    $sql .= ' AND df.is_reference = ?';
    $self->bind_param_generic_fetch($is_reference, SQL_INTEGER);
  }

  return $self->generic_fetch($sql);
}


=head2 fetch_by_Slice

  Arg [1]    : Bio::EnsEMBL::Slice $slice
  Example    : $dnafrag = $dnafrag_adaptor->fetch_by_Slice($slice);
  Description: Retrieves the DnaFrag corresponding to this
               Bio::EnsEMBL::Slice object
  Returntype : Bio::EnsEMBL::Compara::DnaFrag
  Exceptions : thrown if $slice is not a Bio::EnsEMBL::Slice
  Caller     : general
  Status     : Stable

=cut

sub fetch_by_Slice {
  my ($self, $slice) = @_;

  my $genome_db_adaptor = $self->db->get_GenomeDBAdaptor;
  my $genome_db = $genome_db_adaptor->fetch_by_Slice($slice);

  return $self->fetch_by_GenomeDB_and_name($genome_db, $slice->seq_region_name);
}

=head2 fetch_all

  Arg         : none
  Example     : my $all_dnafrags = $dnafrag_adaptor->fetch_all();
  Description : fetches all Bio::EnsEMBL::Compara::DnaFrag objects for this
                compara database
  Returntype  : listref of all Bio::EnsEMBL::Compara::DnaFrag objects
  Exceptions  : none
  Caller      : general
  Status      : Stable

=cut

sub fetch_all {
  my ($self) = @_;

  my $columns = join(", ", $self->_columns);
  my $tablenames = join(', ', map({ join(' ', @$_) } $self->_tables));
  my $sql = "SELECT $columns FROM $tablenames";

  my $sth = $self->prepare($sql);

  $sth->execute;
  return $self->_objs_from_sth( $sth );
}

=head2 _tables

  Args       : none
  Example    : $tables = $self->_tables()
  Description: a list of [tablename, alias] pairs for use with generic_fetch
  Returntype : list of [tablename, alias] pairs
  Exceptions : none
  Caller     : BaseAdaptor::generic_fetch
  Status     : Stable

=cut

sub _tables {
  return (
      ['dnafrag', 'df']
      );
}

=head2 _columns

  Args       : none
  Example    : $columns = $self->_columns()
  Description: a list of [tablename, alias] pairs for use with generic_fetch
  Returntype : list of [tablename, alias] pairs
  Exceptions : none
  Caller     : BaseAdaptor::generic_fetch
  Status     : Stable

=cut

sub _columns {
  return ('df.dnafrag_id',
          'df.length',
          'df.name',
          'df.genome_db_id',
          'df.coord_system_name',
          'df.is_reference'
          );
}

=head2 _objs_from_sth

  Args[1]    : DBI::row_hashref $hashref containing key-value pairs
  Example    : my $dna_frags = $self->_objs_from_sth($sth);
  Description: convert DBI row hash reference into a 
               Bio::EnsEMBL::Compara::DnaFrag object
  Returntype : listref of Bio::EnsEMBL::Compara::DnaFrag objects
  Exceptions : throw if $sth is not supplied
  Caller     : general
  Status     : Stable

=cut

sub _objs_from_sth {
  my ($self, $sth) = @_;

  throw if (!$sth);

  my $these_dnafrags = [];

  my ($dbID, $length, $name, $genome_db_id, $coord_system_name, $is_reference);
  $sth->bind_columns(
          \$dbID,
          \$length,
          \$name,
          \$genome_db_id,
          \$coord_system_name,
          \$is_reference
      );

  my $gda = $self->db->get_GenomeDBAdaptor();

  while ($sth->fetch()) {

    my $this_dnafrag = $self->_id_cache->cache->{$dbID};
    if (not defined $this_dnafrag) {
        $this_dnafrag = Bio::EnsEMBL::Compara::DnaFrag->new_fast(
            {'dbID' => $dbID,
            'adaptor' => $self,
            'length' => $length,
            'name' => $name,
            'genome_db_id' => $genome_db_id,
            'coord_system_name' => $coord_system_name,
            'is_reference' => $is_reference}
        );
        $self->_id_cache->put($dbID, $this_dnafrag);
    }

    push(@$these_dnafrags, $this_dnafrag);
  }

  return $these_dnafrags;
}



=head2 store

 Arg [1]     : Bio::EnsEMBL::Compara::DnaFrag $new_dnafrag
 Example     : $dnafrag_adaptor->store($new_dnafrag)
 Description : Stores a Bio::EnsEMBL::Compara::DnaFrag object
               in the DB-
 ReturnType  : integer new_dnafrag_id
 Exceptions  : throw if $new_dnafrag is not a
               Bio::EnsEMBL::Compara::DnaFrag object
 Exceptions  : does not store anything if $new_dnafrag->adaptor is
               already defined and is equal to this adaptor
 Exceptions  : throw if $new_dnafrag->genome_db is not defined or has
               no dbID.
 Exceptions  : throw if $new_dnafrag has no name
 Caller      : $object->methodname
  Status     : Stable

=cut

sub store {
   my ($self, $dnafrag) = @_;

   if( !defined $dnafrag ) {
       throw("Must store $dnafrag object");
   }

   if( !ref $dnafrag || !$dnafrag->isa('Bio::EnsEMBL::Compara::DnaFrag') ) {
       throw("Must have dnafrag arg [$dnafrag]");
   }

   if (defined $dnafrag->adaptor() && $dnafrag->adaptor() == $self) {
     return $dnafrag->dbID();
   }

   my $gdb = $dnafrag->genome_db();

   if( !defined $gdb || !ref $gdb || !$gdb->isa('Bio::EnsEMBL::Compara::GenomeDB') ) {
       $self->throw("Must have genomedb attached to the dnafrag to store the dnafrag [$gdb]");
   }

   if( !defined $gdb->dbID ) {
       throw("genomedb must be stored (no dbID). Store genomedb first");
   }

  if( !defined $dnafrag->name ) {
       throw("dnafrag must have a name");
   }

   my $name = $dnafrag->name;
   my $gid =  $gdb->dbID;
   my $type = $dnafrag->coord_system_name;
   my $stored_id;

   # use INSERT IGNORE so that this method can be used 
   # in a multi-process environment

   my $sth = $self->prepare("
     INSERT IGNORE INTO dnafrag ( genome_db_id, coord_system_name,
                                  name, length, is_reference )
     VALUES (?,?,?,?,?)");

   my $rows_inserted = $sth->execute($gid, $type, $name, $dnafrag->length, $dnafrag->is_reference);
   
   if ($rows_inserted > 0) {
     $stored_id = $self->dbc->db_handle->last_insert_id(undef, undef, 'dnafrag', 'dnafrag_id');
   } else {
     # entry was already stored by another process
     my $sth2 = $self->prepare("
        SELECT dnafrag_id 
          FROM dnafrag 
         WHERE name= ?
           AND genome_db_id= ?");
     $sth2->execute($name, $gid);
     ($stored_id) = $sth2->fetchrow_array();
   }

   throw("DnaFrag apparently already stored, but could not be retrieved")
       if not defined $stored_id;

   $dnafrag->adaptor($self);
   $dnafrag->dbID($stored_id);

   return $dnafrag->dbID;
}

=head2 is_already_stored

 Title   : is_already_stored
 Usage   : $self->is_already_stored($dnafrag)
 Function: checks if already stored by querying database
 Example :
 Returns : $dnafrag->dbID if stored and 0 if not stored
 Args    : Bio::EnsEMBL::Compara::DnaFrag object
 Status  : Stable

=cut

sub is_already_stored {
   my ($self,$dnafrag) = @_;

   if( !defined $dnafrag ) {
       $self->throw("Must have dnafrag object");
   }

   if( !ref $dnafrag || !$dnafrag->isa('Bio::EnsEMBL::Compara::DnaFrag') ) {
       $self->throw("Must have dnafrag arg [$dnafrag]");
   }

   if (defined $dnafrag->adaptor() && $dnafrag->adaptor() == $self) {
     return $dnafrag->dbID();
   }
   
   my $gdb = $dnafrag->genome_db();

   if( !defined $gdb || !ref $gdb || !$gdb->isa('Bio::EnsEMBL::Compara::GenomeDB') ) {
       $self->throw("Must have genomedb attached to the dnafrag to store the dnafrag [$gdb]");
   }


   if( !defined $gdb->dbID ) {
       $self->throw("genomedb must be stored (no dbID). Store genomedb first");
   }

   if( !defined $dnafrag->name ) {
       $self->throw("dna frag must have a name");
   }
   
   my $name = $dnafrag->name;
   my $gid =  $gdb->dbID;
   my $sth = $self->prepare("
      SELECT dnafrag_id 
        FROM dnafrag 
       WHERE name= ?
         AND genome_db_id= ?
   ");

   unless ($sth->execute( "$name", $gid )) {
     $self->throw("Failed execution of a select query");
   }

   my ($dnafrag_id) = $sth->fetchrow_array();

   if (defined $dnafrag_id) {
     # $dnafrag already stored
     $dnafrag->dbID($dnafrag_id);
     $dnafrag->adaptor( $self );
     return $dnafrag_id;
   } 
  return 0;
} 
   

=head2 store_if_needed

 Title   : store_if_needed
 Usage   : $self->store_if_needed($dnafrag)
 Function: store instance in the defined database if NOT
           already present.
 Example :
 Returns : $dnafrag->dbID
 Args    : Bio::EnsEMBL::Compara::DnaFrag object
 Status  : Stable


=cut


sub store_if_needed {

   my ($self,$dnafrag) = @_;

   $self->store($dnafrag) unless($self->is_already_stored($dnafrag));
   return $dnafrag->dbID;
}


=head2 update

 Title   : update
 Usage   : $self->update($dnafrag)
 Function: look for this dnafrag in the database, using the genome_db_id,
           the coordinate_system_name and the name of the
           Bio::EnsEMBL::Compara::DnaFrag object. If there is already an
           entry in the database for this dnafrag, it does do anything. If
           the length is different, it updates it. If there is not any entry
           for this, it stores it.
 Example :
 Returns : int $dnafrag->dbID
 Args    : Bio::EnsEMBL::Compara::DnaFrag object
 Status  : Stable

=cut


sub update {
  my ($self,$dnafrag) = @_;

  my $current_verbose_level = verbose();
  verbose(0);
  my $existing_dnafrag = $self->fetch_by_GenomeDB_and_name($dnafrag->genome_db, $dnafrag->name);
  verbose($current_verbose_level);

  if (!$existing_dnafrag) {
    return $self->store($dnafrag);
  }

  if ($existing_dnafrag->length != $dnafrag->length or $existing_dnafrag->is_reference != $dnafrag->is_reference) {
    my $sql = "UPDATE dnafrag SET length = ?, is_reference = ? WHERE dnafrag_id = ?";
    my $sth = $self->prepare($sql);
    $sth->execute($dnafrag->length, $dnafrag->is_reference, $existing_dnafrag->dbID);
  }
  $dnafrag->dbID($existing_dnafrag->dbID);
 
  return $dnafrag->dbID;
}

1;

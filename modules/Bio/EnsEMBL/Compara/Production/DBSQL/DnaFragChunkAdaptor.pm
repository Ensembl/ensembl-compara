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

Bio::EnsEMBL::Compara::Production::DBSQL::DnaFragChunkAdaptor

=cut

package Bio::EnsEMBL::Compara::Production::DBSQL::DnaFragChunkAdaptor;

use strict;
use warnings;

use Bio::EnsEMBL::Compara::Production::DnaFragChunk;

use Bio::EnsEMBL::Compara::DBSQL::DnaFragAdaptor;
use Bio::EnsEMBL::Compara::DBSQL::SequenceAdaptor;

use Bio::EnsEMBL::DBSQL::BaseAdaptor;
our @ISA = qw(Bio::EnsEMBL::DBSQL::BaseAdaptor);


#############################
#
# store methods
#
#############################

=head2 store

  Arg[1]     : one or many DnaFragChunk objects
  Example    : $adaptor->store($chunk);
  Description: stores DnaFragChunk objects into compara database
  Returntype : none
  Exceptions : none
  Caller     : general

=cut

sub store {
  my ($self, $dfc)  = @_;

  return unless($dfc);
  return unless($dfc->isa('Bio::EnsEMBL::Compara::Production::DnaFragChunk'));

  my $query = "INSERT ignore INTO dnafrag_chunk".
              "(dnafrag_id,sequence_id,seq_start,seq_end, dnafrag_chunk_set_id) ".
              "VALUES (?,?,?,?,?)";

  $dfc->sequence_id($self->db->get_SequenceAdaptor->store($dfc->sequence));

  #print("$query\n");
  my $sth = $self->prepare($query);
  my $insertCount =
     $sth->execute($dfc->dnafrag_id, $dfc->sequence_id,
                   $dfc->seq_start, $dfc->seq_end, $dfc->dnafrag_chunk_set_id);
  if($insertCount>0) {
    #sucessful insert
    $dfc->dbID( $self->dbc->db_handle->last_insert_id(undef, undef, 'dnafrag_chunk', 'dnafrag_chunk_id') );
    $sth->finish;
  } else {
    $sth->finish;
    #UNIQUE(dnafrag_id,seq_start,seq_end,dnafrag_chunk_set_id) prevented insert
    #since dnafrag_chunk was already inserted so get dnafrag_chunk_id with select
    my $sth2 = $self->prepare("SELECT dnafrag_chunk_id FROM dnafrag_chunk ".
           " WHERE dnafrag_id=? and seq_start=? and seq_end=? and dnafrag_chunk_set_id=?");
    $sth2->execute($dfc->dnafrag_id, $dfc->seq_start, $dfc->seq_end, $dfc->dnafrag_chunk_set_id);
    my($id) = $sth2->fetchrow_array();
    warn("DnaFragChunkAdaptor: insert failed, but dnafrag_chunk_id select failed too") unless($id);
    $dfc->dbID($id);
    $sth2->finish;
  }

  $dfc->adaptor($self);
  
  return $dfc;
}


sub update_sequence
{
  my $self = shift;
  my $dfc  = shift;

  return 0 unless($dfc);
  return 0 unless($dfc->isa('Bio::EnsEMBL::Compara::Production::DnaFragChunk'));
  return 0 unless($dfc->dbID);
  return 0 unless(defined($dfc->sequence));
  return 0 unless(length($dfc->sequence) <= 11500000);  #limited by myslwd max_allowed_packet=12M 

  my $seqDBA = $self->db->get_SequenceAdaptor;
  my $newSeqID = $seqDBA->store($dfc->sequence);

  return if($dfc->sequence_id == $newSeqID); #sequence unchanged

  my $sth = $self->prepare("UPDATE dnafrag_chunk SET sequence_id=? where dnafrag_chunk_id=?");
  $sth->execute($newSeqID, $dfc->dbID);
  $sth->finish();
  $dfc->sequence_id($newSeqID);
  return $newSeqID;
}


###############################################################################
#
# fetch methods
#
###############################################################################

=head2 fetch_by_dbID

  Arg [1]    : int $id
               the unique database identifier for the feature to be obtained
  Example    : $dfc = $adaptor->fetch_by_dbID(1234);
  Description: Returns the DnaFragChunk created from the database defined by the
               the id $id.
  Returntype : Bio::EnsEMBL::Compara::Production::DnaFragChunk
  Exceptions : thrown if $id is not defined
  Caller     : general

=cut

sub fetch_by_dbID{
  my ($self,$id) = @_;

  unless(defined $id) {
    $self->throw("fetch_by_dbID must have an id");
  }

  my @tabs = $self->_tables;

  my ($name, $syn) = @{$tabs[0]};

  #construct a constraint like 't1.table1_id = 1'
  my $constraint = "${syn}.${name}_id = $id";

  #return first element of _generic_fetch list
  my ($obj) = @{$self->_generic_fetch($constraint)};
  return $obj;
}

=head2 fetch_all_by_DnaFragChunkSet

  Arg [1...] : Bio::EnsEMBL::Compara::Production::DnaFragChunkSet 
  Example    : $dfc = $adaptor->fetch_all_by_(1234);
  Description: Returns an array of DnaFragChunks created from the database from a DnaFragChunkSet
  Returntype : listref of Bio::EnsEMBL::Compara::Production::DnaFragChunk objects
  Exceptions : thrown if $dnafrag_chunk_set is not defined
  Caller     : general

=cut

sub fetch_all_by_DnaFragChunkSet {
  my $self = shift;
  my $dnafrag_chunk_set = shift;

  unless(defined $dnafrag_chunk_set) {
    $self->throw("fetch_all_by_DnaFragChunkSet must have a DnaFragChunkSet");
  }

  my $dnafrag_chunk_set_id = $dnafrag_chunk_set->dbID;
  my $constraint = "dfc.dnafrag_chunk_set_id = $dnafrag_chunk_set_id";

  #printf("fetch_all_by_DnaFragChunkSet has contraint\n$constraint\n");

  return $self->_generic_fetch($constraint);
}


=head2 fetch_all

  Arg        : None
  Example    :
  Description:
  Returntype :
  Exceptions :
  Caller     :

=cut

sub fetch_all {
  my $self = shift;

  return $self->_generic_fetch();
}

############################
#
# INTERNAL METHODS
# (pseudo subclass methods)
#
############################

#internal method used in multiple calls above to build objects from table data

sub _tables {
  my $self = shift;

  return (['dnafrag_chunk', 'dfc'] );
}

sub _columns {
  my $self = shift;

  return qw (dfc.dnafrag_chunk_id
             dfc.dnafrag_chunk_set_id
             dfc.dnafrag_id
             dfc.seq_start
             dfc.seq_end
             dfc.sequence_id
            );
}

sub _default_where_clause {
  my $self = shift;
  return '';
}

sub _final_clause {
  my $self = shift;
  $self->{'_final_clause'} = shift if(@_);
  return $self->{'_final_clause'};
}


sub _objs_from_sth {
  my ($self, $sth) = @_;

  my @chunks = ();

  while( my $row_hashref = $sth->fetchrow_hashref()) {

    my $dfc = Bio::EnsEMBL::Compara::Production::DnaFragChunk->new();

    $dfc->adaptor($self);
    $dfc->dbID($row_hashref->{'dnafrag_chunk_id'});
    $dfc->seq_start($row_hashref->{'seq_start'});
    $dfc->seq_end($row_hashref->{'seq_end'});
    $dfc->sequence_id($row_hashref->{'sequence_id'});
    $dfc->dnafrag_id($row_hashref->{'dnafrag_id'});
    $dfc->dnafrag_chunk_set_id($row_hashref->{'dnafrag_chunk_set_id'}),

    push @chunks, $dfc;

  }
  $sth->finish;

  return \@chunks
}


=head2 _generic_fetch

  Arg [1]    : (optional) string $constraint
               An SQL query constraint (i.e. part of the WHERE clause)
  Arg [2]    : (optional) string $logic_name
               the logic_name of the analysis of the features to obtain
  Example    : $fts = $a->_generic_fetch('contig_id in (1234, 1235)', 'Swall');
  Description: Performs a database fetch and returns feature objects in
               contig coordinates.
  Returntype : listref of Bio::EnsEMBL::Production::DnaFragChunk in contig coordinates
  Exceptions : none
  Caller     : internal

=cut

sub _generic_fetch {
  my ($self, $constraint, $join) = @_;

  my @tables = $self->_tables;
  my $columns = join(', ', $self->_columns());

  if ($join) {
    foreach my $single_join (@{$join}) {
      my ($tablename, $condition, $extra_columns) = @{$single_join};
      if ($tablename && $condition) {
        push @tables, $tablename;

        if($constraint) {
          $constraint .= " AND $condition";
        } else {
          $constraint = " $condition";
        }
      }
      if ($extra_columns) {
        $columns .= ", " . join(', ', @{$extra_columns});
      }
    }
  }

  #construct a nice table string like 'table1 t1, table2 t2'
  my $tablenames = join(', ', map({ join(' ', @$_) } @tables));

  my $sql = "SELECT $columns FROM $tablenames";

  my $default_where = $self->_default_where_clause;
  my $final_clause = $self->_final_clause;

  #append a where clause if it was defined
  if($constraint) {
    $sql .= " WHERE $constraint ";
    if($default_where) {
      $sql .= " AND $default_where ";
    }
  } elsif($default_where) {
    $sql .= " WHERE $default_where ";
  }

  #append additional clauses which may have been defined
  $sql .= " $final_clause" if($final_clause);

  #print STDERR $sql,"\n";
  my $sth = $self->prepare($sql);
  $sth->execute;

  # print STDERR $sql,"\n";
  # print STDERR "sql execute finished. about to build objects\n";

  return $self->_objs_from_sth($sth);

}

sub _fetch_DnaFrag_by_dbID
{
  my $self       = shift;
  my $dnafrag_id = shift;

  return $self->db->get_DnaFragAdaptor->fetch_by_dbID($dnafrag_id);  
}

1;

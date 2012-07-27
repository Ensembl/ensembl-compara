=head1 LICENSE

  Copyright (c) 1999-2012 The European Bioinformatics Institute and
  Genome Research Limited.  All rights reserved.

  This software is distributed under a modified Apache license.
  For license details, please see

    http://www.ensembl.org/info/about/code_licence.html

=head1 CONTACT

  Please email comments or questions to the public Ensembl
  developers list at <dev@ensembl.org>.

  Questions may also be sent to the Ensembl help desk at
  <helpdesk@ensembl.org>.

=head1 NAME

Bio::EnsEMBL::Compara::Production::DBSQL::DnaFragChunkAdaptor

=head1 SYNOPSIS

=head1 APPENDIX

=cut

package Bio::EnsEMBL::Compara::Production::DBSQL::DnaFragChunkSetAdaptor;

use strict;
use Bio::EnsEMBL::Compara::Production::DnaFragChunk;
use Bio::EnsEMBL::Compara::Production::DnaFragChunkSet;

use Bio::EnsEMBL::DBSQL::BaseAdaptor;
our @ISA = qw(Bio::EnsEMBL::DBSQL::BaseAdaptor);


#
# STORE METHODS
#
################

=head2 store

  Arg [1]    : Bio::EnsEMBL::Compara::Production::DnaFragChunkSet
  Example    :
  Description: stores the set of DnaFragChunk objects
  Returntype : int dbID of DnaFragChunkSet
  Exceptions :
  Caller     :

=cut

sub store {
  my ($self,$chunkSet) = @_;

  unless($chunkSet->isa('Bio::EnsEMBL::Compara::Production::DnaFragChunkSet')) {
    $self->throw(
      "set arg must be a [Bio::EnsEMBL::Compara::Production::DnaFragChunkSet] "
    . "not a $chunkSet");
  }
  my $description = $chunkSet->description or undef;

  my $insertCount=0;

  my $sth = $self->prepare("INSERT ignore INTO dnafrag_chunk_set (dna_collection_id, description) VALUES (?,?)");
  $insertCount = $sth->execute($chunkSet->dna_collection->dbID, $description);
  $sth->finish;

  if($insertCount>0) {
    $chunkSet->dbID( $sth->{'mysql_insertid'} );
  }

  return $chunkSet->dbID;

}

#
# FETCH METHODS
#
################

=head2 fetch_by_dbID

  Arg [1]    : int $id
               the unique database identifier for the feature to be obtained
  Example    : $feat = $adaptor->fetch_by_dbID(1234);
  Description: Returns the feature created from the database defined by the
               the id $id.
  Returntype : Bio::EnsEMBL::Compara::Production::DnaFragChunkSet
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

=head2 fetch_all_by_DnaCollection

  Arg [1]    : Bio::EnsEMBL::Compara::Production::DnaCollection $dna_collection
  Example    : $feat = $adaptor->fetch_all_by_dna_collection(1234);
  Description: Returns all the DnaFragChunkSets for this DnaCollection
  Returntype : Bio::EnsEMBL::Compara::Production::DnaFragChunkSet
  Exceptions : thrown if $dna_collection is not defined
  Caller     : general

=cut

sub fetch_all_by_DnaCollection {
    my ($self, $dna_collection) = @_;
    
    unless (defined $dna_collection) {
        $self->throw("fetch_by_dna_collection must have a dna_collection");
    }
    my $dna_collection_id = $dna_collection->dbID;

    #construct a constraint like 't1.table1_id = 1'
    my $constraint = "sc.dna_collection_id = '$dna_collection_id'";
    #print("fetch_by_set_name contraint:\n$constraint\n");
    
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



#
# INTERNAL METHODS
#
###################

=head2 _generic_fetch

  Arg [1]    : (optional) string $constraint
               An SQL query constraint (i.e. part of the WHERE clause)
  Arg [2]    : (optional) string $logic_name
               the logic_name of the analysis of the features to obtain
  Example    : $fts = $a->_generic_fetch('contig_id in (1234, 1235)', 'Swall');
  Description: Performs a database fetch and returns feature objects in
               contig coordinates.
  Returntype : listref of Bio::EnsEMBL::SeqFeature in contig coordinates
  Exceptions : none
  Caller     : BaseFeatureAdaptor, DnaFragChunkSetAdaptor::_generic_fetch

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
  $sql .= " $final_clause";

  my $sth = $self->prepare($sql);
  $sth->execute;

#  print STDERR $sql,"\n";

  return $self->_objs_from_sth($sth);
}

sub _tables {
  my $self = shift;

  return (['dnafrag_chunk_set', 'sc']);
}

sub _columns {
  my $self = shift;

  return qw (sc.dna_collection_id
             sc.dnafrag_chunk_set_id);
}

sub _objs_from_sth {
  my ($self, $sth) = @_;
  
  my %column;
  $sth->bind_columns( \( @column{ @{$sth->{NAME_lc} } } ));

  my @sets = ();
  my %setNames;
  my %setDnaFragChunkIds;

  while ($sth->fetch()) {
    my ($dna_collection_id, $dnafrag_chunk_set_id);
    $dna_collection_id = $column{'dna_collection_id'};
    $dnafrag_chunk_set_id = $column{'dnafrag_chunk_set_id'};

    my $chunkSet = new Bio::EnsEMBL::Compara::Production::DnaFragChunkSet
                       -dbid => $dnafrag_chunk_set_id,
                       -adaptor => $self,
                       -dna_collection_id => $dna_collection_id;

    push @sets, $chunkSet;

  }
  $sth->finish;

  return \@sets
}

sub _default_where_clause {
  my $self = shift;
  return '';
}

sub _final_clause {
  my $self = shift;

  return '';
}

1;






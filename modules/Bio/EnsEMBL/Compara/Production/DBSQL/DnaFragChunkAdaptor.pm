=head1 NAME

Bio::EnsEMBL::Compara::Production::DBSQL::DnaFragChunkAdaptor

=head1 SYNOPSIS

=head1 CONTACT

Jessica Severin : jessica@ebi.ac.uk

=head1 APPENDIX

=cut


package Bio::EnsEMBL::Compara::Production::DBSQL::DnaFragChunkAdaptor;

use Bio::EnsEMBL::Compara::Production::DnaFragChunk;

use Bio::EnsEMBL::Hive::DBSQL::AnalysisDataAdaptor;
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
              "(dnafrag_id,sequence_id,seq_start,seq_end,masking_analysis_data_id) ".
              "VALUES (?,?,?,?,?)";

  $dfc->sequence_id($self->db->get_SequenceAdaptor->store($dfc->sequence));

  if($dfc->masking_analysis_data_id==0 and defined($dfc->masking_options)) {
    my $dataDBA = $self->db->get_AnalysisDataAdaptor;
    $dfc->masking_analysis_data_id($dataDBA->store_if_needed($dfc->masking_options));
  }

  #print("$query\n");
  my $sth = $self->prepare($query);
  my $insertCount =
     $sth->execute($dfc->dnafrag_id, $dfc->sequence_id,
                   $dfc->seq_start, $dfc->seq_end,
                   $dfc->masking_analysis_data_id);
  if($insertCount>0) {
    #sucessful insert
    $dfc->dbID( $sth->{'mysql_insertid'} );
    $sth->finish;
  } else {
    $sth->finish;
    #UNIQUE(dnafrag_id,seq_start,seq_end,masking_analysis_data_id) prevented insert
    #since dnafrag_chunk was already inserted so get dnafrag_chunk_id with select
    my $sth2 = $self->prepare("SELECT dnafrag_chunk_id FROM dnafrag_chunk ".
           " WHERE dnafrag_id=? and seq_start=? and seq_end=? and masking_analysis_data_id=?");
    $sth2->execute($dfc->dnafrag_id, $dfc->seq_start, $dfc->seq_end,
                   $dfc->masking_analysis_data_id);
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

=head2 fetch_by_dbIDs

  Arg [1...] : int $id (multiple)
               the unique database identifier for the feature to be obtained
  Example    : $dfc = $adaptor->fetch_by_dbID(1234);
  Description: Returns an array of DnaFragChunk created from the database defined by the
               the id $id.
  Returntype : listref of Bio::EnsEMBL::Compara::Production::DnaFragChunk objects
  Exceptions : thrown if $id is not defined
  Caller     : general

=cut

sub fetch_by_dbIDs{
  my $self = shift;
  my @ids = @_;

  return undef unless(scalar(@ids));

  my $id_string = join(",", @ids);
  my $constraint = "dfc.dnafrag_chunk_id in ($id_string)";
  #printf("fetch_by_dbIDs has contraint\n$constraint\n");

  #return first element of _generic_fetch list
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

=head2 fetch_all_for_genome_db_id

  Arg [1]    : int $genome_db_id
  Example    : $chunks = $adaptor->fetch_all_for_genome_db_id(1);
  Description: Returns an array with all the DnaFragChunk objects for a given genome_db_id
  Returntype : listref of Bio::EnsEMBL::Compara::Production::DnaFragChunk objects
  Exceptions : thrown if $id is not defined
  Caller     : general

=cut

sub fetch_all_for_genome_db_id{
  my $self = shift;
  my $genome_db_id = shift;

  $self->throw() unless (defined $genome_db_id);
  
  my $constraint = "df.genome_db_id='$genome_db_id'";

  my $join = [[['dnafrag', 'df'], 'dfc.dnafrag_id=df.dnafrag_id']];
  
  return $self->_generic_fetch($constraint, $join);
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
             dfc.dnafrag_id
             dfc.seq_start
             dfc.seq_end
             dfc.masking_analysis_data_id
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

  my %column;
  $sth->bind_columns( \( @column{ @{$sth->{NAME_lc} } } ));

  my @chunks = ();

  while ($sth->fetch()) {
    my $dfc;

    $dfc = Bio::EnsEMBL::Compara::Production::DnaFragChunk->new();

    $dfc->adaptor($self);
    $dfc->dbID($column{'dnafrag_chunk_id'});
    $dfc->seq_start($column{'seq_start'});
    $dfc->seq_end($column{'seq_end'});
    $dfc->sequence_id($column{'sequence_id'});
    $dfc->dnafrag_id($column{'dnafrag_id'});
    $dfc->masking_analysis_data_id($column{'masking_analysis_data_id'});

    if($column{'masking_analysis_data_id'}) {
      $dfc->masking_options($self->_fetch_MaskingOptions_by_dbID($column{'masking_analysis_data_id'}));

      #reset masking_analysis_data_id second because setting masking_options internal clears ID
      $dfc->masking_analysis_data_id($column{'masking_analysis_data_id'});
    }

    #$dfc->display_short();
    
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

sub _fetch_MaskingOptions_by_dbID
{
  my $self    = shift;
  my $data_id = shift;

  $self->{'_masking_cache'} = {} unless(defined($self->{'_masking_cache'}));

  if(!defined($self->{'_masking_cache'}->{$data_id})) {
    #print("FETCH masking_options for data_id = $data_id\n");
    my $dataDBA = new Bio::EnsEMBL::Hive::DBSQL::AnalysisDataAdaptor($self->dbc);
    $self->{'_masking_cache'}->{$data_id} = $dataDBA->fetch_by_dbID($data_id);
  }
  
  return $self->{'_masking_cache'}->{$data_id};
}


1;

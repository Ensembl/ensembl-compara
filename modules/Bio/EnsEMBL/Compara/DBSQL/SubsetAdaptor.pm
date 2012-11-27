package Bio::EnsEMBL::Compara::DBSQL::SubsetAdaptor;

use strict;
use Bio::EnsEMBL::Compara::Subset;
use Bio::EnsEMBL::DBSQL::BaseAdaptor;
use Bio::EnsEMBL::Utils::Exception;

deprecate('SubsetAdaptor and Subset are deprecated and will be removed in e71. Please have a look at Member and MemberAdaptor, at the canonical member methods.');

our @ISA = qw(Bio::EnsEMBL::DBSQL::BaseAdaptor);


=head2 fetch_by_set_description

  Arg [1]    : string $set_description
  Example    : 
  Description: 
  Returntype : 
  Exceptions : 
  Caller     : 

=cut

sub fetch_by_set_description {
  my ($self,$set_description) = @_;

  unless(defined $set_description) {
    $self->throw("fetch_by_set_name must have a set_description");
  }

  #construct a constraint like 't1.table1_id = 1'
  my $constraint = "s.description = '$set_description'";
  #print("fetch_by_set_name contraint:\n$constraint\n");

  #return first element of generic_fetch list
  my ($obj) = @{$self->generic_fetch($constraint)};
  return $obj;
}


=head2 fetch_by_description_pattern

  Arg [1]    : string $description_pattern
  Example    : 
  Description: 
  Returntype : 
  Exceptions : 
  Caller     : 

=cut

sub fetch_by_description_pattern {
  my ($self,$description_pattern) = @_;

  unless(defined $description_pattern) {
    $self->throw("fetch_by_description_pattern must have a description_pattern");
  }

  #construct a constraint like 't1.table1_id = 1'
  my $constraint = "s.description LIKE '$description_pattern'";
  # print("fetch_by_description_pattern contraint:\n$constraint\n");

  #return first element of generic_fetch list
  my ($obj) = @{$self->generic_fetch($constraint)};
  return $obj;
}



#
# INTERNAL METHODS
#
###################


sub _tables {
  return (['subset', 's'], ['subset_member', 'sm']);
}

sub _columns {
  my $self = shift;

  return qw (s.subset_id
             s.description
             sm.subset_id
             sm.member_id);
}

sub _objs_from_sth {
  my ($self, $sth) = @_;
  
  my %column;
  $sth->bind_columns( \( @column{ @{$sth->{NAME_lc} } } ));

  my @sets = ();
  my %setNames;
  my %setMemberIds;

  while ($sth->fetch()) {
    my ($subset_id, $name, $member_id);
    $subset_id = $column{'subset_id'};
    $name = $column{'description'};
    $member_id = $column{'member_id'};

    if(defined($setMemberIds{$subset_id})) {
      $setMemberIds{$subset_id}->{$member_id} = $member_id;
    }
    else {
      $setNames{$subset_id} = $name;
      $setMemberIds{$subset_id} = {};
      $setMemberIds{$subset_id}->{$member_id} = $member_id;
    }
  }
  $sth->finish;

  my @allSubsetIds = keys(%setNames);

  foreach my $subset_id (@allSubsetIds) {
    my ($subset, @member_id_list, $member_id);

    @member_id_list = keys(%{$setMemberIds{$subset_id}});
    my $count = $#member_id_list + 1;
    # print("subset id = $subset_id has $count unique member_ids\n");
    
    $subset = Bio::EnsEMBL::Compara::Subset->new(-dbid => $subset_id,
                                                 -name => $setNames{$subset_id},
                                                 -adaptor => $self);
    # print("loading set '" . $setNames{$subset_id} . "' id=$subset_id\n");

    @{$subset->{'_member_id_list'}} = @member_id_list;

    push @sets, $subset;
  }

  return \@sets
}

sub _default_where_clause {
  return 's.subset_id = sm.subset_id';
}


#
# STORE METHODS
#
################

=head2 store

  Arg [1]    :
  Example    :
  Description:
  Returntype :
  Exceptions :
  Caller     :

=cut

sub store {
  my ($self,$subset) = @_;

  unless($subset->isa('Bio::EnsEMBL::Compara::Subset')) {
    $self->throw(
      "set arg must be a [Bio::EnsEMBL::Compara::Subset] "
    . "not a $subset");
  }

  my $sth = $self->prepare("INSERT ignore INTO subset (description) VALUES (?)");
  if($sth->execute($subset->description) >0) {
    $subset->dbID( $sth->{'mysql_insertid'} );
  } else {
    #print("insert failed, do select\n");
    my $sth2 = $self->prepare("SELECT subset_id FROM subset WHERE description=?");
    $sth2->execute($subset->description);
    my($id) = $sth2->fetchrow_array();
    $subset->dbID($id);
    $sth2->finish;
  }
  $sth->finish;
  #print("SubsetAdaptor:store() dbID = ", $subset->dbID, "\n");

  my @memberIds = @{$subset->member_id_list()};
  $sth = $self->prepare("INSERT ignore INTO subset_member (subset_id, member_id) VALUES (?,?)");
  foreach my $member_id (@memberIds) {
    $sth->execute($subset->dbID, $member_id) if($member_id);
  }
  $sth->finish;

  $subset->adaptor($self);

  return $subset->dbID;
}


=head2 store_link

  Arg [1]    :  Bio::EnsEMBL::Compara::MemberSet $subset
  Arg [2]    :  int $member_id
  Example    :
  Description:
  Returntype :
  Exceptions :
  Caller     :

=cut

sub store_link {
  my ($self, $subset, $member_id) = @_;

  unless($subset->isa('Bio::EnsEMBL::Compara::Subset')) {
    $self->throw(
      "set arg must be a [Bio::EnsEMBL::Compara::Subset] "
    . "not a $subset");
  }
  return unless($member_id);

  my $sth = $self->prepare("INSERT ignore INTO subset_member (subset_id, member_id) VALUES (?,?)");
  $sth->execute($subset->dbID, $member_id);
  $sth->finish;
}


=head2 delete_link

  Arg [1]    :  Bio::EnsEMBL::Compara::MemberSet $subset
  Arg [2]    :  int $member_id
  Example    :
  Description:
  Returntype :
  Exceptions :
  Caller     :

=cut

sub delete_link {
  my ($self, $subset, $member_id) = @_;

  unless($subset->isa('Bio::EnsEMBL::Compara::Subset')) {
    $self->throw(
      "set arg must be a [Bio::EnsEMBL::Compara::Subset] "
    . "not a $subset");
  }

  my $sth =
    $self->prepare("DELETE FROM subset_member WHERE subset_id=? AND member_id=?");
  $sth->execute($subset->dbID, $member_id);
  $sth->finish;
}


sub dumpFastaForSubset {
  my($self, $subset, $fastafile) = @_;

  unless($subset && $subset->isa('Bio::EnsEMBL::Compara::Subset')) {
    throw(
      "set arg must be a [Bio::EnsEMBL::Compara::Subset] "
    . "not a $subset");
  }
  unless($subset->dbID) {
    throw("subset must be in database and dbID defined");
  }
  
  my $sql = "SELECT member.source_name, member.stable_id, member.genome_db_id," .
            " member.member_id, member.description, sequence.sequence " .
            " FROM member, sequence, subset_member " .
            " WHERE subset_member.subset_id = " . $subset->dbID .
            " AND member.member_id=subset_member.member_id ".
            " AND member.sequence_id=sequence.sequence_id " ;
           # " ORDER BY member.stable_id;";

  open FASTAFILE, ">$fastafile"
    or die "Could not open $fastafile for output\n";
  print("writing fasta to loc '$fastafile'\n");

  my $sth = $self->prepare( $sql );
  $sth->execute();

  my ($source_name, $stable_id, $genome_db_id, $member_id, $description, $sequence);
  $sth->bind_columns( undef, \$source_name, \$stable_id, \$genome_db_id,
      \$member_id, \$description, \$sequence );

  while( $sth->fetch() ) {
    $sequence =~ s/(.{72})/$1\n/g;
    $genome_db_id ||= 0;
    print FASTAFILE ">$source_name:$stable_id IDs:$genome_db_id:$member_id $description\n$sequence\n";
  }
  close(FASTAFILE);

  $sth->finish();

  #
  # update this subset_id's  subset.dump_loc with the full path of this dumped fasta file
  #

  $sth = $self->prepare("UPDATE subset SET dump_loc = ? WHERE subset_id = ?");
  $sth->execute($fastafile, $subset->dbID);
  $sth->finish;
  $subset->dump_loc($fastafile);
}

1;






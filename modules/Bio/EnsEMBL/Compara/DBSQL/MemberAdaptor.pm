package Bio::EnsEMBL::Compara::DBSQL::MemberAdaptor;

use strict;
use Bio::EnsEMBL::Compara::Member;
use Bio::EnsEMBL::Compara::Attribute;
use Bio::EnsEMBL::Compara::DBSQL::BaseRelationAdaptor;

our @ISA = qw(Bio::EnsEMBL::Compara::BaseRelationAdaptor);


=head2 fetch_by_source_taxon

=cut

sub fetch_by_source_taxon {
  my ($self,$source_name,$taxon_id) = @_;

  $self->throw("source_name and taxon_id args are required") 
    unless($source_name && $taxon_id);

  my $constraint = "s.source_name = '$source_name' and m.taxon_id = $taxon_id";

  return $self->generic_fetch($constraint);
}

sub fetch_by_relation {
  my ($self, $relation) = @_;

  my $join;
  my $constraint;
  my $extra_columns;

  $self->throw() 
    unless (defined $relation && ref $relation);
  
  if ($relation->isa('Bio::EnsEMBL::Compara::Family')) {
    $join = [['family_member', 'fm'], 'm.member_id = fm.member_id'];
    my $family_id = $relation->dbID;
    $constraint = "fm.family_id = $family_id";
    $extra_columns = [qw(fm.family_id,
                         fm.member_id,
                         fm.cigar_line)];
  }
  elsif ($relation->isa('Bio::EnsEMBL::Compara::Domain')) {
    $join = [['domain_member', 'dm'], 'm.member_id = dm.member_id'];
    my $domain_id = $relation->dbID;
    $constraint = "dm.domain_id = $domain_id";
    $extra_columns = [qw(dm.domain_id,
                         dm.member_id,
                         dm.member_start,
                         dm.member_end)];
  }
  elsif ($relation->isa('Bio::EnsEMBL::Compara::Homology')) {
    $join = [['homology_member', 'hm'], 'm.member_id = hm.member_id'];
    my $homology_id = $relation->dbID;
    $constraint .= "hm.homology_id = $homology_id";
    $extra_columns = [qw(hm.homology_id,
                         hm.member_id,
                         hm.cigar_line,
                         hm.perc_cov,
                         hm.perc_id,
                         hm.perc_pos,
                         hm.exon_count,
                         hm.flag)];
  }
  else {
    $self->throw();
  }

  return $self->generic_fetch($constraint, $join, $extra_columns);
}

sub fetch_by_relation_source {
  my ($self, $relation, $source_name) = @_;

  my $join;
  my $constraint = "s.source_name = '$source_name'";

  $self->throw() 
    unless (defined $relation && ref $relation);
  
  $self->throw("source_name arg is required\n")
    unless ($source_name);

  if ($relation->isa('Bio::EnsEMBL::Compara::Family')) {
    $join = [['family_member', 'fm'], 'm.member_id = fm.member_id'];
    my $family_id = $relation->dbID;
    $constraint .= " AND fm.family_id = $family_id";
  }
  elsif ($relation->isa('Bio::EnsEMBL::Compara::Domain')) {
    $join = [['domain_member', 'dm'], 'm.member_id = dm.member_id'];
    my $domain_id = $relation->dbID;
    $constraint .= " AND dm.domain_id = $domain_id";
  }
  elsif ($relation->isa('Bio::EnsEMBL::Compara::Homology')) {
    $join = [['homology_member', 'hm'], 'm.member_id = hm.member_id'];
    my $homology_id = $relation->dbID;
    $constraint .= " AND hm.homology_id = $homology_id";
  }
  else {
    $self->throw();
  }
  return $self->generic_fetch($constraint, $join);
}

sub fetch_by_relation_source_taxon {
  my ($self, $relation, $source_name, $taxon_id) = @_;

  my $join;
  my $constraint = "s.source_name = '$source_name' AND m.taxon_id = $taxon_id";

  $self->throw()
    unless (defined $relation && ref $relation);
  
  $self->throw("source_name and taxon_id args are required") 
    unless($source_name && $taxon_id);

  if ($relation->isa('Bio::EnsEMBL::Compara::Family')) {
    $join = [['family_member', 'fm'], 'm.member_id = fm.member_id'];
    my $family_id = $relation->dbID;
    $constraint .= " AND fm.family_id = $family_id";
  }
  elsif ($relation->isa('Bio::EnsEMBL::Compara::Domain')) {
    $join = [['domain_member', 'dm'], 'm.member_id = dm.member_id'];
    my $domain_id = $relation->dbID;
    $constraint .= " AND dm.domain_id = $domain_id AND s.source_name";
  }
#  elsif ($relation->isa('Bio::EnsEMBL::Compara::Homology')) {
#  }
  else {
    $self->throw();
  }
  return $self->generic_fetch($constraint, $join);
}

sub _tables {
  my $self = shift;

  return {['member', 'm'], ['source', 's']};
}

sub _columns {
  my $self = shift;

  return qw (m.member_id,
             m.stable_id,
             m.taxon_id,
             m.genome_db_id,
             m.description,
             m.chr_name,
             m.chr_start,
             m.chr_end,
             m.sequence,
             s.source_id,
             s.source_name);
}

sub _objs_from_sth {
  my ($self, $sth) = @_;
  
  my %column;
  $sth->bind_columns( \( @column{ @{$sth->{NAME_lc} } } ));

  my @members = ();
  my @relation_attributes = ();

  while ($sth->fetch()) {
    push @members, Bio::EnsEMBL::Compara::Member->new_fast
      ('_dbID' => $column{'member_id'},
       '_stable_id' => $column{'stable_id'},
       '_taxon_id' => $column{'taxon_id'},
       '_genome_db_id' => $column{'genome_db_id'},
       '_description' => $column{'description'},
       '_chr_name' => $column{'chr_name'},
       '_chr_start' => $column{'chr_start'},
       '_chr_end' => $column{'chr_end'},
       '_sequence' => $column{'sequence'},
       '_source_id' => $column{'source_id'},
       '_source_name' => $column{'source_name'},
       '_adaptor' => $self);
    
    if (scalar keys %column > scalar $self->_columns) {
      my $attribute = new Bio::EnsEMBL::Compara::Attribute;
      $attribute->member_id($column{'member_id'});
      foreach my $key (keys %column) {
        next if (grep $column{$key},  $self->_columns);
        my $autoload_method = $column{$key};
        $attribute->$autoload_method($column{$key});
      }
    }
  }
  return [ \@members, \@relation_attributes ];  
}

sub _default_where_clause {
  my $self = shift;

  return 'm.source_id = s.source_id';
}

=head2 store

=cut

sub store {
  my ($self,$member) = @_;
  
  unless($member->isa('Bio::EnsEMBL::Compara::Member')) {
    $self->throw(
      "member arg must be a [Bio::EnsEMBL::Compara::Member]"
    . "not a $member");
  }

  $member->source_id($self->store_source($member->source_name));

  my $sth = 
    $self->prepare("INSERT INTO member (stable_id,source_id, 
                                taxon_id, genome_db_id, description,
                                chr_name, chr_start, chr_end, sequence) 
                    VALUES (?,?,?,?,?,?,?,?,?)");

  $sth->execute($member->stable_id,
		$member->source_id, 
		$member->taxon_id,
		$member->genome_db_id,
                $member->description,
		$member->chr_name, 
		$member->chr_start,
		$member->chr_end,
		$member->sequence);

  $member->dbID( $sth->{'mysql_insertid'} );
  $member->adaptor($self);
  if (defined $member->taxon) {
    $self->db->get_TaxonAdaptor->store_if_needed($member->taxon);
  }
  return $member->dbID;
}



=head2 update

  Arg [1]    : Bio::EnsEMBL::Compara::FamilyMember
  Example    : 
  Description: Updates the attributes of a family member that has already been
               stored in the database.  This is useful to update attributes
               such as a the alignment string which may have been calculated
               after the families were alreated created.  On success this 
               method returns the dbID of the updated member
  Returntype : int
  Exceptions : thrown if incorrect argument is provided
               thrown if the member to be updated does not have a dbID
  Caller     : general

=cut

sub update {
  my ($self, $member) = @_;

  unless($member->isa('Bio::EnsEMBL::Compara::Member')) {
    $self->throw(
      "member arg must be a [Bio::EnsEMBL::Compara::Member".
      "not a [$member]");
  }

  unless($member->dbID) {
    $self->throw("Family member does not have a dbID and cannot be updated");
  }

  my $sth = 
    $self->prepare("UPDATE family_members 
                    SET    family_id = ?, 
                           external_db_id = ?, 
                           external_member_id = ?, 
                           taxon_id = ?, 
                           alignment = ?
                    WHERE  family_member_id = ?");

  $sth->execute($member->family_id, $member->external_db_id, 
                $member->stable_id, $member->taxon_id, 
                $member->alignment_string, $member->dbID);

  return $member->dbID;
}


1;







package Bio::EnsEMBL::Compara::DBSQL::MemberAdaptor;

use strict; 
use warnings;
use Bio::EnsEMBL::Compara::Member;
use Bio::EnsEMBL::Compara::DBSQL::SequenceAdaptor;
use Bio::EnsEMBL::Compara::DBSQL::BaseAdaptor;
use Bio::EnsEMBL::Utils::Scalar qw(:all);
use Bio::EnsEMBL::Utils::Argument qw(rearrange);
use Bio::EnsEMBL::Utils::Exception qw(throw warning stack_trace_dump deprecate);
use DBI qw(:sql_types);

our @ISA = qw(Bio::EnsEMBL::Compara::DBSQL::BaseAdaptor);



sub fetch_all_by_sequence_id {
    my ($self, $sequence_id) = @_;

    $self->bind_param_generic_fetch($sequence_id, SQL_INTEGER);
    return $self->generic_fetch('m.sequence_id = ?');
}


=head2 fetch_by_source_stable_id

  Arg [1]    : (optional) string $source_name
  Arg [2]    : string $stable_id
  Example    : my $member = $ma->fetch_by_source_stable_id(
                   "Uniprot/SWISSPROT", "O93279");
  Example    : my $member = $ma->fetch_by_source_stable_id(
                   undef, "O93279");
  Description: Fetches the member corresponding to this $stable_id.
               Although two members from different sources might
               have the same stable_id, this never happens in a normal
               compara DB. You can set the first argument to undef
               like in the second example.
  Returntype : Bio::EnsEMBL::Compara::Member object
  Exceptions : throws if $stable_id is undef
  Caller     : 

=cut

sub fetch_by_source_stable_id {
  my ($self,$source_name, $stable_id) = @_;

  unless(defined $stable_id) {
    throw("fetch_by_source_stable_id must have an stable_id");
  }

  #construct a constraint like 't1.table1_id = 1'
  my $constraint = '';
  if ($source_name) {
    $constraint = 'm.source_name = ? AND ';
    $self->bind_param_generic_fetch($source_name, SQL_VARCHAR);
  }
  $constraint .= 'm.stable_id = ?';
  $self->bind_param_generic_fetch($stable_id, SQL_VARCHAR);

  return $self->generic_fetch_one($constraint);
}

sub fetch_all_by_source_stable_ids {
  my ($self,$source_name, $stable_ids) = @_;
  return [] if (!$stable_ids or !@$stable_ids);

  #construct a constraint like 't1.table1_id = 1'
  my $constraint = "";
  $constraint = "m.source_name = '$source_name' AND " if ($source_name);
  $constraint .= "m.stable_id IN ('".join("','", @$stable_ids). "')";

  #return first element of generic_fetch list
  my $obj = $self->generic_fetch($constraint);
  return $obj;
}

=head2 fetch_all

  Arg        : None
  Example    : my $members = $ma->fetch_all;
  Description: Fetch all the members in the db
               WARNING: Depending on the database where this method is called,
                        it can return a lot of data (objects) that has to be kept in memory.
                        Make sure you don't ask for more data than you can handle.
                        To access this data in a safer way, use fetch_all_Iterator instead.
  Returntype : listref of Bio::EnsEMBL::Compara::Member objects
  Exceptions : 
  Caller     : 

=cut

sub fetch_all {
  my $self = shift;

  return $self->generic_fetch();
}


=head2 fetch_all_Iterator

  Arg        : (optional) int $cache_size
  Example    : my $memberIter = $memberAdaptor->fetch_all_Iterator();
               for my $member ($memberIter->next) {
                  #do something with $member
               }
  Description: Returns an iterator over all the members in the database
               This is safer than fetch_all for large databases.
  Returntype : Bio::EnsEMBL::Utils::Iterator
  Exceptions : 
  Caller     : 
  Status     : Experimental

=cut

sub fetch_all_Iterator {
    my ($self, $cache_size) = @_;
    return $self->generic_fetch_Iterator($cache_size,"");
}

=head2 fetch_all_Iterator

  Arg[1]     : string $source_name
  Arg[2]     : (optional) int $cache_size
  Example    : my $memberIter = $memberAdaptor->fetch_all_by_source_Iterator("ENSEMBLGENE");
               for my $member ($memberIter->next) {
                  #do something with $member
               }
  Description: Returns an iterator over all the members corresponding
               to a source_name in the database.
               This is safer than fetch_all_by_source for large databases.
  Returntype : Bio::EnsEMBL::Utils::Iterator
  Exceptions : 
  Caller     : 
  Status     : Experimental

=cut

sub fetch_all_by_source_Iterator {
    my ($self, $source_name, $cache_size) = @_;
    throw("source_name arg is required\n") unless ($source_name);
    return $self->generic_fetch_Iterator($cache_size, "member.source_name = '$source_name'");
}


=head2 fetch_all_by_source

  Arg [1]    : string $source_name
  Example    : my $members = $ma->fetch_all_by_source(
                   "Uniprot/SWISSPROT");
  Description: Fetches the member corresponding to a source_name.
                WARNING: Depending on the database and the "source"
                where this method is called, it can return a lot of data (objects)
                that has to be kept in memory. Make sure you don't ask
                for more data than you can handle.
                To access this data in a safer way, use fetch_all_by_source_Iterator instead.
  Returntype : listref of Bio::EnsEMBL::Compara::Member objects
  Exceptions : throws if $source_name is undef
  Caller     :

=cut

sub fetch_all_by_source {
  my ($self,$source_name) = @_;

  throw("source_name arg is required\n")
    unless ($source_name);

  my $constraint = "m.source_name = '$source_name'";

  return $self->generic_fetch($constraint);
}


=head2 fetch_all_by_source_taxon

  Arg [1]    : string $source_name
  Arg [2]    : int $taxon_id
  Example    : my $members = $ma->fetch_all_by_source_taxon(
                   "Uniprot/SWISSPROT", 9606);
  Description: Fetches the member corresponding to a source_name and a taxon_id.
  Returntype : listref of Bio::EnsEMBL::Compara::Member objects
  Exceptions : throws if $source_name or $taxon_id is undef
  Caller     : 

=cut

sub fetch_all_by_source_taxon {
  my ($self,$source_name,$taxon_id) = @_;

  throw("source_name and taxon_id args are required") 
    unless($source_name && $taxon_id);

    $self->bind_param_generic_fetch($source_name, SQL_VARCHAR);
    $self->bind_param_generic_fetch($taxon_id, SQL_INTEGER);
    return $self->generic_fetch('m.source_name = ? AND m.taxon_id = ?');
}

=head2 fetch_all_by_source_genome_db_id

  Arg [1]    : string $source_name
  Arg [2]    : int $genome_db_id
  Example    : my $members = $ma->fetch_all_by_source_genome_db_id(
                   "Uniprot/SWISSPROT", 90);
  Description: Fetches the member corresponding to a source_name and a genome_db_id.
  Returntype : listref of Bio::EnsEMBL::Compara::Member objects
  Exceptions : throws if $source_name or $genome_db_id is undef
  Caller     : 

=cut

sub fetch_all_by_source_genome_db_id {
  my ($self,$source_name,$genome_db_id) = @_;

  throw("source_name and genome_db_id args are required") 
    unless($source_name && $genome_db_id);

    $self->bind_param_generic_fetch($source_name, SQL_VARCHAR);
    $self->bind_param_generic_fetch($genome_db_id, SQL_INTEGER);
    return $self->generic_fetch('m.source_name = ? AND m.genome_db_id = ?');
}


sub fetch_all_canonical_by_source_genome_db_id {
  my ($self,$source_name,$genome_db_id) = @_;

  throw("source_name and genome_db_id args are required") 
    unless($source_name && $genome_db_id);

    my $join = [[['member', 'mg'], 'mg.canonical_member_id = m.member_id']];

    $self->bind_param_generic_fetch($source_name, SQL_VARCHAR);
    $self->bind_param_generic_fetch($genome_db_id, SQL_INTEGER);
    return $self->generic_fetch('m.source_name = ? AND mg.genome_db_id = ?', $join);
}



sub _fetch_all_by_source_taxon_chr_name_start_end_strand_limit {
  my ($self,$source_name,$taxon_id,$chr_name,$chr_start,$chr_end,$chr_strand,$limit) = @_;

  $self->throw("all args are required") 
      unless($source_name && $taxon_id && $chr_start && $chr_end && $chr_strand && defined ($chr_name));

  my $constraint = "m.source_name = '$source_name' and m.taxon_id = $taxon_id 
                    and m.chr_name = '$chr_name' 
                    and m.chr_start >= $chr_start and m.chr_start <= $chr_end and m.chr_end <= $chr_end 
                    and m.chr_strand = $chr_strand";

  return $self->generic_fetch($constraint, undef, defined $limit ? "LIMIT $limit" : "");
}


=head2 get_source_taxon_count

  Arg [1]    : string $source_name
  Arg [2]    : int $taxon_id
  Example    : my $sp_gene_count = $memberDBA->get_source_taxon_count('ENSEMBLGENE',$taxon_id);
  Description: 
  Returntype : int $sp_gene_count is the number of members for this source_name and taxon_id
  Exceptions : 
  Caller     : 

=cut

sub get_source_taxon_count {
  my ($self,$source_name,$taxon_id) = @_;

  throw("source_name and taxon_id args are required") 
    unless($source_name && $taxon_id);

  my $sth = $self->prepare
    ("SELECT COUNT(*) FROM member WHERE source_name=? AND taxon_id=?");
  $sth->execute($source_name, $taxon_id);
  my ($count) = $sth->fetchrow_array();
  $sth->finish;

  return $count;
}


sub fetch_all_by_Domain {
    my ($self, $domain) = @_;
    assert_ref($domain, 'Bio::EnsEMBL::Compara::Domain');

    my $domain_id = $domain->dbID;
    my $constraint = "dm.domain_id = $domain_id";
    my $extra_columns = [qw(dm.domain_id dm.member_start dm.member_end)];
    my $join = [[['domain_member', 'dm'], 'm.member_id = dm.member_id', $extra_columns]];

    return $self->generic_fetch($constraint, $join);
}


=head2 fetch_all_by_MemberSet

  Arg[1]     : MemberSet $set: Currently: Domain, Family, Homology and GeneTree
                are supported
  Example    : $family_members = $m_adaptor->fetch_all_by_MemberSet($family);
  Description: Fetches from the database all the members attached to this set
  Returntype : arrayref of Bio::EnsEMBL::Compara::Member
  Exceptions : none
  Caller     : general

=cut

sub fetch_all_by_MemberSet {
    my ($self, $set) = @_;
    assert_ref($set, 'Bio::EnsEMBL::Compara::MemberSet');
    if (UNIVERSAL::isa($set, 'Bio::EnsEMBL::Compara::AlignedMemberSet')) {
        return $self->db->get_AlignedMemberAdaptor->fetch_all_by_AlignedMemberSet($set);
    } elsif (UNIVERSAL::isa($set, 'Bio::EnsEMBL::Compara::Domain')) {
        return $self->fetch_all_by_Domain($set);
    } else {
        throw("$self is not a recognized MemberSet object\n");
    }
}



=head2 fetch_all_by_subset_id

  Arg [1]    : int subset_id
  Example    : @members = @{$memberAdaptor->fetch_all_by_subset_id($subset_id)};
  Description: given a subset_id, does a join to the subset_member table
               to return a list of Member objects in this subset
  Returntype : list by reference of Compara::Member objects
  Exceptions :
  Caller     : general

=cut

sub fetch_all_by_subset_id {
  my ($self, $subset_id) = @_;

  throw() unless (defined $subset_id);

  my $constraint = "sm.subset_id = '$subset_id'";

  my $join = [[['subset_member', 'sm'], 'm.member_id = sm.member_id']];

  return $self->generic_fetch($constraint, $join);
}


=head2 fetch_all_peptides_for_gene_member_id

  Arg [1]    : int member_id of a gene member
  Example    : @pepMembers = @{$memberAdaptor->fetch_all_peptides_for_gene_member_id($gene_member_id)};
  Description: given a member_id of a gene member,
               fetches all peptide members for this gene
  Returntype : array ref of Bio::EnsEMBL::Compara::Member objects
  Exceptions :
  Caller     : general

=cut

sub fetch_all_peptides_for_gene_member_id {
  my ($self, $gene_member_id) = @_;

  throw() unless (defined $gene_member_id);

    $self->bind_param_generic_fetch($gene_member_id, SQL_INTEGER);
    return $self->generic_fetch('m.gene_member_id = ?');
}


=head2 fetch_canonical_member_for_gene_member_id

  Arg [1]    : int member_id of a gene member
  Example    : $members = $memberAdaptor->fetch_canonical_member_for_gene_member_id($gene_member_id);
  Description: given a member_id of a gene member,
               fetches the canonical peptide / transcript member for this gene
  Returntype : Bio::EnsEMBL::Compara::Member object
  Exceptions :
  Caller     : general

=cut

sub fetch_canonical_member_for_gene_member_id {
    my ($self, $gene_member_id) = @_;

    throw() unless (defined $gene_member_id);

    my $constraint = 'mg.member_id = ?';
    my $join = [[['member', 'mg'], 'm.member_id = mg.canonical_member_id']];

    $self->bind_param_generic_fetch($gene_member_id, SQL_INTEGER);
    return $self->generic_fetch_one($constraint, $join);
}



#
# INTERNAL METHODS
#
###################

sub _tables {
  return (['member', 'm']);
}

sub _columns {
  return ('m.member_id',
          'm.source_name',
          'm.stable_id',
          'm.version',
          'm.taxon_id',
          'm.genome_db_id',
          'm.description',
          'm.chr_name',
          'm.chr_start',
          'm.chr_end',
          'm.chr_strand',
          'm.sequence_id',
          'm.gene_member_id',
          'm.display_label'
          );
}

sub create_instance_from_rowhash {
	my ($self, $rowhash) = @_;
	
	return Bio::EnsEMBL::Compara::Member->new_fast({
		_adaptor        => $self,                   # field name NOT in sync with Bio::EnsEMBL::Storable
		_dbID           => $rowhash->{member_id},   # field name NOT in sync with Bio::EnsEMBL::Storable
		_stable_id      => $rowhash->{stable_id},
		_version        => $rowhash->{version},
		_taxon_id       => $rowhash->{taxon_id},
		_genome_db_id   => $rowhash->{genome_db_id},
		_description    => $rowhash->{description},
		_chr_name       => $rowhash->{chr_name},
		_chr_start      => $rowhash->{chr_start},
		_chr_end        => $rowhash->{chr_end},
		_chr_strand     => $rowhash->{chr_strand},
		_sequence_id    => $rowhash->{sequence_id} || 0,
		_source_name    => $rowhash->{source_name},
		_display_label  => $rowhash->{display_label},
		_gene_member_id => $rowhash->{gene_member_id},
	});
}

sub init_instance_from_rowhash {
  my $self = shift;
  my $member = shift;
  my $rowhash = shift;

  $member->member_id($rowhash->{'member_id'});
  $member->stable_id($rowhash->{'stable_id'});
  $member->version($rowhash->{'version'});
  $member->taxon_id($rowhash->{'taxon_id'});
  $member->genome_db_id($rowhash->{'genome_db_id'});
  $member->description($rowhash->{'description'});
  $member->chr_name($rowhash->{'chr_name'});
  $member->chr_start($rowhash->{'chr_start'});
  $member->chr_end($rowhash->{'chr_end'});
  $member->chr_strand($rowhash->{'chr_strand'});
  $member->sequence_id($rowhash->{'sequence_id'});
  $member->gene_member_id($rowhash->{'gene_member_id'});
  $member->source_name($rowhash->{'source_name'});
  $member->display_label($rowhash->{'display_label'});
  $member->adaptor($self);

  return $member;
}

sub _objs_from_sth {
  my ($self, $sth) = @_;

  my @members = ();

  while(my $rowhash = $sth->fetchrow_hashref) {
    my $member = $self->create_instance_from_rowhash($rowhash);
    
    my @_columns = $self->_columns;
    if (scalar keys %{$rowhash} > scalar @_columns) {
      if (exists $rowhash->{domain_id}) {
        bless $member, 'Bio::EnsEMBL::Compara::MemberDomain';
        $member->member_start($rowhash->{member_start});
        $member->member_end($rowhash->{member_end});
      }
    }
    push @members, $member;
  }
  $sth->finish;
  return \@members
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
  my ($self,$member) = @_;

  unless($member->isa('Bio::EnsEMBL::Compara::Member')) {
    throw(
      "member arg must be a [Bio::EnsEMBL::Compara::Member]"
    . "not a $member");
  }

  my $sth = $self->prepare("INSERT ignore INTO member (stable_id,version, source_name,
                              gene_member_id,
                              taxon_id, genome_db_id, description,
                              chr_name, chr_start, chr_end, chr_strand,display_label)
                            VALUES (?,?,?,?,?,?,?,?,?,?,?,?)");

  my $insertCount = $sth->execute($member->stable_id,
                  $member->version,
                  $member->source_name,
                  $member->gene_member_id,
                  $member->taxon_id,
                  $member->genome_db_id,
                  $member->description,
                  $member->chr_name,
                  $member->chr_start,
                  $member->chr_end,
                  $member->chr_strand,
                  $member->display_label);
  if($insertCount>0) {
    #sucessful insert
    $member->dbID( $sth->{'mysql_insertid'} );
    $sth->finish;
  } else {
    $sth->finish;
    #UNIQUE(source_name,stable_id) prevented insert since member was already inserted
    #so get member_id with select
    my $sth2 = $self->prepare("SELECT member_id, sequence_id FROM member WHERE source_name=? and stable_id=?");
    $sth2->execute($member->source_name, $member->stable_id);
    my($id, $sequence_id) = $sth2->fetchrow_array();
    warn("MemberAdaptor: insert failed, but member_id select failed too") unless($id);
    $member->dbID($id);
    $member->sequence_id($sequence_id) if ($sequence_id);
    $sth2->finish;
  }

  $member->adaptor($self);

  # insert in sequence table to generate new
  # sequence_id to insert into member table;
  if(defined($member->sequence) and $member->sequence_id == 0) {
    $member->sequence_id($self->db->get_SequenceAdaptor->store($member->sequence,1)); # Last parameter induces a check for redundancy

    my $sth3 = $self->prepare("UPDATE member SET sequence_id=? WHERE member_id=?");
    $sth3->execute($member->sequence_id, $member->dbID);
    $sth3->finish;
  }

  return $member->dbID;
}



sub update_sequence {
  my ($self, $member) = @_;

  return 0 unless($member);
  unless($member->dbID) {
    throw("MemberAdapter::update_sequence member must have valid dbID\n");
  }
  unless(defined($member->sequence)) {
    warning("MemberAdapter::update_sequence with undefined sequence\n");
  }

  if($member->sequence_id) {
    my $sth = $self->prepare("UPDATE sequence SET sequence = ?, length=? WHERE sequence_id = ?");
    $sth->execute($member->sequence, $member->seq_length, $member->sequence_id);
    $sth->finish;
  } else {
    $member->sequence_id($self->db->get_SequenceAdaptor->store($member->sequence,1)); # Last parameter induces a check for redundancy

    my $sth3 = $self->prepare("UPDATE member SET sequence_id=? WHERE member_id=?");
    $sth3->execute($member->sequence_id, $member->dbID);
    $sth3->finish;
  }
  return 1;
}

sub _set_member_as_canonical {
    my ($self, $peptide_member) = @_;

    my $sth = $self->prepare('UPDATE member SET canonical_member_id = ? WHERE member_id = ?');
    $sth->execute($peptide_member->member_id, $peptide_member->gene_member_id);
    $sth->finish;
}


1;


package Bio::EnsEMBL::Compara::BaseRelation;

use strict;
use Bio::EnsEMBL::Root;

our @ISA = qw(Bio::EnsEMBL::Root);

sub new {
  my ($class, @args) = @_;
  my $self = $class->SUPER::new(@args);

  if (scalar @args) {
    #do this explicitly.
    my ($dbid, $stable_id, $description, $source_id, $source_name, $adaptor) = $self->_rearrange([qw(DBID STABLE_ID DESCRIPTION SOURCE_ID SOURCE_NAME ADAPTOR)], @args);
    
    $dbid && $self->dbID($dbid);
    $stable_id && $self->stable_id($stable_id);
    $description && $self->description($description);
    $source_id && $self->source_id($source_id);
    $source_name && $self->source_id($source_name);
    $adaptor && $self->adaptor($adaptor);
  }
  
  return $self;
}   

=head2 new_fast

  Arg [1]    : hash reference $hashref
  Example    : none
  Description: This is an ultra fast constructor which requires knowledge of
               the objects internals to be used.
  Returntype : 
  Exceptions : none
  Caller     : 

=cut

sub new_fast {
  my ($class, $hashref) = @_;

  return bless $hashref, $class;
}

=head2 dbID

  Arg [1]    : int $dbID (optional)
  Example    : 
  Description: 
  Returntype : 
  Exceptions : 
  Caller     : 

=cut

sub dbID {
  my $self = shift;
  $self->{'_dbID'} = shift if(@_);
  return $self->{'_dbID'};
}

=head2 stable_id

  Arg [1]    : string $stable_id (optional)
  Example    : 
  Description: 
  Returntype : 
  Exceptions : 
  Caller     : 

=cut

sub stable_id {
  my $self = shift;
  $self->{'_stable_id'} = shift if(@_);
  return $self->{'_stable_id'};
}

=head2 description

  Arg [1]    : string $description (optional)
  Example    : 
  Description: 
  Returntype : string
  Exceptions : 
  Caller     : 

=cut

sub description {
  my $self = shift;
  $self->{'_description'} = shift if(@_);
  return $self->{'_description'};
}

=head2 description_score

  Arg [1]    : int $score (optional)
  Example    : 
  Description: get/set the description_score of the Family. This a
               measure of how good the cluster is (scale 0-100)
  Returntype : 
  Exceptions : 
  Caller     : 

=cut

=head2 source_id

=cut

sub source_id {
  my $self = shift;
  $self->{'_source_id'} = shift if (@_);
  return $self->{'_source_id'};
}

=head2 source_name

=cut

sub source_name {
  my $self = shift;
  $self->{'_source_name'} = shift if (@_);
  return $self->{'_source_name'};
}

=head2 adaptor

  Arg [1]    : string $adaptor (optional)
               corresponding to a perl module
  Example    : 
  Description: 
  Returntype : 
  Exceptions : 
  Caller     : 

=cut

sub adaptor {
  my $self = shift;
  $self->{'_adaptor'} = shift if(@_);
  return $self->{'_adaptor'};
}

sub add_Relation {
  my ($self, $relation_attribute) = @_;

  my ($relation, $attribute) = @{$relation_attribute};

  if ($relation->isa('Bio::EnsEMBL::Compara::Member')) {

    $self->isa('Bio::EnsEMBL::Compara::Member') &&
      $self->throw("You can't add a Member to a Member");
    push @{$self->{'_member_array'}}, $relation_attribute ;
    push @{$self->{'_members_by_source'}{$relation->source_name}}, $relation_attribute;
    push @{$self->{'_members_by_source_taxon'}{$relation->source_name."_".$relation->taxon_id}}, $relation_attribute;

  } elsif ($relation->isa('Bio::EnsEMBL::Compara::Family')) {

    $self->isa('Bio::EnsEMBL::Compara::Family') &&
      $self->throw("You can't add a Family to a Family");
    push @{$self->{'_family_array'}}, $relation_attribute;
    push @{$self->{'_family_by_source'}{$relation->source_name}}, $relation_attribute;

  } elsif ($relation->isa('Bio::EnsEMBL::Compara::Domain')) {

    $self->isa('Bio::EnsEMBL::Compara::Domain') &&
      $self->throw("You can't add a Domain to a Domain");
    push @{$self->{'_domain_array'}}, $relation_attribute;
    push @{$self->{'_domain_by_source'}{$relation->source_name}}, $relation_attribute;

  } elsif ($relation->isa('Bio::EnsEMBL::Compara::Homology')) {
   
    $self->isa('Bio::EnsEMBL::Compara::Homology') &&
      $self->throw("You can't add a Homology to a Homology");

    push @{$self->{'_homology_array'}}, $relation_attribute;
    push @{$self->{'_homology_by_source'}{$relation->source_name}}, $relation_attribute;
  }
}

=head2 get_all_Member

  Arg [1]    : None
  Example    : 
  Description: 
  Returntype : array reference of Bio::EnsEMBL::Compara::Member
  Exceptions : 
  Caller     : 

=cut

sub get_all_Member {
  my ($self) = @_;
  
  unless (defined $self->{'_member_array'}) {

    my $MemberAdaptor = $self->adaptor->db->get_MemberAdaptor();
    my $members = $MemberAdaptor->fetch_by_relation($self);

    $self->{'_member_array'} = [];
    $self->{'_members_by_source'} = {};
    $self->{'_members_by_source_taxon'} = {};
    foreach my $member_attribute (@{$members}) {
      $self->add_Relation($member_attribute);
    }
  }
  return $self->{'_member_array'}; #should return also attributes
}

=head2 get_Member_by_source

  Arg [1]    : string $source_name
               e.g. "ENSEMBLPEP"
  Example    : 
  Description: 
  Returntype : array reference of Bio::EnsEMBL::Compara::Member
  Exceptions : 
  Caller     : 

=cut

sub get_Member_by_source {
  my ($self, $source_name) = @_;

  $self->throw("Should give defined source_name as arguments\n") unless (defined $source_name);

  unless (defined $self->{'_members_by_source'}->{$source_name}) {
    my $MemberAdaptor = $self->adaptor->db->get_MemberAdaptor();
    my $members = $MemberAdaptor->fetch_by_relation_source($self,$source_name);

    $self->{'_members_by_source'}->{$source_name} = [];
    push @{$self->{'_members_by_source'}->{$source_name}}, @{$members};
  }
  return $self->{'_members_by_source'}->{$source_name};
}

=head2 get_Member_by_source_taxon

  Arg [1]    : string $source_name
  Arg [2]    : int $taxon_id
  Example    : $domain->get_Member_by_source_taxon('ENSEMBLPEP',9606)
  Description: 
  Returntype : array reference of Bio::EnsEMBL::Compara::Member
  Exceptions : 
  Caller     :

=cut

sub get_Member_by_source_taxon {
  my ($self, $source_name, $taxon_id) = @_;

  $self->throw("Should give defined source_name and taxon_id as arguments\n") unless (defined $source_name && defined $taxon_id);

  unless (defined $self->{'_members_by_source_taxon'}->{$source_name."_".$taxon_id}) {
    my $MemberAdaptor = $self->adaptor->db->get_MemberAdaptor();
    my $members = $MemberAdaptor->fetch_by_relation_source_taxon($self,$source_name,$taxon_id);

    $self->{'_members_by_source_taxon'}->{$source_name."_".$taxon_id} = [];
    push @{$self->{'_members_by_source_taxon'}->{$source_name."_".$taxon_id}}, @{$members};
  }
  return $self->{'_members_by_source_taxon'}->{$source_name."_".$taxon_id};
}

=head2 Member_count

  Arg [1]    : None
  Example    : 
  Description: 
  Returntype : int
  Exceptions : 
  Caller     : 

=cut

sub Member_count {
  my ($self) = @_; 
  
  # we do not want to have a total number of gene+peptide members
  # That is why we substracte from the total those corresponding to genes
  # Need to be fixed as ENSEMBLGENE is here hard coded
  # Probably by just adding a colunm type in source, which would be gene, peptide, or
  # even transcript. Then recode Member_count as Member_count_by_type or something like that.
  # Member_count_by_type('peptide'),...

  return scalar @{$self->get_all_Member} - $self->Member_count_by_source('ENSEMBLGENE');
}

=head2 Member_count_by_source

  Arg [1]    : string $source_name
               e.g. "ENSEMBLPEP"
  Example    : $domain->Member_count_by_source('ENSEMBLPEP');
  Description: 
  Returntype : int
  Exceptions : 
  Caller     : 

=cut

sub Member_count_by_source {
  my ($self, $source_name) = @_; 
  
  $self->throw("Should give a defined source_name as argument\n") unless (defined $source_name);
  
  return scalar @{$self->get_Member_by_source($source_name)};
}

=head2 Member_count_by_source_taxon

  Arg [1]    : string $source_name
  Arg [2]    : int $taxon_id
  Example    : Member_count_by_source_taxon('ENSEMBLPEP',9606);
  Description: 
  Returntype : int
  Exceptions : 
  Caller     : 

=cut

sub Member_count_by_source_taxon {
  my ($self, $source_name, $taxon_id) = @_; 
  
  $self->throw("Should give defined source_name and taxon_id as arguments\n") unless (defined $source_name && defined $taxon_id);

  return scalar @{$self->get_Member_by_source_taxon($source_name,$taxon_id)};
}

=head2 get_Taxon_by_source

  Arg [1]    : string $source_name
  Example    : $domain->get_Taxon_by_source('ENSEMBLGENE')
  Description: 
  Returntype : array reference of Bio::EnsEMBL::Compara::Taxon
  Exceptions : 
  Caller     : 

=cut

sub get_Taxon_by_source {
  my ($self, $source_name) = @_;
  $self->throw("Should give defined source_name as argument\n") unless (defined $source_name);
  return $self->adaptor->fetch_Taxon_by_source_dbID($source_name,$self->dbID);
}


=head2 known_sources

 Args       : none
 Example    : $FamilyAdaptor->known_sources
 Description: get all database name, source of the family members
 Returntype : an array reference of string
 Exceptions : none
 Caller     : general

=cut

sub known_sources {
  my ($self) = @_;
  
  unless (defined $self->{_known_sources}) {
      $self->{'_known_sources'} = $self->adaptor->_known_sources;
  }
  return $self->{'_known_sources'};
}


=head2 get_families

=cut

sub get_all_families {
  my $self = shift;

  #if not cached, retrieve all of the families for this member
  if (!defined $self->{'_family_array'} && $self->adaptor) {
    $self->{'_family_array'} = 
      $self->adaptor->db->get_FamilyAdaptor->fetch_by_Relation($self);
  }

  $self->{'_family_array'} ||= [];

  return $self->{'_family_array'};
}

=head2 get_all_domains

=cut

sub get_all_domains {
  my $self = shift;

  #if not cached, retrieve all of the domains for this member
  if (!defined $self->{'_domain_array'} && $self->adaptor) {
    $self->{'_domain_array'} =
      $self->adaptor->db->get_DomainAdaptor->fetch_by_relation($self);
  }

  $self->{'_domain_array'} ||= [];

  return $self->{'_domain_array'};
}


1;

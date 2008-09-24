
#
# Ensembl module for Bio::EnsEMBL::Compara::SitewiseOmega
#
# Cared for by Albert Vilella <avilella@ebi.ac.uk>
#
# Copyright Albert Vilella
#
# You may distribute this module under the same terms as perl itself

# POD documentation - main docs before the code

=head1 NAME

Bio::EnsEMBL::Compara::SitewiseOmega - DESCRIPTION of Object

=head1 SYNOPSIS

Give standard usage here

=head1 DESCRIPTION

Describe the object here

=head1 AUTHOR - Albert Vilella

This modules is part of the Ensembl project http://www.ensembl.org

Email avilella@ebi.ac.uk

Describe contact details here

=head1 APPENDIX

The rest of the documentation details each of the object methods. Internal methods are usually preceded with a _

=cut


# Let the code begin...


package Bio::EnsEMBL::Compara::SitewiseOmega;

use strict;

use Bio::EnsEMBL::Utils::Argument qw(rearrange);
use Bio::EnsEMBL::Utils::Exception qw(warning deprecate throw);

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

=head2 member_position

  Arg [1]    : Bio::EnsEMBL::Member $member
  Arg [2]    : Bio::SimpleAlign $aln
  Example    : $sitewise_omega->member_position($member,$aln);
  Description: Obtain the member position for a given sitewise_omega value
  Returntype : integer
  Exceptions : return undef if member not in the alignment or aln_position not in member
  Caller     : general
  Status     : At risk

=cut

sub member_position {
  my ($self, $member, $aln) = @_;

  throw("$member is not a Bio::EnsEMBL::Compara::Member object")
    unless ($member->isa("Bio::EnsEMBL::Compara::Member"));

  throw("$aln is not a Bio::SimpleAlign object")
    unless ($aln->isa("Bio::SimpleAlign"));

  my @seqs = $aln->each_seq_with_id($member->stable_id);
  my $seq = $seqs[0];

  my $seq_location;
  eval { $seq_location = $seq->location_from_column($self->aln_position);};
  return undef if ($@);
  my $location_type;
  eval { $location_type = $seq_location->location_type;};
  return undef if ($@);
  if ($seq_location->location_type eq 'EXACT') {
    my $member_position = $seq_location->start;
    return $member_position;
  }

  return undef;
}

=head2 adaptor

  Arg [1]    : Bio::EnsEMBL::DBSQL::SitewiseOmegaAdaptor $adaptor
  Example    : $sitewise_omega->adaptor($adaptor);
  Description: Getter/Setter for the adaptor this object used for database
               interaction
  Returntype : Bio::EnsEMBL::DBSQL::SitewiseOmegaAdaptor object
  Exceptions : thrown if the argument is not a
               Bio::EnsEMBL::DBSQL::SitewiseOmegaAdaptor object
  Caller     : general
  Status     : At risk

=cut

sub adaptor {
  my ( $self, $adaptor ) = @_;

  if (defined($adaptor)) {
    throw("$adaptor is not a Bio::EnsEMBL::Compara::DBSQL::SitewiseOmegaAdaptor object")
        unless ($adaptor->isa("Bio::EnsEMBL::Compara::DBSQL::SitewiseOmegaAdaptor"));
    $self->{'adaptor'} = $adaptor;
  }

  return $self->{'adaptor'};
}

=head2 aln_position

  Arg [1]    : (opt) integer
  Example    : $sitewise_dnds->aln_position(1);
  Description: Getter/Setter for the alignment position
  Returntype : integer. Return 1 if value not defined
  Exceptions : none
  Caller     : general
  Status     : At risk

=cut

sub aln_position {
    my ($self, $aln_position) = @_;

    if(defined $aln_position) {
	$self->{'aln_position'} = $aln_position;
    }

  $self->{'aln_position'}= undef unless(defined($self->{'aln_position'}));
  return $self->{'aln_position'};
}


=head2 omega

  Arg [1]    : (opt) integer
  Example    : $sitewise_dnds->omega(1);
  Description: Getter/Setter for the omega value
  Returntype : integer. Return 1 if value not defined
  Exceptions : none
  Caller     : general
  Status     : At risk

=cut

sub omega {
    my ($self, $omega) = @_;

    if(defined $omega) {
	$self->{'omega'} = $omega;
    }

  $self->{'omega'}= undef unless(defined($self->{'omega'}));
  return $self->{'omega'};
}


=head2 omega_lower

  Arg [1]    : (opt) float
  Example    : $sitewise_dnds->omega_lower(1);
  Description: Getter/Setter for the omega_lower value
  Returntype : float. Return 1 if value not defined
  Exceptions : none
  Caller     : general
  Status     : At risk

=cut

sub omega_lower {
    my ($self, $omega_lower) = @_;

    if(defined $omega_lower) {
	$self->{'omega_lower'} = $omega_lower;
    }

  $self->{'omega_lower'}= undef unless(defined($self->{'omega_lower'}));
  return $self->{'omega_lower'};
}


=head2 omega_upper

  Arg [1]    : (opt) float
  Example    : $sitewise_dnds->omega_upper(1);
  Description: Getter/Setter for the omega_upper value
  Returntype : float. Return 1 if value not defined
  Exceptions : none
  Caller     : general
  Status     : At risk

=cut

sub omega_upper {
    my ($self, $omega_upper) = @_;

    if(defined $omega_upper) {
	$self->{'omega_upper'} = $omega_upper;
    }

  $self->{'omega_upper'}= undef unless(defined($self->{'omega_upper'}));
  return $self->{'omega_upper'};
}


=head2 optimal

  Arg [1]    : (opt) float
  Example    : $sitewise_dnds->optimal(1);
  Description: Getter/Setter for the optimal value
  Returntype : float. Return 1 if value not defined
  Exceptions : none
  Caller     : general
  Status     : At risk

=cut

sub optimal {
    my ($self, $optimal) = @_;

    if(defined $optimal) {
	$self->{'optimal'} = $optimal;
    }

  $self->{'optimal'}= undef unless(defined($self->{'optimal'}));
  return $self->{'optimal'};
}


=head2 threshold_on_branch_ds

  Arg [1]    : (opt) float
  Example    : $sitewise_dnds->threshold_on_branch_ds(1);
  Description: Getter/Setter for the threshold_on_branch_ds value
  Returntype : float. Return 1 if value not defined
  Exceptions : none
  Caller     : general
  Status     : At risk

=cut

sub threshold_on_branch_ds {
    my ($self, $threshold_on_branch_ds) = @_;

    if(defined $threshold_on_branch_ds) {
	$self->{'threshold_on_branch_ds'} = $threshold_on_branch_ds;
    }

  $self->{'threshold_on_branch_ds'}= undef unless(defined($self->{'threshold_on_branch_ds'}));
  return $self->{'threshold_on_branch_ds'};
}

=head2 type

  Arg [1]    : (opt) integer
  Example    : $sitewise_dnds->type(1);
  Description: Getter/Setter for the type value
  Returntype : integer. Return 1 if value not defined
  Exceptions : none
  Caller     : general
  Status     : At risk

=cut

sub type {
    my ($self, $type) = @_;

    if(defined $type) {
	$self->{'type'} = $type;
    }

  $self->{'type'}= undef unless(defined($self->{'type'}));
  return $self->{'type'};
}


=head2 node_id

  Arg [1]    : (opt) integer
  Example    : $sitewise_dnds->node_id(1);
  Description: Getter/Setter for the node_id value
  Returnnode_id : integer. Return 1 if value not defined
  Exceptions : none
  Caller     : general
  Status     : At risk

=cut

sub node_id {
    my ($self, $node_id) = @_;

    if(defined $node_id) {
	$self->{'node_id'} = $node_id;
    }

  $self->{'node_id'}= undef unless(defined($self->{'node_id'}));
  return $self->{'node_id'};
}

=head2 tree_node_id

  Arg [1]    : (opt) integer
  Example    : $sitewise_dnds->tree_node_id(1);
  Description: Getter/Setter for the tree_node_id value
  Returntree_node_id : integer. Return 1 if value not defined
  Exceptions : none
  Caller     : general
  Status     : At risk

=cut

sub tree_node_id {
    my ($self, $tree_node_id) = @_;

    if(defined $tree_node_id) {
	$self->{'tree_node_id'} = $tree_node_id;
    }

  $self->{'tree_node_id'}= undef unless(defined($self->{'tree_node_id'}));
  return $self->{'tree_node_id'};
}


sub dbID {
    my ($self, $dbID) = @_;

    if(defined $dbID) {
	$self->{'_dbID'} = $dbID;
    }

  $self->{'_dbID'}= undef unless(defined($self->{'_dbID'}));
  return $self->{'_dbID'};
}




1;

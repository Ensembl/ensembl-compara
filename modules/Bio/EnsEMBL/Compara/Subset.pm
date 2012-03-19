# $Id$
#
# Module to handle family members
#
# Cared for by Abel Ureta-Vidal <abel@ebi.ac.uk>
#
# Copyright Abel Ureta-Vidal
#
# You may distribute this module under the same terms as perl itself

# POD documentation - main docs before the code

=head1 NAME

Subset - DESCRIPTION of Object

=head1 SYNOPSIS

=head1 DESCRIPTION

=head1 CONTACT

 Jessica Severin <jessica@ebi.ac.uk>

=head1 APPENDIX

The rest of the documentation details each of the object methods. Internal methods are usually preceded with a _

=cut

package Bio::EnsEMBL::Compara::Subset;

use strict;
use Bio::Species;
use Bio::EnsEMBL::Utils::Exception;
use Bio::EnsEMBL::Utils::Argument;

use Data::Dumper;

sub new {
  my ($class, @args) = @_;
  my $self = {};

  bless $self,$class;

  if (scalar @args) {
    #do this explicitly.
    my ($dbid, $description, $adaptor) = rearrange([qw(DBID NAME ADAPTOR)], @args);

    $self->dbID($dbid)               if($dbid);
    $self->description($description) if($description);
    $self->adaptor($adaptor)         if($adaptor);

    $self->{'_member_id_list'} = [];
    $self->{'_cached_member_list'} = [];
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

=head2 adaptor

 Title   : adaptor
 Usage   :
 Function: give the adaptor if known
 Example :
 Returns :
 Args    :


=cut

sub adaptor {
   my ($self, $value) = @_;

   if (defined $value) {
      $self->{'_adaptor'} = $value;
   }

   return $self->{'_adaptor'};
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

=head2 dump_loc

  Arg [1]    : string $dump_loc (optional)
  Example    :
  Description:
  Returntype : string
  Exceptions :
  Caller     :

=cut

sub dump_loc {
  my $self = shift;
  $self->{'_dump_loc'} = shift if(@_);
  return $self->{'_dump_loc'};
}

=head2 add_member_id

  Arg [1]     : $member_id
  Example     : my $count = $subset->add_member_id($member_id);
  Description : Add a new member_id to the subset object and
                returns the number of member_ids already in the object
  Returntype  : A scalar with the number of member_ids in the object
  Exceptions  :
  Caller      :

=cut

sub add_member_id {
  my $self = shift;
  my $count=0;

  if(@_) {
    my $member_id = shift;
    $count = push @{$self->{'_member_id_list'}}, $member_id;
    #print("added $count element to list\n");

    if(defined($self->adaptor)) {
      $self->adaptor->store_link($self, $member_id);
    }
  }
  return $count
}


=head2 add_member

  Arg [1]      : A Bio::EnsEMBL::Compara::Member
  Example      : my $count = $subset->add_member($member);
  Description  : Add a new Bio::EnsEMBL::Compara::Member to the subset object
                 and returns the number of members already in the object
  ReturnType   : A scalar with the number of members in the object
  Exceptions   :
  Caller       :

=cut

sub add_member {
  my ($self, $member) = @_;

  unless(defined($member) and $member->isa('Bio::EnsEMBL::Compara::Member')) {
    throw(
    "gene arg must be a [Bio::EnsEMBL::Compara::Member] ".
    "not a [$member]");
  }

  my $count = $self->add_member_id($member->dbID);

  push @{$self->{'_cached_member_list'}}, $member;

  return $count;
}

sub member_id_list {
  my $self = shift;

  return $self->{'_member_id_list'};
}

=head2 member_list

  Arg [1]    : 
  Example    :
  Description:
  Returntype : reference to array of Bio::EnsEMBL::Compara::Member objects
  Exceptions :
  Caller     :

=cut
sub member_list {
  my $self = shift;

  return $self->{'_cached_member_list'};
}

sub count {
  my $self = shift;

  return $#{$self->member_id_list()} + 1;
  #return $#{$self->member_list()} + 1;

  #my @idList = @{$self->member_id_list()};
  #my $count = $#idList;
  #return $count;
}


sub output_to_fasta {
  my ($self, $fastaPath, $prefix) = @_;

  if(defined($fastaPath)) {
    if($fastaPath ne "stdout") {
      open FASTA_FP,">$fastaPath";
    } else {
      open FASTA_FP,">-";
    }
  }

  foreach my $member (@{member_list()}) {

    my $seq_string = $member->sequence;
    $seq_string =~ s/(.{72})/$1\n/g;
    
    print FASTA_FP ">$prefix" .
        $member->stable_id . " " .
        $member->description . "\n" .
        $seq_string . "\n";
  }

  close(FASTA_FP);
}

1;

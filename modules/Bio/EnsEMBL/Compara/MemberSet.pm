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

MemberSet - DESCRIPTION of Object

=head1 SYNOPSIS

=head1 DESCRIPTION

=head1 CONTACT

 Jessica Severin <jessica@ebi.ac.uk>

=head1 APPENDIX

The rest of the documentation details each of the object methods. Internal methods are usually preceded with a _

=cut

package Bio::EnsEMBL::Compara::MemberSet;

use strict;
use Bio::Species;

our @ISA = qw(Bio::EnsEMBL::Root);

sub new {
  my ($class, @args) = @_;
  my $self = $class->SUPER::new(@args);

  if (scalar @args) {
    #do this explicitly.
    my ($dbid, $name, $adaptor) = $self->_rearrange([qw(DBID NAME ADAPTOR)], @args);

    $dbid && $self->dbID($dbid);
    $name && $self->name($name);
    $self->{'_member_id_list'} = ();
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

=head2 name

  Arg [1]    : string $name (optional)
  Example    :
  Description:
  Returntype : string
  Exceptions :
  Caller     :

=cut

sub name {
  my $self = shift;
  $self->{'_name'} = shift if(@_);
  return $self->{'_name'};
}

=head2 add_member_id

  Arg [1]    : $member_id
  Example    :
  Description:
  Returntype :
  Exceptions :
  Caller     :

=cut

sub add_member_id {
  my $self = shift;

  if(@_) {
    my $member_id = shift;
    my @idList = $self->{'_member_id_list'};
    push @idList, $member_id;
    $self->{'_member_id_list'} = @idList;
    #$self->{'_member_id_list'} .= " " . $member_id;;
    #$self->{'_member_id_list'} .= " " . $member_id;
  }
  return;
}

sub add_member {
  my ($self, $member) = @_;

  unless(defined($member) and $member->isa('Bio::EnsEMBL::Compara::Member')) {
    $self->throw(
    "gene arg must be a [Bio::EnsEMBL::Compara::Member] ".
    "not a [$member]");
  }

  return add_member_id($member->dbID);
}

=head2 member_id_list

  Arg [1]    : 
  Example    :
  Description:
  Returntype : list of strings
  Exceptions :
  Caller     :

=cut

sub member_id_list {
  my $self = shift;
  my @idList = ();

  #@idList = split(/\s/, $self->{'_member_id_list'});
  #return @idList;
  return $self->{'_member_id_list'};
}

sub count {
  my $self = shift;

  my $count = @{$self->member_id_list};
  return $count;
}

1;

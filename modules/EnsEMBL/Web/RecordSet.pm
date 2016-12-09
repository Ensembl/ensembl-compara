=head1 LICENSE

Copyright [1999-2016] Wellcome Trust Sanger Institute and the EMBL-European Bioinformatics Institute

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

package EnsEMBL::Web::RecordSet;

### Object representation of set of session/user/group records
### Wrapper around the record rose object(s)

use strict;
use warnings;

use overload qw(bool count);

use EnsEMBL::Web::Exceptions qw(ORMException WebException);

our $AUTOLOAD;

sub new {
  ## @constructor
  ## @params List of all the record rose objects
  my $class = shift;
     $class = ref $class || $class;

  return bless \@_, $class;
}

sub save {
  ## Saves all the records in the set
  my ($self, $args) = @_;

  my $count = 0;

  $args = {'changes_only' => 1, %{$args || {}}};

  try {
    $count = scalar grep { $_->data($_->data); $_->save(%$args); } @$self; # data is set again to make sure it's considered by 'changes_only' argument
  } catch {
    throw ORMException($_->message(1));
  };

  return $count;
}

sub delete {
  ## Deletes all the records in the set
  ## @note This should only be called via RecordManager->delete_records. If not, then RecordManager->has_changes(1) should be
  ##       called after calling this, otherwise the it may not commit the MySQL transaction.
  my ($self, $args) = @_;

  return 0 unless $self->count;

  return scalar grep { $_->delete(%$args) } @$self;
}

sub filter {
  ## Filters the records in the set according to the subroutine provided
  ## @param Callback to filter the records ($_ gets assigned as a record when iterating through all records)
  ## @params List of arguments to be passed to the callback
  ## @return A new instance of the RecordSet with filtered records
  my ($self, $callback) = splice @_, 0, 2;

  return $self->new(grep $callback->(@_), @$self);
}

sub get {
  ## Gets the nth record of the set
  ## @param Position of record in the set array
  ## @return A new instance of RecordSet with a record at nth position record only (possibly empty is nth record doesn't exist)
  my ($self, $pos) = @_;
  return $self->new($self->[$pos] || ());
}

sub first {
  ## Gets the first record of the set
  ## @return A new instance of RecordSet with first record only
  return shift->get(0);
}

sub last {
  ## Gets the last record of the set
  ## @return A new instance of RecordSet with last record only
  return shift->get(-1);
}

sub count {
  ## Counts the number of records in the set
  return scalar @{$_[0]};
}

sub add {
  ## Adds new record(s) to the set
  ## @params List of Rose Record or RecordSet objects
  ## @return RecordSet of newly added records
  my $self = shift;

  my $records = $self->new(map { $_->isa(ref $self) ? @$_ : $_ } @_);

  push @$self, @$records;

  return $records;
}

sub can {
  ## @override UNIVERSAL's can to implement AUTOLOAD
  my ($self, $method) = @_;

  my $coderef = $self->SUPER::can($method);

  return $coderef if $coderef;

  return unless $self->[0] && $self->[0]->can($method);

  return sub {
    my $self = shift;
    return $self->[0]->can($method)->($self->[0], @_);
  }
}

sub AUTOLOAD {
  ## Falls back to calling the corresponding method on the first record object inside the set
  my $self    = shift;
  my $method  = $AUTOLOAD =~ s/.*:://r;
  my $coderef = $self->can($method);

  throw WebException(sprintf 'Could not call method "%s" on "%s"', $method, ref $self) unless $coderef;

  return $coderef->($self, @_);
}

sub DESTROY {}

1;

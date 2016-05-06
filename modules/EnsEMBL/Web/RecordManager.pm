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

package EnsEMBL::Web::RecordManager;

### Abstract class to serve as a parent to EnsEMBL::Web::Session and EnsEMBL::Web::User that have access to records

use strict;
use warnings;

use EnsEMBL::Web::Attributes;
use EnsEMBL::Web::RecordSet;
use EnsEMBL::Web::Exceptions qw(WebException ORMException);

sub hub :Getter;

sub new {
  ## @constructor
  ## @param Hub
  my ($class, $hub) = @_;

  my $self = bless { 'hub' => $hub }, $class;

  $self->init;

  return $self;
}

sub init :Abstract;
  ## @abstract
  ## Initialise the object (called by new method after blessing the object)

sub rose_manager :Abstract;
  ## @abstract
  ## @return The package name of the rose manager to access the records

sub record_type :Abstract;
  ## @abstract
  ## @return Type of the owner of the record eg. user or session or group (value for record_type column  in record table)

sub record_type_id :Abstract;
  ## @abstract
  ## @return id of the session/user against which the records are saved (value for record_type_id column  in record table)

sub records {
  ## Gets all the records for the given filter
  ## @param String type, or hasref with keys to filter all session records or subroutine callback to be passed to 'grep' for all records
  ## @params (Optional) Any arguments for filter callback
  ## @return EnsEMBL::Web::RecordSet object
  my ($self, $filter) = splice @_, 0, 2;

  # load records on demand
  $self->{'_record_set'} ||= EnsEMBL::Web::RecordSet->new(@{$self->rose_manager->get_objects({'query' => ['record_type_id' => $self->record_type_id, 'record_type' => $self->record_type]})});

  # return all records if no filter applied
  return $self->{'_record_set'} unless $filter;

  # if filter is a callback itself
  return $self->{'_record_set'}->filter($filter, @_) if ref $filter && ref $filter eq 'CODE';

  # create a callback
  my $filter_callback = sub {
    my ($record, $column_filter, $is_column) = @_;
    for (keys %$column_filter) {
      return unless $column_filter->{$_} eq ($is_column->{$_} ? $record->$_ : $record->data->{$_}); # skip record for any mismatch
    }
    return 1;
  }

  $filter = { 'type' => $filter } unless ref $filter; # if filter is a string, it's type of the record

  return $self->{'_record_set'}->filter($filter_callback, $filter, { map { $_ => 1 } @{$self->_record_column_names} });
}

sub record {
  ## Gets the first record for the given filter
  ## @params Filter arguments, same as records method
  ## @return EnsEMBL::Web::RecordSet object with one or no record object in it
  my $self = shift;

  return $self->records(@_)->first;
}

sub get_record_data {
  ## Gets the record and converts it into as a hash
  ## @params Filter arguments, same as records method
  ## @return Hashref (possibly empty)
  my $self    = shift;
  my $record  = $self->record(@_);
  my $data    = {};

  if ($record->count) {
    $data = $record->data->raw;

    for (@{$self->_record_column_names}) {
      $data->{$_} = $record->$_;
    }
  }

  return $data;
}

sub set_record_data {
  ## Adds (or replaces) a record to the current record set (does not permanently save it to the db - call store to finally to make it permanent)
  ## @param Hashref with key-value as columns or data keys as keys and their corresponding values as values
  ## @note An existing record is replaced if record_type_id is provided or there's a record that already exists with given non-null `type` and `code`
  my ($self, $data) = @_;

  my $row = {};
  my $record;

  for (@{$self->_record_column_names}) {
    $row->{$_} = delete $data->{$_} if exists $data->{$_};
  }

  $row->{'data'}            = $data;
  $row->{'record_type'}     = $self->record_type;
  $row->{'record_type_id'}  = $self->record_type_id;

  # if record id is provided, the record HAS TO BE there among the record set
  if (my $record_id = delete $row->{'record_id'}) {
    $record = $self->record({'record_id' => $record_id});

    throw WebException('Record (' + $self->record_type + ') with id ' + $record_id + ' does not exist.') unless $record->count;
  }

  # if type and code is provided, the record may or may not exist among the record set
  if (!$record && $row->{'type'} && $row->{'code'}) {
    $record = $self->record({'type' => $row->{'type'}, 'code' => $row->{'code'}});
  }

  # if new record needs to be added
  if (!$record || !$record->count) {
    $record = $self->records->add($self->rose_manager->create_empty_object({}));
  }

  # update column values
  $record->$_($row->{$_}) for keys %$row;

  return $record->save;
}

sub store {
  ## Does a final commit to db for all the changes
  my $self = shift;

  $self->_commit_transaction;
}

sub _record_column_names {
  ## @private
  ## save column names from the rose db meta object
  my $self = shift;
  $self->{'_record_column_names'} ||= $self->rose_manager->object_class->meta->column_names;
}

sub _begin_transaction {
  ## @private
  ## Begins a mysql transaction
  my $self = shift;

  if (!$self->{'_db'}) { # if $self->{'_db'} exists, we have already started transaction
    $self->{'_db'} = $self->rose_manager->object_class->init_db;
    $self->{'_db'}->begin_work or throw ORMException($self->{'_db'}->error);
  }
}

sub _commit_transaction {
  ## @private
  ## Commits a mysql transaction
  my ($self, $no_exception) = @_;

  if ($self->{'_db'}) {
    if (!$self->{'_db'}->commit) {
      throw ORMException($self->{'_db'}->error) unless $no_exception;
      return 0;
    }
    delete $self->{'_db'};
  }
}

sub DESTROY {
  # just rollback if no changes were stored permanently
  $_[0]->{'_db'}->rollback if $_[0]->{'_db'};
}

1;

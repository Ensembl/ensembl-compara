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

sub hub :Accessor;

sub new {
  ## @constructor
  ## @param Hub
  my $class = shift;
  my $hub   = shift;

  my $self = bless { 'hub' => $hub }, $class;

  $self->init(@_); # pass any extra arguments to init

  return $self;
}

sub init :Abstract;
  ## @abstract
  ## Initialise the object (called by new method after blessing the object)

sub record_rose_manager :Abstract;
  ## @abstract
  ## @return The package name of the rose manager to access the records

sub record_type :Abstract;
  ## @abstract
  ## @return Type of the owner of the record eg. user or session or group (value for record_type column  in record table)

sub record_type_id :Abstract;
  ## @abstract
  ## @return id of the session/user against which the records are saved (value for record_type_id column  in record table)

sub has_changes :AccessorMutator;
  ## @param Flag passed as true if some changes have been made to records
  ## @return Flag if true means changes have been made to the records

sub records {
  ## Gets all the records for the given filter
  ## @param String type, or hasref with keys to filter all session records or subroutine callback to be passed to 'grep' for all records
  ## @params (Optional) Any arguments for filter callback
  ## @return EnsEMBL::Web::RecordSet object
  my ($self, $filter) = splice @_, 0, 2;

  # load records on demand
  $self->{'_record_set'} //= $self->_recordset_class->new(@{$self->record_rose_manager->get_objects('query' => ['record_type_id' => $self->record_type_id, 'record_type' => $self->record_type])});

  # return all records if no filter applied
  return $self->{'_record_set'} unless $filter;

  # if filter is a callback itself
  return $self->{'_record_set'}->filter($filter, @_) if ref $filter && ref $filter eq 'CODE';

  # if filter is a string, it's type of the record
  $filter = { 'type' => $filter } unless ref $filter;

  # query records according to the hashref query
  return $self->_query_records($filter);
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

  return $record->count ? $self->_get_record_data($record) : {};
}

sub set_record_data {
  ## Adds (or replaces) a record to the current record set (does not permanently save it to the db - call store to finally to make it permanent)
  ## @param Hashref with key-value as columns or data keys as keys and their corresponding values as values
  ## @note An existing record is replaced if record_type_id is provided or there's a record that already exists with given non-null `type` and `code`
  ## @note An existing record is deleted if 'data' key is null or is an empty hash
  my ($self, $data) = @_;

  my $row = {};
  my $record;

  for (@{$self->_record_column_names}) {
    $row->{$_} = delete $data->{$_} if exists $data->{$_};
  }

  $row->{'data'}            = $data;
  $row->{'record_type'}     = $self->record_type;
  $row->{'record_type_id'}  = $self->record_type_id;
  $row->{'modified_at'}     = 'now';

  # if record id is provided, the record HAS TO BE there among the record set
  if (my $record_id = delete $row->{'record_id'}) {
    $record = $self->record({'record_id' => $record_id});

    throw WebException('Record ('.$self->record_type.') with id '.$record_id.' does not exist.') unless $record->count;
  }

  # if type and code is provided, the record may or may not exist among the record set
  if (!$record && $row->{'type'} && $row->{'code'}) {
    $record = $self->record({'type' => $row->{'type'}, 'code' => $row->{'code'}});
  }

  # if an existing record needes to be removed
  if (!$data || !keys %$data) {
    return $record ? $self->delete_records($record) : 1;
  }

  # if new record needs to be added
  if (!$record) {
    $record = $self->records->add($self->record_rose_manager->create_empty_object({'created_at' => 'now'}));
  }

  # update column values
  $record->$_($row->{$_}) for keys %$row;

  # type and code are required
  throw WebException(q(Record can not be created without 'type' and 'code'.)) unless $record->type && $record->code;

  $self->has_changes(1);

  return $self->_save_record($record) ? $self->_get_record_data($record) : {};
}

sub get_records_data {
  ## Gets the records and converts them into hashes
  ## @params Filter arguments, same as records method
  ## @return List of Hashrefs
  my $self = shift;

  return map $self->_get_record_data($_), @{$self->records(@_)};
}

sub add_record {
  ## Adds a new record to the current RecordSet
  ## @param Columns and their values as a hash (or type string)
  my ($self, $row) = @_;

  $row                      = {'type' => $row} unless ref $row;
  $row                    ||= {};
  $row->{'data'}          ||= {};
  $row->{'record_type'}     = $self->record_type;
  $row->{'record_type_id'}  = $self->record_type_id;
  $row->{'modified_at'}     = 'now';
  $row->{'created_at'}      = 'now';

  return $self->records->add($self->record_rose_manager->create_empty_object($row));
}

sub delete_records {
  ## Deletes records according to the filtering arguments
  ## @param RecordSet object or filter params as excepted by the records method
  my $self      = shift;
  my $to_delete = ref $_[0] && UNIVERSAL::isa($_[0], __PACKAGE__->_recordset_class) ? $_[0] : $self->records(@_);

  return 0 unless $to_delete->count;

  # remove the records from current record_set
  $self->{'_record_set'} = $self->records(sub { return !$_[0]->{$_->record_id}; }, { map { $_->record_id => 1 } @$to_delete });

  # delete the records from db
  $self->has_changes(1);
  return $to_delete->delete;
}

sub store_records {
  ## Does a final commit to db for all the changes
  ## @param Force - if true will made commit changes even if has_changes flag is false
  my ($self, $force) = @_;

  $self->_commit_transaction if $force || $self->has_changes;
}

sub _get_record_data {
  ## @private
  ## Converts a record to a hash by using columns as keys and combining key from 'data' column
  my ($self, $record) = @_;

  my $data = $record->data->raw;
  $data->{$_} = $record->$_ for @{$self->_record_column_names};

  return $data;
}

sub _save_record {
  ## @private
  ## Saves a record
  my ($self, $record, $args) = @_;

  return $record->save($args);
}

sub _record_column_names {
  ## @private
  ## Gets column names from the rose db meta object
  my $self = shift;
  $self->{'_record_column_names'} ||= [ grep $_ ne 'data', $self->record_rose_manager->object_class->meta->column_names ];
}

sub _query_records {
  ## @private
  ## Tries to create functionality as offered by 'query' parameter of Rose::DB::Object::QueryBuilder::build_select but with limited operator (OP) support
  my ($self, $query) = @_;

  my $filter_callback = sub {
    my $record  = $_;
    my $data    = $record->data;
    my ($column_filter, $column_hash) = @_;

    foreach my $key (keys %$column_filter) {
      my $value     = $column_filter->{$key};
      my $reverse   = $key =~ s/^\!// ? 1 : 0;
      my $cmp_value = ($column_hash->{$key} ? $record->$key : $data->{$key}) // '';
      my $match     = $reverse;

      if (defined $value && $value ne '') {
        if (ref $value) {
          if (ref $value eq 'HASH') {
            # TODO
          }
          if (ref $value eq 'ARRAY') {
            $match = grep { $cmp_value eq $_ } @$value;
          }
        } else { # $value is a string
          $match = $value eq $cmp_value;
        }
      } else { # $value is undef or empty string
        $match = $cmp_value eq '';
      }

      return 0 if $match xor !$reverse;
    }

    return 1;
  };

  return $self->{'_record_set'}->filter($filter_callback, $query, { map { $_ => 1 } @{$self->_record_column_names} });
}

sub _begin_transaction {
  ## @private
  ## Begins a mysql transaction
  my $self = shift;

  if (!$self->{'_db'}) { # if $self->{'_db'} exists, we have already started transaction
    $self->{'_db'} = $self->record_rose_manager->object_class->init_db;
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

sub _recordset_class {
  ## @private
  return 'EnsEMBL::Web::RecordSet';
}

sub DESTROY {
  # just rollback if no changes were stored permanently
  warn sprintf "%s: Data not saved - doing a rollback on transaction\n", ref $_[0];
  $_[0]->{'_db'}->rollback if $_[0]->{'_db'};
}

sub store :Deprecated('use store_records') { shift->store_records(@_) }

1;

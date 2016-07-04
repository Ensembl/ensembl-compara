=head1 LICENSE

Copyright [1999-2015] Wellcome Trust Sanger Institute and the EMBL-European Bioinformatics Institute
Copyright [2016] EMBL-European Bioinformatics Institute

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

package EnsEMBL::Web::CDBI;

### NAME: EnsEMBL::Web::CDBI
### Base class for ORM objects based on Class::DBI::Sweet  

### STATUS: At Risk
### We are in the process of replacing Class::DBI-based domain objects
### with Rose::DB objects - once all such objects have been migrated, 
### this module will be removed.

use strict;
use warnings;
no warnings 'uninitialized';

use base qw(EnsEMBL::Web::DBSQL::MySQLAdaptor);

use EnsEMBL::Web::Cache;
use Data::Dumper;


#----------------------------------------------------------------------
# Our Class Data
#----------------------------------------------------------------------
__PACKAGE__->mk_classdata(data_fields       => {});
__PACKAGE__->mk_classdata(queriable_fields  => {});
__PACKAGE__->mk_classdata(relations         => {});
__PACKAGE__->mk_classdata(hasa_relations    => {});
__PACKAGE__->mk_classdata(hasmany_relations => {});
__PACKAGE__->mk_classdata(tie_relations     => {});
__PACKAGE__->mk_classdata(cache_tags        => {});
__PACKAGE__->mk_classdata('_type');



##
## Fix for add_trigger, so that same triggers wont be added twice
##
sub add_trigger{
  my $proto = shift;
  my @args  = @_;
  my $when  = $args[0];
  my $call  = $args[1];
  
  $proto->SUPER::add_trigger(@args)
    unless grep { $call eq $_->[0] } Class::Trigger::__fetch_all_triggers($proto, $when);
}


##
## Enhancement for our MySQLAdaptor (Class::DBI), which doesn't have new constructor by default
## arguments:
## LIST of primery keys - will be looked up in DB
## OR!
## HASHREF of values for new object
##
sub new {
  my $class = shift; 
  my $data  = shift;

## Sometimes data comes throuh as a empty string..
## convert this back to undef other wise 
## _live_object_key fails as can't work with an
## empty string - requires "undef"

  $data = undef if $data eq '';
  if( $data && !ref($data) ) {
    if ($class->_type) {
      my $key = $class->get_primary_key;
      return $class->retrieve(
        $key => $data,
        type => $class->_type,
      );
    } else {
      return $class->retrieve($data);
    }
  } else {
    $class->normalize_column_values($data) if ref $data;
    $class->validate_column_values($data)  if ref $data;
    my $key   = $class->_live_object_key($data);
    return $class->_fresh_init($key => $data);  	
  }
}

sub save {
  my $self = shift;

  if ($self->id) {
    $self->update(@_);
  } else {
    $self->insert_blessed(@_);
  }
}

##
## Fix for insert, to work with new() and save()
##
sub insert_blessed {
	my $self = shift;
  
	$self->call_trigger('before_create');
	$self->call_trigger('deflate_for_create');

	$self->_prepopulate_id if $self->_undefined_primary;

	# Reinstate data
	my ($real, $temp) = ({}, {});
	foreach my $col (grep $self->_attribute_exists($_), $self->all_columns) {
		($self->has_real_column($col) ? $real : $temp)->{$col} =
			$self->_attrs($col);
	}

	$self->_insert_row($real);

	my @primary_columns = $self->primary_columns;
	$self->_attribute_store(
		$primary_columns[0] => $real->{ $primary_columns[0] }
  )
    if @primary_columns == 1;

	delete $self->{__Changed};

	my %primary_columns;
	@primary_columns{@primary_columns} = ();
	my @discard_columns = grep !exists $primary_columns{$_}, keys %$real;
	$self->call_trigger('create', discard_columns => \@discard_columns);   # XXX

	# Empty everything back out again!
	$self->_attribute_delete(@discard_columns);
	$self->call_trigger('after_create');
	return $self;
}
##/Class::DBI enhancements


sub set_primary_key {
  my $class = shift;
  $class->columns(Primary => @_);
}
*set_primary_keys = \&set_primary_key;

sub get_primary_key {
  my $class = shift;
  my @keys = $class->columns(Primary => @_);
  return wantarray ? @keys : $keys[0];
}


sub add_fields {
  my $class = shift;

  $class->add_queriable_field(data => 'data');
  $class->data_fields({
    %{ $class->data_fields },
    @_,
  });
  
  $class->columns(TEMP => keys %{ $class->data_fields });

  $class->add_trigger(select        => \&withdraw_data);
  $class->add_trigger(before_create => \&fertilize_data);
  $class->add_trigger(before_update => \&fertilize_data);
}


sub add_queriable_fields {
  my $class = shift;
  $class->queriable_fields({
    %{ $class->queriable_fields },
    @_,
  });
  
  $class->columns(Essential => keys %{ $class->queriable_fields });
}
*add_queriable_field = \&add_queriable_fields;


sub get_all_fields {
  my $class = shift;

  return {
  %{ $class->data_fields },
  %{ $class->queriable_fields },
  };
}


###################################################################################################
##
## Record serialized data stuff
##
###################################################################################################

sub withdraw_data {
  my $self = shift;
  my $data = $self->data;
  $data =~ s/^\$data = //;
  $data =~ s!\+'!'!g;
  ##$data =~ s/\n|\r|\f|\\//g;
  $data = eval ($data);
  foreach my $field (keys %{ $self->data_fields }) {
    $self->$field($data->{$field})
      if $self->can($field) && ref $data;
  }

  $self->_attribute_store(data => $data);
  
  return $data;
}


sub fertilize_data {
  my $self = shift;
  my $data = $self->data || {};

  return unless ref $data;

  foreach my $field (keys %{ $self->data_fields }) {
    $data->{$field} = $self->$field;
  }
  
  $self->_attribute_set(data => $self->dump_data($data));
}


sub dump_data {
  my $self = shift;
  my $data = shift;
  
  my $temp_fields = {};
  foreach my $key (keys %{ $data }) {
    $temp_fields->{$key} = $data->{$key};
    ##$temp_fields->{$key} =~ s/'/\\'/g;
  }
  my $dumper = Data::Dumper->new([$temp_fields]);
  $dumper->Indent(0);
  $dumper->Maxdepth(0);
  
  my $dump = $dumper->Dump();
  #$dump =~ s/'/\\'/g;
  $dump =~ s/^\$VAR1 = //;
  return $dump;
}



###################################################################################################
##
## Owner/record related stuff
##
###################################################################################################

sub get_lookup_values {
  ## Method for getting a standard set of identifying data 
  ## for dropdown lists and similar usage
  ## Needs to be defined in children
  return [];
}

sub add_hasa_relations {
  my $class = shift;
  $class->hasa_relations({
    %{ $class->hasa_relations },
    @_,
  });
}
sub add_hasmany_relations {
  my $class = shift;
  $class->hasmany_relations({
    %{ $class->hasmany_relations },
    @_,
  });
}
sub add_tie_relations {
  my $class = shift;
  $class->tie_relations({
    %{ $class->tie_relations },
    @_,
  });
}
*add_hasa_relation = \&add_hasa_relations;
*add_hasmany_relation = \&add_hasmany_relations;
*add_tie_relation = \&add_tie_relations;

sub has_a {
  my $class    = shift;
  my $accessor = shift;
  my ($relation_class) = @_;
  
  $accessor .= '_id';
  
  $class->add_hasa_relation($accessor => $relation_class);
  $class->add_queriable_fields($accessor => 'int');

  return $class->SUPER::has_a($accessor => @_);
}


sub add_has_many {
  my $class = shift;
  my %args  = @_;
  while (my ($key, $value) = each %args) {
    $class->has_many($key => $value);
  }
}


sub has_many {
  my $class    = shift;
  my $accessor = shift;
  my ($relation_class) = @_;
  no strict 'refs';

  if (ref($relation_class)) {
    return $class->SUPER::has_many($accessor => @_);
  } else {

    $class->_require_class($relation_class);
  
    $class->relations({
      %{ $class->relations },
      $accessor => $relation_class,
    });
  
    my $real_accessor = '_'. $accessor;
    $class->SUPER::has_many($real_accessor => $relation_class);
 
    my $link_table = $relation_class->new;
    $class->add_hasmany_relation($accessor => [$relation_class, $link_table->tie_relations->{$accessor}]);
 
    *{$class."::$accessor"} =
      sub {
        my $self = shift;
  
        ## Retrieve by primary field ...(id => $id) // short version
        $_[0] = $relation_class->get_primary_key if @_ == 2 && $_[0] eq 'id';
  
        ## Retrieve by primary field ...($id) // shorter version
        unshift @_, $relation_class->get_primary_key if @_ == 1 && !ref($_[0]);
  
        return $self->$real_accessor(
          @_,
          #type => $relation_class->__type,
        );
      };
  
    *{$class."::add_to_$accessor"} =
      sub {
        my $self = shift;
        my $args = ref $_[0] ? shift : {@_};
        
        ## Force hash ref, in case if blessed hash was passed (or die)
        my %args = %{ $args };
        die "add_to_$accessor needs data" unless %args;
  
        my $add_to_real_accessor = 'add_to_' . $real_accessor;
        return $self->$add_to_real_accessor(\%args);
      };
  
  }

}

sub set_type {
  my $class = shift;
  my $type  = shift;
  no strict 'refs';
  
  *{$class."::search"}       = sub { shift->SUPER::search(type => $type, @_) };
  *{$class."::retrieve"}     = sub { shift->SUPER::retrieve(type => $type, @_) };
  *{$class."::retrieve_all"} = sub { shift->search(@_) };

  $class->_type($type);
  $class->add_queriable_fields(type => 'string');
  $class->add_trigger(before_create => sub { my $self = shift; $self->type($self->_type) });
}

## 
## Like has_a, but imports all relative properties into our object
## so they both represented together as one entity
##
sub tie_a {
  my $class = shift;
  my ($rel_obj, $rel_class) = @_;
  $class->add_tie_relation($rel_obj => $rel_class);
  no strict 'refs';
  
  $class->has_a(@_);
  $class->add_trigger( after_update => sub { shift->$rel_obj->update } );
  foreach my $column (keys %{ $rel_class->get_all_fields }) {
    *{$class."::$column"} = sub { shift->$rel_obj->$column(@_) }
      unless $class->find_column($column);
  }
}



###################################################################################################
##
## Cache related stuff
##
###################################################################################################

## Set caching object
## Any cache object that has a get, set, and remove method is supported
if (my $cache = EnsEMBL::Web::Cache->new) {
  __PACKAGE__->add_trigger(select =>        sub { $_[0]->propagate_cache_tags     } );
  __PACKAGE__->add_trigger(after_create  => sub { $_[0]->invalidate_cache($cache) } );
  __PACKAGE__->add_trigger(after_update  => sub { $_[0]->invalidate_cache($cache) } );
  __PACKAGE__->add_trigger(before_delete => sub { $_[0]->invalidate_cache($cache) } );

  ## ->search must propogate tags
  sub search {
    my $proto = shift;
    $proto->propagate_cache_tags;
    $proto->SUPER::search(@_);
  }
  
  ## Some calls use direct sql query so
  ## ->sth_to_objects must propogate tags
  sub sth_to_objects {  
    my $proto = shift;
    $proto->propagate_cache_tags;
    $proto->SUPER::sth_to_objects(@_);
  }
}

sub invalidate_cache {
  my $self  = shift;
  my $cache = shift;
  return $cache->delete_by_tags(@_, $self->table);
}

sub propagate_cache_tags {
  my $self  = shift;
  $ENV{'CACHE_TAGS'}{$_} = $_ for @_, $self->table;
}

###################################################################################################
##
## Some other nice stuff
##
###################################################################################################

sub find_all { shift->retrieve_all(@_) }
sub find     { shift->retrieve(@_) }
sub destroy  { shift->delete(@_) }

1;

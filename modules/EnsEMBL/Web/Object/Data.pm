package EnsEMBL::Web::Object::Data;

use strict;
use warnings;

use Class::Std;
use EnsEMBL::Web::DBSQL::SQL::Result;
use EnsEMBL::Web::DBSQL::SQL::Request;
use EnsEMBL::Web::Object::DataField;
use EnsEMBL::Web::Root;

{

my %Fields :ATTR(:set<fields> :get<fields>);
my %Primary_key :ATTR(:set<primary_key> :get<primary_key>);
my %Data_field :ATTR(:set<data_field_name> :get<data_field_name>);
my %Value :ATTR(:set<values>, :get<values>);
my %Queriable_Fields :ATTR(:set<queriable_fields> :get<queriable_fields>);
my %Adaptor :ATTR(:set<adaptor> :get<adaptor>);
my %Belongs_to :ATTR(:set<belongs_to> :get<belongs_to>);
my %Relational_attributes :ATTR(:set<relational_attributes> :get<relational_attributes>);
my %Relational_table :ATTR(:set<relational_table> :get<relational_table>);
my %Relational_fields :ATTR(:set<relational_fields> :get<relational_fields>);
my %Relational_link_table :ATTR(:set<relational_link_table> :get<relational_link_table>);
my %Relational_contribution :ATTR(:set<relational_contribution> :get<relational_contribution>);
my %Has_many:ATTR(:set<has_many> :get<has_many>);

}

sub BUILD {
  my ($self, $ident, $args) = @_;
  $self->add_queriable_field({ name => 'id', type => 'int' });
  $self->add_queriable_field({ name => 'created_at', type => 'datetime' });
  $self->add_queriable_field({ name => 'modified_at', type => 'datetime' });
  $self->add_queriable_field({ name => 'modified_by', type => 'int' });
  $self->add_queriable_field({ name => 'created_by', type => 'int' });
}

sub populate_with_arguments {
  my ($self, $args) = @_;
  if (defined $args->{id}) {
    $self->populate($args->{id});
  }
}

sub populate {
  my ($self, $id) = @_;
  $self->id($id);
  my $result = $self->get_adaptor->find($self);
  foreach my $key (@{ $result->fields }) {
    my $field = $self->mapped_field($key);
    if ($self->get_data_field_name && ($field eq $self->get_data_field_name)) {
      $self->populate_data($result->get_value($key));
    } else {
      $self->$field($result->get_value($key));
    }
  }
}

sub populate_data {
  ### Populates data.
  my ($self, $string) = @_;
  #warn "Populating data for: " . ref($self);
  my $hash = eval ($string);
  foreach my $key (keys %{ $hash }) {
    $self->$key($hash->{$key});
  }
}

sub mapped_field {
  my ($self, $field) = @_;
  if ($field eq $self->get_primary_key) {
    $field = 'id';
  }
  return $field;
}

sub records {
  my ($self) = @_;
  my @records = ();
  foreach my $key (keys %{ $self->get_relational_attributes }) {
    push @records, @{ $self->$key }; 
  }
  return \@records;
}

sub get_value {
  my ($self, $name) = @_;
  return $self->get_values->{$name};
}

sub set_value {
  my ($self, $name, $value) = @_;
  if (!defined $self->get_values) {
    $self->set_values({});
  }
  $self->get_values->{$name} = $value;
}

sub add_field {
  my ($self, $args) = @_;
  if (!$self->get_fields) {
    $self->set_fields([]);
  }
  $self->add_accessor_symbol_lookup($args->{name});
  push @{ $self->get_fields }, EnsEMBL::Web::Object::DataField->new( { name => $args->{name}, type => $args->{type} } );
}

sub add_queriable_field {
  my ($self, $args) = @_;
  if (!$self->get_queriable_fields) {
    $self->set_queriable_fields([]);
  }
  $self->add_accessor_symbol_lookup($args->{name});
  push @{ $self->get_queriable_fields }, EnsEMBL::Web::Object::DataField->new( { name => $args->{name}, type => $args->{type}, queriable => 'yes' } );
}

sub add_relational_field {
  my ($self, $args) = @_;
  if (!$self->get_relational_fields) {
    $self->set_relational_fields([]);
  }
  $self->add_accessor_symbol_lookup($args->{name});
  push @{ $self->get_relational_fields }, EnsEMBL::Web::Object::DataField->new( { name => $args->{name}, type => $args->{type} } );
}

sub get_all_fields {
  my $self = shift;
  my @all_fields;

  ## Check we actually have fields of each type before trying to dereference the arrayref!
  if (ref($self->get_fields) eq 'ARRAY') {
    push @all_fields, @{ $self->get_fields };
  }
  if (ref($self->get_queriable_fields) eq 'ARRAY') {
    push @all_fields, @{ $self->get_queriable_fields };
  }
  return \@all_fields;
}

sub add_has_many {
  my ($self, $args) = @_;
  if (!$self->get_has_many) {
    $self->set_has_many([]);
  }
  $self->relational_class($self->plural($self->object_name_from_package($args->{class})), $args->{class});
  $self->relational_table($self->plural($self->object_name_from_package($args->{class})), $args->{table});
  if ($args->{link_table}) {
    $self->add_linked_has_many_symbol_lookup($self->plural($self->object_name_from_package($args->{class})));
    $self->relational_link_table($self->plural($self->object_name_from_package($args->{class})), $args->{link_table});
    ## relational contributions allow the parent class to bestoy additional attributes on child classes. This
    ## data is usually stored in a link table. For example, this mechanism is used to add an authorisation 'level'
    ## to users retrived from a group, via the group_member table.
    if ($args->{contribute}) {
      $self->relational_contribution($args->{link_table}, $args->{contribute});
    }
  } else {
    $self->add_has_many_symbol_lookup($self->plural($self->object_name_from_package($args->{class})));
  }
  push @{ $self->get_has_many }, $args->{class};
}


sub add_belongs_to {
  my ($self, $arg) = @_;
  if (!$self->get_belongs_to ) {
    $self->set_belongs_to([]);
  }
  $self->relational_class($self->object_name_from_package($arg), $arg);
  $self->add_relational_symbol_lookup($self->object_name_from_package($arg));
  $self->add_queriable_field({ name => $self->object_name_from_package($arg) . "_id", type => 'int', queriable => 'yes' });
  push @{ $self->get_belongs_to }, $arg;
}

sub add_accessor_symbol_lookup {
  my ($self, $name) = @_;
  no strict;
  my $class = ref($self);
  $self->set_value({ $name => "" });
   
  unless (defined *{ "$class\::$name" }) {
    *{ "$class\::$name" } = $self->initialize_accessor($name);
  }
}

sub initialize_accessor {
  no strict;
  my ($self, $attribute) = @_;
  return sub {
    my $self = shift;
    my $new_value = shift;
    if (defined $new_value) {
      $self->set_value($attribute,  $new_value);
    }
    return $self->get_value($attribute);
  };
}

sub add_lazy_accessor_symbol_lookup {
  my ($self, $name) = @_;
  no strict;
  my $class = ref($self);
  $self->set_value({ $name => undef });
   
  unless (defined *{ "$class\::$name" }) {
    *{ "$class\::$name" } = $self->initialize_relational_accessor($name);
  }
}

sub initialize_relational_accessor {
  no strict;
  my ($self, $attribute) = @_;
  #warn "Adding relational accessor: " . $attribute;
  return sub {
    my $self = shift;
    my $new_value = shift;
    if (defined $new_value) {
      $self->set_value($attribute,  $new_value);
    }
    return $self->get_lazy_value($attribute);
  };
}

sub add_has_many_symbol_lookup {
  my ($self, $name) = @_;
  no strict;
  my $class = ref($self);
  $self->set_value({ $name => undef });
   
  unless (defined *{ "$class\::$name" }) {
    *{ "$class\::$name" } = $self->initialize_has_many_accessor($name);
  }
}

sub initialize_has_many_accessor {
  no strict;
  my ($self, $attribute) = @_;
  #warn "Adding HAS MANY accessor: " . $attribute;
  return sub {
    my $self = shift;
    my $new_value = shift;
    if (defined $new_value) {
      $self->set_value($attribute,  $new_value);
    }
    return $self->get_lazy_values($attribute);
  };
}

sub add_linked_has_many_symbol_lookup {
  my ($self, $name) = @_;
  no strict;
  my $class = ref($self);
  $self->set_value({ $name => undef });
   
  unless (defined *{ "$class\::$name" }) {
    *{ "$class\::$name" } = $self->initialize_linked_has_many_accessor($name);
  }
}

sub initialize_linked_has_many_accessor {
  no strict;
  my ($self, $attribute) = @_;
  #warn "Adding MANY TO MANY accessor: " . $attribute;
  return sub {
    my $self = shift;
    my $new_value = shift;
    if (defined $new_value) {
      $self->set_value($attribute,  $new_value);
    }
    return $self->get_linked_values($attribute);
  };
}

sub get_linked_values {
  my ($self, $attribute) = @_;
  my $class = $self->relational_class($attribute);
  my $accessor = $self->object_name_from_package($class) . "_id";
  #warn "Finding MANY $attribute via link table: " . $class;
  my $result = $self->find_linked_many($attribute);
  my @objects = ();
  if (EnsEMBL::Web::Root::dynamic_use(undef, $class)) {
    foreach my $id (keys %{ $result->get_result_hash }) {
      my $new = $class->new({ id => $id });
      if ($self->relational_contribution($self->relational_link_table($attribute))) {
        foreach my $contrib (@{ $self->relational_contribution($self->relational_link_table($attribute)) }) {
          $new->$contrib($result->get_result_hash->{$id}->{$contrib});
        }
      }
      push @objects, $new;
    }
  }
  return \@objects;
}

sub get_lazy_value {
  my ($self, $attribute) = @_;
  #warn "GETTING LAZY VALUE: " . $attribute;
  my $class = $self->relational_class($attribute);
  my $accessor = $self->object_name_from_package($class) . "_id";
  my $object = $self->object_name_from_package($class);
  if (defined $self->get_value($object)) {
    return $self->get_value($object);
  }
  #warn "Creating new $attribute with class " . $class . " and " . $accessor;
  if (EnsEMBL::Web::Root::dynamic_use(undef, $class)) {
    my $new = $class->new({ id => $self->$accessor });
    $self->set_value($object, $new);
    return $new;
  }
  return undef;
}

sub get_lazy_values {
  my ($self, $attribute) = @_;
  my $class = $self->relational_class($attribute);
  my $accessor = $self->object_name_from_package($class) . "_id";
  my $object = $self->object_name_from_package($class);
  if (defined $self->get_value($object)) {
    return $self->get_value($object);
  }
  #warn "Creating MANY new $attribute with class " . $class;
  my $result = $self->find_many($attribute);
  my @objects = ();
  if (EnsEMBL::Web::Root::dynamic_use(undef, $class)) {
    foreach my $id (keys %{ $result->get_result_hash }) {  
      my $new = $class->new({ id => $id });
      push @objects, $new;
    }
    $self->set_value($object, \@objects);
  }
  return \@objects;
}

sub relational_contribution {
  my ($self, $attribute, $contribution) = @_;
  unless (defined $self->get_relational_contribution) {
    $self->set_relational_contribution({});
  }
  if (defined $contribution) {
    $self->get_relational_contribution->{$attribute} = $contribution; 
  }
  return $self->get_relational_contribution->{$attribute};
}

sub relational_class {
  my ($self, $attribute, $class) = @_;
  unless (defined $self->get_relational_attributes) {
    $self->set_relational_attributes({});
  }
  if (defined $class) {
    $self->get_relational_attributes->{$attribute} = $class; 
  }
  return $self->get_relational_attributes->{$attribute};
}

sub relational_table {
  my ($self, $attribute, $table) = @_;
  unless (defined $self->get_relational_table) {
    $self->set_relational_table({});
  }
  if (defined $table) {
    $self->get_relational_table->{$attribute} = $table; 
  }
  return $self->get_relational_table->{$attribute};
}

sub relational_link_table {
  my ($self, $attribute, $table) = @_;
  unless (defined $self->get_relational_link_table) {
    $self->set_relational_link_table({});
  }
  if (defined $table) {
    $self->get_relational_link_table->{$attribute} = $table; 
  }
  return $self->get_relational_link_table->{$attribute};
}

sub add_relational_symbol_lookup {
  my ($self, $name) = @_;
  no strict;
  my $class = ref($self);
  
  ## Add method to populate the relational data object from the 
  ## database if an ID is specified.
  ## eg: $data->user_id('66');
  ##     $user = $data->user();
  $self->add_accessor_symbol_lookup($name . "_id");

  ## Add methods to get and set the relational data object.
  ## eg: $data->user($user)
  $self->add_lazy_accessor_symbol_lookup($name);
}

sub has_id {
  my ($self) = @_;
  if ($self->get_value('id')) {
    return 1;
  }
  return 0;
}

# DB methods

sub save {
  my $self = shift;
  my $result = $self->get_adaptor->save($self);
  if ($result->get_action eq 'create') {
    $self->id($result->get_last_inserted_id);
  }
  return $result->get_success;
}

sub destroy {
  my $self = shift;
  my $request = EnsEMBL::Web::DBSQL::SQL::Request->new();
  $request->set_action('destroy');
  $request->add_where($self->get_primary_key, $self->id);
  $request->set_index_by('user_record_id');
  my $result = $self->get_adaptor->destroy($request);
  return $result->get_success;
}

sub find_many {
  my ($self, $attribute) = @_;
  my $request = EnsEMBL::Web::DBSQL::SQL::Request->new();
  $request->set_action('select');
  $request->set_table($self->relational_table($attribute));
  $request->add_where('type', $self->singular($attribute));
  $request->add_where($self->get_primary_key, $self->id);
  $request->set_index_by($self->relational_table($attribute) . "_id");
  #warn "INDEX BY: " . $request->get_index_by;
  #warn $request->get_sql;
  return $self->get_adaptor->find_many($request);
}

sub find_linked_many {
  my ($self, $attribute) = @_;
  my $request = EnsEMBL::Web::DBSQL::SQL::Request->new();
  $request->set_action('select');
  $request->set_table($self->relational_link_table($attribute));
  if ($self->relational_contribution($self->relational_link_table($attribute))) {
    foreach my $contribution (@{ $self->relational_contribution($self->relational_link_table($attribute)) }) {
      $request->add_select($self->relational_link_table($attribute) . "." . $contribution);
    }
  }
  $request->add_select($self->relational_table($attribute) . '.*');
  $request->add_join($self->relational_table($attribute), $self->relational_link_table($attribute) . "." . $self->relational_table($attribute) . "_id", $self->relational_table($attribute) . "." . $self->relational_table($attribute) . "_id");
  $request->add_where($self->relational_link_table($attribute) . "." . $self->get_primary_key, $self->id);
  $request->set_index_by($self->relational_table($attribute) . "_id");
  #warn "LINKED SQL: " . $request->get_sql;
  return $self->get_adaptor->find_many($request);
}

# Util methods

sub object_name_from_package {
  my ($self, $name) = @_;
  my @components = split /::/, $name;
  return lc($components[$#components]);
}

sub plural {
  ### Returns the plural form of a word. 
  ### Note: this is not a definitive lexical modification!
  ### Extended this method with more complex rules if it doesn't
  ### return what you expected.

  my ($self, $word) = @_;
  my $plural = $word;
  my $found = 0;

  ## Words ending in ws - skip
  if (!$found && $word =~ /ws$/) {
    $found = 1;
  }

  ## Words ending in s
  if (!$found && $word =~ /s$/) {
    $plural =~ s/s$/ses/;
    $found = 1;
  }

  ## Words ending in x 
  if (!$found && $word =~ /x$/) {
    $plural =~ s/x$/xes/;
    $found = 1;
  }
  
  unless ($found) {
    $plural .= "s";
  }
  return $plural;
}

sub singular {
  ### Returns the single form of a word. 
  ### Note: this is not a definitive lexical modification!
  ### Extended this method with more complex rules if it doesn't
  ### return what you expected.
 
  my ($self, $word) = @_;
  my $singular = $word;
  my $found = 0;

  ## Words ending in ws - skip
  if (!$found && $word =~ /ws$/) {
    $found = 1;
  }

  ## Words ending in ses
  if (!$found && $word =~ /ses$/) {
    $singular =~ s/ses$/s/;
    $found = 1;
  }

  ## Words ending in xes
  if (!$found && $word =~ /xes$/) {
    $singular =~ s/xes$/x/;
    $found = 1;
  }

  unless ($found) {
    $singular =~ s/s$//;
  }

  return $singular;
}

1;

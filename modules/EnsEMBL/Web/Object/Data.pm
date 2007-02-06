package EnsEMBL::Web::Object::Data;

use strict;
use warnings;

use Class::Std;
use EnsEMBL::Web::DBSQL::SQL::Result;
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
    if ($field eq $self->get_data_field_name) {
      $self->populate_data($result->get_value($key));
    } else {
      $self->$field($result->get_value($key));
    }
  }
}

sub populate_data {
  my ($self, $string) = @_;
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

sub add_has_many {
  my ($self, $arg) = @_;
  if (!$self->get_has_many) {
    $self->set_has_many([]);
  }
  push @{ $self->has_many}, $arg;
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
  warn "Adding relational accessor: " . $attribute;
  return sub {
    my $self = shift;
    my $new_value = shift;
    if (defined $new_value) {
      $self->set_value($attribute,  $new_value);
    }
    return $self->get_lazy_value($attribute);
  };
}

sub get_lazy_value {
  my ($self, $attribute) = @_;
  my $class = $self->relational_class($attribute);
  my $accessor = $self->object_name_from_package($class) . "_id";
  my $object = $self->object_name_from_package($class);
  if (defined $self->get_value($object)) {
    return $self->get_value($object);
  }
  warn "Creating new $attribute with class " . $class . " and " . $accessor;
  if (EnsEMBL::Web::Root::dynamic_use(undef, $class)) {
    my $new = $class->new({ id => $self->$accessor });
    $self->set_value($object, $new);
    return $new;
  }
  return undef;
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
  if (defined $self->get_value('id')) {
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
  return $self->get_adaptor->destroy($self);
}

# Util methods

sub object_name_from_package {
  my ($self, $name) = @_;
  my @components = split /::/, $name;
  return lc($components[$#components]);
}

1;

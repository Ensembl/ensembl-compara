package EnsEMBL::Web::Object::Data;

use strict;
use warnings;

use Class::Std;
use EnsEMBL::Web::Object::DataField;

{

my %Fields :ATTR(:set<fields> :get<fields>);
my %Value :ATTR(:set<values>, :get<values>);
my %Queriable_Fields :ATTR(:set<queriable_fields> :get<queriable_fields>);
my %Record_type :ATTR(:set<record_type> :get<record_type>);
my %Adaptor :ATTR(:set<adaptor> :get<adaptor>);
my %Belongs_to :ATTR(:set<belongs_to> :get<belongs_to>);
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
  $self->add_symbol_lookup($args->{name});
  push @{ $self->get_fields }, EnsEMBL::Web::Object::DataField->new( { name => $args->{name}, type => $args->{type} } );
}

sub add_queriable_field {
  my ($self, $args) = @_;
  if (!$self->get_queriable_fields) {
    $self->set_queriable_fields([]);
  }
  $self->add_symbol_lookup($args->{name});
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
  $self->add_symbol_lookup($self->object_name_from_package($arg));
  $self->add_symbol_lookup($self->object_name_from_package($arg) . "_id");
  push @{ $self->get_belongs_to }, $arg;
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

sub add_symbol_lookup {
  my ($self, $name) = @_;
  no strict;
  my $class = ref($self);
  $self->set_value({ $name => "" });
  *{ "$class\::$name" } = $self->initialize_accessor($name);
}

sub has_id {
  my ($self) = @_;
  if (defined $self->get_value('id')) {
    return 1;
  }
  return 0;
}

# DB methods

sub populate {
  my $self = shift;
  my $hash = $self->get_adaptor->select({ id => $self->id });
}

sub save {
  my $self = shift;
  return $self->get_adaptor->save($self);
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

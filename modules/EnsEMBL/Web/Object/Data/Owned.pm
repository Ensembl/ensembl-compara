package EnsEMBL::Web::Object::Data::Owned;

### Parent class for records that belong to a user or group
## Can be multiply-inherited with Object::Data::Trackable

use strict;
use warnings;

use Class::Std;
use EnsEMBL::Web::Object::Data;

our @ISA = qw(EnsEMBL::Web::Object::Data);

my %Owner :ATTR(:set<record_type> :get<record_type>);

{

sub BUILD {
  my ($self, $ident, $args) = @_;
  $self->add_queriable_field({ name => 'type', type => 'text' });
  $self->set_data_field_name('data');
}

sub attach_owner {
  my $self = shift;
  my $record_type = shift || 'user';
  $self->set_record_type($record_type);
  $self->set_primary_key($self->key);
  $self->set_adaptor(EnsEMBL::Web::DBSQL::MySQLAdaptor->new({table => $self->table }));
  ## Remove any existing owner
  my $belongs = $self->get_belongs_to;
  if ($belongs && ref($belongs) eq 'ARRAY') {
    $self->set_belongs_to([]);
    my @ok_fields;
    foreach my $field (@{$self->get_queriable_fields}) {
      push @ok_fields, $field unless ($field->get_name =~ 'user_id' || $field->get_name =~ 'group_id');
    }
    $self->set_queriable_fields(\@ok_fields);
  }
  ## Set owner

  if ($record_type eq 'group') {
    $self->add_belongs_to("EnsEMBL::Web::Object::Data::Group");
  }
  else {
    $self->add_belongs_to("EnsEMBL::Web::Object::Data::User");
  }
}

sub record_type {
  my $self = shift;
  return $self->get_record_type;
}

sub key {
  my $self = shift;
  if ($self->get_record_type && $self->get_record_type eq 'group') {
    return '%%group_record%%_id';
  }
  else {
    return '%%user_record%%_id';
  }
}

sub table {
  my $self = shift;
  if ($self->get_record_type && $self->get_record_type eq 'group') {
    return '%%group_record%%';
  }
  else {
    return '%%user_record%%';
  }
}

}

1;

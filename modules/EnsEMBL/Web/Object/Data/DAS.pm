package EnsEMBL::Web::Object::Data::DAS;

use strict;
use warnings;

use Class::Std;
use EnsEMBL::Web::DBSQL::MySQLAdaptor;
use EnsEMBL::Web::DASConfig;
use EnsEMBL::Web::Object::Data;

our @ISA = qw(EnsEMBL::Web::Object::Data);

{

sub BUILD {
  my ($self, $ident, $args) = @_;
  $self->set_primary_key($self->key);
  $self->set_adaptor(EnsEMBL::Web::DBSQL::MySQLAdaptor->new({table => $self->table }));
  $self->set_data_field_name('data');
  $self->add_field({ name => 'url', type => 'text' });
  $self->add_field({ name => 'name', type => 'text' });
  $self->add_field({ name => 'config', type => 'text' });
  $self->add_queriable_field({ name => 'type', type => 'text' });
  $self->type('das');
  $self->add_belongs_to("EnsEMBL::Web::Object::Data::User");
  $self->add_belongs_to("EnsEMBL::Web::Object::Data::Group");
  $self->populate_with_arguments($args);
}

sub get_das_config {
  my ($self) = @_;
  my $dasconfig = EnsEMBL::Web::DASConfig->new;
  $dasconfig->create_from_hash_ref($self->config);
  return $dasconfig;
}

sub key {
  return "user_record_id";
}

sub table {
  return 'user_record';
}

}

1;

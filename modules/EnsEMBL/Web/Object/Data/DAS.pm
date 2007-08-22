package EnsEMBL::Web::Object::Data::DAS;

use strict;
use warnings;

use Class::Std;
use EnsEMBL::Web::DBSQL::MySQLAdaptor;
use EnsEMBL::Web::DASConfig;
use EnsEMBL::Web::Object::Data::Trackable;
use EnsEMBL::Web::Object::Data::Owned;

our @ISA = qw(EnsEMBL::Web::Object::Data::Trackable  EnsEMBL::Web::Object::Data::Owned);


{

sub BUILD {
  my ($self, $ident, $args) = @_;
  $self->type('das');
  $self->attach_owner($args->{'record_type'});
  $self->set_primary_key($self->key);
  $self->set_adaptor(EnsEMBL::Web::DBSQL::MySQLAdaptor->new({table => $self->table }));
  $self->add_field({ name => 'url', type => 'text' });
  $self->add_field({ name => 'name', type => 'text' });
  $self->add_field({ name => 'config', type => 'text' });
  $self->populate_with_arguments($args);
}

sub get_das_config {
  my ($self) = @_;
  my $dasconfig = EnsEMBL::Web::DASConfig->new;
  $dasconfig->create_from_hash_ref($self->config);
  return $dasconfig;
}

}

1;

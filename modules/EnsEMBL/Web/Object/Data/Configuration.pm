package EnsEMBL::Web::Object::Data::Configuration;

use strict;
use warnings;

use Class::Std;
use EnsEMBL::Web::Object::Data;
use EnsEMBL::Web::DBSQL::MySQLAdaptor;

our @ISA = qw(EnsEMBL::Web::Object::Data);

{

sub BUILD {
  my ($self, $ident, $args) = @_;
  $self->set_primary_key('user_record_id');
  $self->set_adaptor(EnsEMBL::Web::DBSQL::MySQLAdaptor->new({table => 'user_record' }));
  $self->set_data_field_name('data');
  $self->add_field({ name => 'scriptconfig', type => 'text' });
  $self->add_field({ name => 'name', type => 'text' });
  $self->add_field({ name => 'url', type => 'text' });
  $self->add_field({ name => 'description', type => 'text' });
  $self->add_queriable_field({ name => 'type', type => 'text' });
  $self->type('configuration');
  $self->add_belongs_to("EnsEMBL::Web::Object::Data::User");
  $self->populate_with_arguments($args);
}

}

1;

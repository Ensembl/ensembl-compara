package EnsEMBL::Web::Object::Data::Invite;

use strict;
use warnings;

use Class::Std;
use EnsEMBL::Web::Object::Data;
use EnsEMBL::Web::DBSQL::MySQLAdaptor;

our @ISA = qw(EnsEMBL::Web::Object::Data);

{

sub BUILD {
  my ($self, $ident, $args) = @_;
  $self->set_primary_key('group_record_id');
  $self->set_adaptor(EnsEMBL::Web::DBSQL::MySQLAdaptor->new({table => 'group_record' }));
  $self->set_data_field_name('data');
  $self->add_field({ name => 'email', type => 'text' });
  $self->add_field({ name => 'status', type => 'text' });
  $self->add_field({ name => 'code', type => 'text' });
  $self->add_queriable_field({ name => 'type', type => 'text' });
  $self->type('invite');
  $self->add_belongs_to("EnsEMBL::Web::Object::Data::Group");
  $self->populate_with_arguments($args);
}

}

1;

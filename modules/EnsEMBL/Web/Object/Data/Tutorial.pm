package EnsEMBL::Web::Object::Data::Tutorial;

use strict;
use warnings;

use Class::Std;
use EnsEMBL::Web::Object::Data::Trackable;
use EnsEMBL::Web::DBSQL::MySQLAdaptor;

our @ISA = qw(EnsEMBL::Web::Object::Data::Trackable);

{

sub BUILD {
  my ($self, $ident, $args) = @_;
  $self->set_primary_key('help_record_id');
  $self->set_adaptor(EnsEMBL::Web::DBSQL::MySQLAdaptor->new(
                        {table => 'help_record',
                        adaptor => 'websiteAdaptor'}
  ));
  $self->set_data_field_name('data');
  $self->add_field({ name => 'title', type => 'string' });
  $self->add_field({ name => 'filename', type => 'string' });
  $self->add_field({ name => 'filesize', type => 'float(3,1)' });
  $self->add_field({ name => 'list_position', type => 'int' });
  $self->add_queriable_field({ name => 'keyword', type => 'string' });
  $self->add_queriable_field({ name => 'status', type => "enum('draft','live','dead')" });
  $self->add_queriable_field({ name => 'type', type => 'string' });
  $self->type('tutorial');
  $self->populate_with_arguments($args);
}

}

1;

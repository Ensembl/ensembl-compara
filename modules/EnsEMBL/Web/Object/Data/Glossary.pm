package EnsEMBL::Web::Object::Data::Glossary;

use strict;
use warnings;

use Class::Std;
use EnsEMBL::Web::Object::Data;
use EnsEMBL::Web::DBSQL::MySQLAdaptor;

our @ISA = qw(EnsEMBL::Web::Object::Data);

{

sub BUILD {
  my ($self, $ident, $args) = @_;
  $self->set_primary_key('help_record_id');
  $self->set_adaptor(EnsEMBL::Web::DBSQL::MySQLAdaptor->new(
                        {table => 'help_record',
                        adaptor => 'websiteAdaptor'}
  ));
  $self->set_data_field_name('data');
  $self->add_field({ name => 'word', type => 'tinytext' });
  $self->add_field({ name => 'acronym_for', type => 'tinytext' });
  $self->add_field({ name => 'meaning', type => 'text' });
  $self->add_queriable_field({ name => 'type', type => 'varchar(255)' });
  $self->add_queriable_field({ name => 'status', type => "enum('draft','live','dead')" });
  $self->type('glossary');
  #$self->add_belongs_to("EnsEMBL::Web::Object::Data::User");
  $self->populate_with_arguments($args);
}

}

1;

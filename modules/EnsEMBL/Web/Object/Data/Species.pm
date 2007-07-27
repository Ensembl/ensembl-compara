package EnsEMBL::Web::Object::Data::Species;

use strict;
use warnings;

use Class::Std;
use EnsEMBL::Web::Object::Data;
use EnsEMBL::Web::DBSQL::MySQLAdaptor;

our @ISA = qw(EnsEMBL::Web::Object::Data);

{

sub BUILD {
  my ($self, $ident, $args) = @_;
  $self->set_adaptor(EnsEMBL::Web::DBSQL::MySQLAdaptor->new({ 'table' => 'species', 
                                                              'adaptor' => 'websiteAdaptor'}));
  $self->set_primary_key('species_id');
  $self->add_queriable_field({ name => 'code', type => 'char(3)' });
  $self->add_queriable_field({ name => 'name', type => 'varchar(255)' });
  $self->add_queriable_field({ name => 'common_name', type => 'varchar(32)' });
  $self->add_queriable_field({ name => 'vega', type => "enum('N','Y')" });
  $self->add_queriable_field({ name => 'dump_notes', type => 'text' });
  $self->add_belongs_to("EnsEMBL::Web::Object::Data::Release");
  $self->add_belongs_to("EnsEMBL::Web::Object::Data::NewsItem");
  $self->populate_with_arguments($args);
}

}

1;

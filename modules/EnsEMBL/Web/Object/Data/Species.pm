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
  $self->set_adaptor(EnsEMBL::Web::DBSQL::MySQLAdaptor->new({ table => 'species' }));
  $self->set_primary_id({ name => 'species_id', type => 'int' });
  $self->add_queriable_field({ name => 'code', type => 'char(3)' });
  $self->add_queriable_field({ name => 'name', type => 'varchar(255)' });
  $self->add_queriable_field({ name => 'common_name', type => 'varchar(32)' });
  $self->add_queriable_field({ name => 'vega', type => "enum('N','Y')" });
  $self->add_belongs_to("EnsEMBL::Web::Object::Data::Release");
  $self->add_belongs_to("EnsEMBL::Web::Object::Data::NewsItem");
}

}

1;

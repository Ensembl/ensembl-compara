package EnsEMBL::Web::Object::Data::Release;

use strict;
use warnings;

use Class::Std;
use EnsEMBL::Web::Object::Data;
use EnsEMBL::Web::DBSQL::MySQLAdaptor;

our @ISA = qw(EnsEMBL::Web::Object::Data);

{

sub BUILD {
  my ($self, $ident, $args) = @_;
  $self->set_adaptors({ db => 'website', table => 'ens_release' });
  $self->set_primary_id({ name => 'release_id', type => 'int' });
  $self->add_queriable_field({ name => 'number', type => 'varchar(5)' });
  $self->add_queriable_field({ name => 'date', type => 'date' });
  $self->add_queriable_field({ name => 'archive', type => 'varchar(7)' });
  $self->has_many("EnsEMBL::Web::Object::Data::NewsItem");
  $self->has_many("EnsEMBL::Web::Object::Data::Species");
}

}

1;

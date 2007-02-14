package EnsEMBL::Web::Object::Data::NewsCategory;

use strict;
use warnings;

use Class::Std;
use EnsEMBL::Web::Object::Data;
use EnsEMBL::Web::DBSQL::MySQLAdaptor;

our @ISA = qw(EnsEMBL::Web::Object::Data);

{

sub BUILD {
  my ($self, $ident, $args) = @_;
  $self->set_adaptor(EnsEMBL::Web::DBSQL::MySQLAdaptor->new({ table => 'news_category' }));
  $self->set_primary_id({ name => 'news_category_id', type => 'int' });
  $self->add_queriable_field({ name => 'code', type => 'varchar(10)' });
  $self->add_queriable_field({ name => 'name', type => 'varchar(64)' });
  $self->add_queriable_field({ name => 'priority', type => 'tinyint' });
  $self->has_many("EnsEMBL::Web::Object::Data::NewsItem");
}

}

1;

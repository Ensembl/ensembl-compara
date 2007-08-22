package EnsEMBL::Web::Object::Data::OldHelpCategory;

use strict;
use warnings;

use Class::Std;
use EnsEMBL::Web::DBSQL::MySQLAdaptor;
use EnsEMBL::Web::Object::Data;

our @ISA = qw(EnsEMBL::Web::Object::Data);


{

sub BUILD {
  my ($self, $ident, $args) = @_;
  $self->set_adaptor(EnsEMBL::Web::DBSQL::MySQLAdaptor->new({table => 'category', 'adaptor' => 'websiteAdaptor' }));
  $self->set_primary_key('category_id');
  $self->add_queriable_field({ name => 'name', type => 'string' });
  $self->add_queriable_field({ name => 'priority', type => 'int' });
  $self->add_has_many({ class => 'EnsEMBL::Web::Object::Data::OldHelpArticle'});
  $self->populate_with_arguments($args);
}

}

1;

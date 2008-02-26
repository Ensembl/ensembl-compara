package EnsEMBL::Web::Data::NewsItem;

use strict;
use warnings;

use Class::Std;
use EnsEMBL::Web::Data::Trackable;
use EnsEMBL::Web::DBSQL::MySQLAdaptor;

our @ISA = qw(EnsEMBL::Web::Data::Trackable);

{

sub BUILD {
  my ($self, $ident, $args) = @_;
  $self->set_adaptor(EnsEMBL::Web::DBSQL::MySQLAdaptor->new({ 'table' => 'news_item',
                                                              'adaptor' => 'websiteAdaptor'}));
  $self->set_primary_key('news_item_id');
  $self->add_queriable_field({ name => 'title', type => 'tinytext' });
  $self->add_queriable_field({ name => 'content', type => 'text' });
  $self->add_queriable_field({ name => 'declaration', type => 'text' });
  $self->add_queriable_field({ name => 'notes', type => 'text' });
  $self->add_queriable_field({ name => 'priority', type => 'int' });
  $self->add_queriable_field({ name => 'species_id', type => 'int' }); ## Replacement for has_many
  $self->add_queriable_field({ name => 'status', type => "enum('declared','done','news_ok','news_not_ok')" });
  $self->add_belongs_to("EnsEMBL::Web::Data::Release");
  $self->add_belongs_to("EnsEMBL::Web::Data::NewsCategory");
  #$self->add_has_many({ class => 'EnsEMBL::Web::Data::Species'});
  $self->populate_with_arguments($args);
}

sub get_categories {
  my $self = shift;
  return EnsEMBL::Web::Data::find_all('EnsEMBL::Web::Data::NewsCategory');
}

}

1;

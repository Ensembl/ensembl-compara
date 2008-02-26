package EnsEMBL::Web::Data::Release;

use strict;
use warnings;

use Class::Std;
use EnsEMBL::Web::Data;
use EnsEMBL::Web::DBSQL::MySQLAdaptor;

our @ISA = qw(EnsEMBL::Web::Data);

{

sub BUILD {
  my ($self, $ident, $args) = @_;
  $self->set_adaptor(EnsEMBL::Web::DBSQL::MySQLAdaptor->new({ 'table' => 'ens_release',
                                                              'adaptor' => 'websiteAdaptor'}));
  $self->set_primary_key('release_id');
  $self->add_queriable_field({ name => 'number', type => 'varchar(5)' });
  $self->add_queriable_field({ name => 'date', type => 'date' });
  $self->add_queriable_field({ name => 'archive', type => 'varchar(7)' });
  $self->add_queriable_field({ name => 'online', type => "enum('N','Y')" });
  $self->add_has_many({ class => "EnsEMBL::Web::Data::NewsItem"});
  $self->add_has_many({ class => "EnsEMBL::Web::Data::Species"});
  $self->populate_with_arguments($args);
}

}

1;

package EnsEMBL::Web::Data::View;

## Representation of a help record for an Ensembl view
## N.B. the keyword for this type of record is the name of the view script

use strict;
use warnings;

use Class::Std;
use EnsEMBL::Web::Data::Trackable;
use EnsEMBL::Web::DBSQL::MySQLAdaptor;

our @ISA = qw(EnsEMBL::Web::Data::Trackable);

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
  $self->add_field({ name => 'content', type => 'text' });
  $self->add_queriable_field({ name => 'keyword', type => 'string' });
  $self->add_queriable_field({ name => 'status', type => "enum('draft','live','dead')" });
  $self->add_queriable_field({ name => 'helpful', type => 'int' });
  $self->add_queriable_field({ name => 'not_helpful', type => 'int' });
  $self->add_queriable_field({ name => 'type', type => 'string' });
  $self->type('view');
  $self->populate_with_arguments($args);
}

}

1;

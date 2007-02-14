package EnsEMBL::Web::Object::Data::MiniAd;

use strict;
use warnings;

use Class::Std;
use EnsEMBL::Web::Object::Data;
use EnsEMBL::Web::DBSQL::MySQLAdaptor;

our @ISA = qw(EnsEMBL::Web::Object::Data);

{

sub BUILD {
  my ($self, $ident, $args) = @_;
  $self->set_adaptor(EnsEMBL::Web::DBSQL::MySQLAdaptor->new(
                          {adaptor => 'websiteAdaptor', 
                          table => 'miniad' }
  ));
  $self->set_primary_key('miniad_id');
  $self->add_queriable_field({ name => 'image',       type => 'varchar(32)' });
  $self->add_queriable_field({ name => 'alt',         type => 'tinytext' });
  $self->add_queriable_field({ name => 'url',         type => 'tinytext' });
  $self->add_queriable_field({ name => 'start_date',  type => 'date' });
  $self->add_queriable_field({ name => 'end_date',    type => 'date' });
  $self->populate_with_arguments($args);
}

}

1;

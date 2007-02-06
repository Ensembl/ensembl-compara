package EnsEMBL::Web::Object::Data::Bookmark;

use strict;
use warnings;

use Class::Std;
use EnsEMBL::Web::Object::Data;
use EnsEMBL::Web::DBSQL::MySQLAdaptor;

our @ISA = qw(EnsEMBL::Web::Object::Data);

{

sub BUILD {
  my ($self, $ident, $args) = @_;
  $self->set_record_type('bookmark');
  $self->set_primary_key('record_id');
  $self->set_adaptor(EnsEMBL::Web::DBSQL::MySQLAdaptor->new({table => 'user_record' }));
  $self->add_field({ name => 'url', type => 'text' });
  $self->add_field({ name => 'title', type => 'text' });
  $self->add_belongs_to("EnsEMBL::Web::Object::Data::User");
}

}

1;

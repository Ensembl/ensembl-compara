package EnsEMBL::Web::Component::Server::Summary;

use strict;
use warnings;
no warnings "uninitialized";
use base qw(EnsEMBL::Web::Component::Server);
use EnsEMBL::Web::Document::HTML::TwoCol;

sub _init {
  my $self = shift;
  $self->cacheable( 0 );
  $self->ajaxable(  0 );
}

sub content {
  my $self = shift;
  my $object = $self->object;
  my $table = new EnsEMBL::Web::Document::HTML::TwoCol;
##-- Server URL
  $table->add_row( 'Server', 
    sprintf( '<p><a href="%s">%s</a></p>',
      $object->species_defs->ENSEMBL_BASE_URL,
      $object->species_defs->ENSEMBL_BASE_URL
    ),1
  );
  return $table->render;
}

1;    

package EnsEMBL::Web::Component::Info::WhatsNew;

use strict;
use warnings;
no warnings "uninitialized";
use base qw(EnsEMBL::Web::Component);
use EnsEMBL::Web::Document::HTML::News;

sub _init {
  my $self = shift;
  $self->cacheable( 0 );
  $self->ajaxable(  0 );
}


sub content {
  my $self   = shift;
  my $html = EnsEMBL::Web::Document::HTML::News->render; 

  return $html;
}

1;

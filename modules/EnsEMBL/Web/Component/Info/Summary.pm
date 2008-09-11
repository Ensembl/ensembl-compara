package EnsEMBL::Web::Component::Info::Summary;

use strict;
use warnings;
no warnings "uninitialized";
use base qw(EnsEMBL::Web::Component);
use EnsEMBL::Web::Document::HTML::HomeSearch;

sub _init {
  my $self = shift;
  $self->cacheable( 0 );
  $self->ajaxable(  0 );
}


sub content {
  my $self   = shift;
  my $object = $self->object;
  my $html = '<br />';
  my $search = EnsEMBL::Web::Document::HTML::HomeSearch->new();
  $html .= $search->render;

  return $html;
}

1;

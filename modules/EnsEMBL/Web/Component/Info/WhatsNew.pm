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

  return EnsEMBL::Web::Document::HTML::News->new($_[0]->hub)->render;
}

1;

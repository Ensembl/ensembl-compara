package EnsEMBL::Web::Component::Info::Content;

## Module for displaying arbitrary HTML pages

use strict;

use EnsEMBL::Web::Controller::SSI;

use base qw(EnsEMBL::Web::Component);

sub _init {
  my $self = shift;
  $self->cacheable(0);
  $self->ajaxable(0);
}

sub content {
  my $self = shift;
  my $hub  = $self->hub;
  my $file = $hub->param('file');
  $file    =~ s/\s+//g;
  $file    =~ s/^[\.\/\\]*//;
  $file    =~ s/\/\.+/\//g;
  $file    =~ s/\/+/\//g;
  
  return EnsEMBL::Web::Controller::SSI::template_INCLUDE($self, $hub->species . "/$file"); 
}

1;

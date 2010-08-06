package EnsEMBL::Web::Component::Info::Content;

## Module for displaying arbitrary HTML pages

use strict;
use warnings;
no warnings "uninitialized";
use base qw(EnsEMBL::Web::Component);
use EnsEMBL::Web::Apache::SendDecPage;

sub _init {
  my $self = shift;
  $self->cacheable( 0 );
  $self->ajaxable(  0 );
}


sub content {
  my $self   = shift;
  my $hub = $self->hub;
  my $file = $hub->param('file');

  $file =~ s/\s+//g;
  $file =~ s/^[\.\/\\]*//;
  $file =~ s/\/\.+/\//g;
  $file =~ s/\/+/\//g;
  my $html; 

  my $file = $hub->species.'/'.$file;
  $html .= EnsEMBL::Web::Apache::SendDecPage::template_INCLUDE(undef, $file); 

  return $html;
}

1;

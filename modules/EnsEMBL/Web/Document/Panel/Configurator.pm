# $Id$

package EnsEMBL::Web::Document::Panel::Configurator;

use strict;

use base qw(EnsEMBL::Web::Document::Panel);

sub set_content {
  my ($self, $content) = @_;
  
  $self->{'content'} = qq{
  <div class="panel">
    <div class="content">
      $content
    </div>
  </div>};
}

sub _error { my $self = shift; return sprintf '<h1>AJAX error - %s</h1><pre>%s</pre>', @_; }

1;

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

sub render {
  my ($self, $first) = @_;
  
  if ($self->{'json'}) {
    return $self->{'content'};
  } else {
    $self->content;
  }
}

sub _error { shift->printf('<h1>AJAX error - %s</h1><pre>%s</pre>', @_); }

1;

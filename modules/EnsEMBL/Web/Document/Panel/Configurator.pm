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
  
  my $content = $self->{'delayed_write'} ? $self->_content_delayed : '';
  
  if ($self->{'_delayed_write_'}) {
    $self->renderer->print($content);
  } elsif ($self->{'json'}) {
    return $self->{'content'};
  } else {
    $self->content;
  }
}

sub _error {
  my ($self, $caption, $body) = @_;
  
  $self->printf('<h1>AJAX error - %s</h1><pre>%s</pre>', $caption, $body);
}

1;

package EnsEMBL::Web::Document::Panel::Ajax;

use strict;
use Data::Dumper qw(Dumper);

use base qw(EnsEMBL::Web::Document::Panel);

sub _start {
  my $self = shift;
}

sub _end   { 
  my $self = shift;
}

sub render {
  my( $self, $first ) = @_;
  my $content = '';
  if( $self->{'delayed_write'} ) {
    $content = $self->_content_delayed();
  }
  if( $self->{'cacheable'} eq 'yes' ) { ### We can cache this panel - so switch the renderer!!!
    my $temp_renderer = $self->renderer;
    $self->renderer = new EnsEMBL::Web::Document::Renderer::GzCacheFile( $self->{'cache_type'}, $self->{'cache_filename'} );
    if( $self->{'_delayed_write_'} ) {
      $self->renderer->print($content)    unless( $self->renderer->{'exists'} eq 'yes' );
    } else {
      $self->content()            unless( $self->renderer->{'exists'} eq 'yes' );
    }
    $self->renderer->close();
    $content = $self->renderer->content;
    $self->renderer = $temp_renderer;
    $self->renderer->print( $content );
  } else {
    if( $self->{'_delayed_write_'} ) {
      $self->renderer->print($content);
    } else {
      $self->content();
    }
  }
}

sub _error {
  my( $self, $caption, $body ) = @_;
  $self->add_row( $caption, $body );
}

1;

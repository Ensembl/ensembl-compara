package EnsEMBL::Web::Component::Help::View;

use strict;
use warnings;
no warnings "uninitialized";
use HTML::Entities qw(encode_entities);
use base qw(EnsEMBL::Web::Component::Help);
use EnsEMBL::Web::Data::View;
use EnsEMBL::Web::Component::Help::Movie;

sub _init {
  my $self = shift;
  $self->cacheable( 0 );
  $self->ajaxable(  0 );
  $self->configurable( 0 );
}

sub content {
  my $self = shift;
  my $hub = $self->model->hub;

  my $html;

  my $help = EnsEMBL::Web::Data::View->new(encode_entities($hub->param('id')));
  if ($help) {
    my $content = $help->content;
    ### Parse help looking for embedded movie placeholders
    foreach my $line (split('\n', $content)) {
      if ($line =~ /\[\[movie=(\d+)/i) {
        $line = EnsEMBL::Web::Component::Help::Movie::embed_movie($1);
      }
      $html .= $line;
    }
  }

  return $html;
}

1;

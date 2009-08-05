package EnsEMBL::Web::Component::Help::View;

use strict;
use warnings;
no warnings "uninitialized";
use base qw(EnsEMBL::Web::Component::Help);
use CGI qw(escapeHTML);
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
  my $object = $self->object;

  my $html;

  my $help = EnsEMBL::Web::Data::View->new(CGI::escapeHTML($object->param('id')));
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

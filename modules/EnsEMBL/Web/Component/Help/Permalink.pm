package EnsEMBL::Web::Component::Help::Permalink;

use strict;
use warnings;

use base qw(EnsEMBL::Web::Component::Help);

no warnings "uninitialized";

sub _init {
  my $self = shift;
  $self->cacheable(1);
  $self->ajaxable(0);
  $self->configurable(0);
}

sub content {
  my $self     = shift;
  my $hub      = $self->hub;
  my $sitename = $hub->species_defs->ENSEMBL_SITETYPE;
  my $url      = $hub->param('url') . $hub->referer->{'uri'};
  my $r        = $hub->param('r');
  
  if ($r) {
    $url  =~ s/([\?;&]r=)[^;]+(;?)/$1$r$2/;
    $url .= ($url =~ /\?/ ? ';r=' : '?r=') . $r unless $url =~ /[\?;&]r=[^;&]+/;
  }
  
  return qq{
    <p class="space-below">For a permanent link to this page, which will not change with the next release of $sitename, use:</p>
    <p class="space-below"><a href="$url" class="cp-external">$url</a></p>
    <p>We aim to maintain all archives for at least two years; some key releases may be maintained for longer</p>
  };
}

1;

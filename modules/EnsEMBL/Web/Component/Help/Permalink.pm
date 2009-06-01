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
  my $self = shift;
  my $object = $self->object;

  my $sitename = $object->species_defs->ENSEMBL_SITETYPE;
  my $url = $object->param('url');

  my $html = qq(<p class="space-below">For a permanent link to this page, which will not change with the next release 
of $sitename, use:</p>
<p class="space-below"><a href="$url" class="cp-external">$url</a></p>
<p>We aim to maintain all archives for at least two years; some key releases may be maintained 
for longer);
  
  return $html;
}

1;

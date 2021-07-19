=head1 LICENSE

Copyright [1999-2015] Wellcome Trust Sanger Institute and the EMBL-European Bioinformatics Institute
Copyright [2016-2021] EMBL-European Bioinformatics Institute

Licensed under the Apache License, Version 2.0 (the "License");
you may not use this file except in compliance with the License.
You may obtain a copy of the License at

     http://www.apache.org/licenses/LICENSE-2.0

Unless required by applicable law or agreed to in writing, software
distributed under the License is distributed on an "AS IS" BASIS,
WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
See the License for the specific language governing permissions and
limitations under the License.

=cut

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

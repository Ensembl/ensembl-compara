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

package EnsEMBL::Web::Document::Element::ToolLinks;

### Generates links in masthead

use strict;
use warnings;

use parent qw(EnsEMBL::Web::Document::Element);

sub links {
  my $self  = shift;
  my $hub   = $self->hub;
  my $sd    = $self->species_defs;
  my $blog  = $sd->ENSEMBL_BLOG_URL;
  my @links;

  push @links, 'mart',          '<a class="constant" href="/biomart/martview">BioMart</a>' if $sd->ENSEMBL_MART_ENABLED;
  push @links, 'download',      '<a class="constant" rel="nofollow" href="/info/data/">Downloads</a>';
  push @links, 'documentation', '<a class="constant" rel="nofollow" href="/info/">Help &amp; Docs</a>';
  push @links, 'blog',          qq(<a class="constant" target="_blank" href="$blog">Blog</a>) if $blog;

  return \@links;
}

sub content {
  my $self    = shift;
  my $hub     = $self->hub;
  my $links   = $self->links;
  my $menu    = '';

  while (my (undef, $link) =  splice @$links, 0, 2) {
    $menu .= sprintf '<li%s>%s</li>', @$links ? '' : ' class="last"', $link;
  }

  return qq(<ul class="tools">$menu</ul><div class="more"><a href="#">More <span class="arrow">&#9660;</span></a></div>);
}

1;

=head1 LICENSE

Copyright [1999-2014] Wellcome Trust Sanger Institute and the EMBL-European Bioinformatics Institute

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

### Generates links to site tools - BLAST, help, login, etc (currently in masthead)

use strict;

use base qw(EnsEMBL::Web::Document::Element);

sub home    :lvalue { $_[0]{'home'};   }
sub blast   :lvalue { $_[0]{'blast'};   }
sub biomart :lvalue { $_[0]{'biomart'}; }
sub blog    :lvalue { $_[0]{'blog'};   }

sub init {
  my $self         = shift;
  my $species_defs = $self->species_defs;
  
  $self->home    = $species_defs->ENSEMBL_BASE_URL;
  $self->blast   = $species_defs->ENSEMBL_BLAST_ENABLED;
  $self->biomart = $species_defs->ENSEMBL_MART_ENABLED;
  $self->blog    = $species_defs->ENSEMBL_BLOG_URL;
}

sub content {
  my $self    = shift;
  my $hub     = $self->hub;
  my $species = $hub->species;
     $species = !$species || $species eq 'Multi' || $species eq 'common' ? 'Multi' : $species;
  my @links; # = sprintf '<a class="constant" href="%s">Home</a>', $self->home;
  
  
  push @links, qq(<a class="constant" href="/$species/Tools/Blast">BLAST/BLAT</a>) if $self->blast;
  push @links,   '<a class="constant" href="/biomart/martview">BioMart</a>'        if $self->biomart;
  push @links,   '<a class="constant" href="/info/docs/tools/index.html">Tools</a>';
  push @links,   '<a class="constant" href="/downloads.html">Downloads</a>';
  push @links,   '<a class="constant" href="/info/">Help &amp; Documentation</a>';
  push @links,   '<a class="constant" href="'.$self->blog.'">Blog</a>'                  if $self->blog;
  push @links,   '<a class="constant modal_link" href="/Help/Mirrors">Mirrors</a>' if keys %{$hub->species_defs->ENSEMBL_MIRRORS || {}};

  my $last  = pop @links;
  my $tools = join '', map "<li>$_</li>", @links;
  
  return qq{
    <ul class="tools">$tools<li class="last">$last</li></ul>
    <div class="more">
      <a href="#">More <span class="arrow">&#9660;</span></a>
    </div>
  };
}

1;

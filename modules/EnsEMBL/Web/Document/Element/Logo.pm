=head1 LICENSE

Copyright [1999-2015] Wellcome Trust Sanger Institute and the EMBL-European Bioinformatics Institute
Copyright [2016-2022] EMBL-European Bioinformatics Institute

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

package EnsEMBL::Web::Document::Element::Logo;

### Generates the logo wrapped in a link to the homepage

use strict;

use base qw(EnsEMBL::Web::Document::Element);

sub image       :lvalue { $_[0]{'image'};       }
sub width       :lvalue { $_[0]{'width'};       }
sub height      :lvalue { $_[0]{'height'};      }
sub alt         :lvalue { $_[0]{'alt'};         }
sub href        :lvalue { $_[0]{'href'}         }
sub print_image :lvalue { $_[0]{'print_image'}; }

sub logo_print {
### a
  my $self = shift;
  return sprintf(
    '<img src="%s%s" alt="%s" title="%s" class="screen_hide_inline" style="width:%spx;height:%spx" />',
    $self->img_url, $self->print_image, $self->alt, $self->alt, $self->width, $self->height
  ) if ($self->print_image);
}

sub content {
  my $self = shift;
  my $url  = $self->href || $self->home_url;
  
  my $html = sprintf '<a href="%s"><div class="logo-header print_hide" title="%s">&nbsp;</div></a>', 
              $url, $self->alt; 

  my $species = $self->hub->{'_species'};
  $species = '' if ($species eq 'Multi');

  $html .= sprintf '<span class="mobile-only species-header">%s</span>',
              $species ? $self->species_defs->SPECIES_DISPLAY_NAME 
                       : $self->species_defs->ENSEMBL_SITETYPE; 

  $html .= $self->logo_print;

  return $html;
}

sub init {
  my $self  = shift;
  my $style = $self->species_defs->ENSEMBL_STYLE;
 
  # SiteDefs is the right place for this, please use it. There are many
  # customisations, though, which rely on INI, probably including external
  # installs. We should announce this change and then remove the old
  # mechanism in a future release. SiteDefs type is required for EBI AWS
  # mirrors, as they execute code.
  $self->image  = $style->{'SITE_LOGO'} || $SiteDefs::SITE_LOGO;
  $self->width  = $style->{'SITE_LOGO_WIDTH'} || $SiteDefs::SITE_LOGO_WIDTH;
  $self->height = $style->{'SITE_LOGO_HEIGHT'} || $SiteDefs::SITE_LOGO_HEIGHT;
  $self->alt    = $style->{'SITE_LOGO_ALT'} || $SiteDefs::SITE_LOGO_ALT;
  $self->href   = $style->{'SITE_LOGO_HREF'} || $SiteDefs::SITE_LOGO_HREF;
  $self->print_image = $style->{'PRINT_LOGO'};
}

1;

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

package EnsEMBL::Web::Document::HTML::WhatsNew;

### This module uses our blog's RSS feed to create a list of headlines
### Note that the RSS XML is cached to avoid saturating our blog's bandwidth! 

use strict;

use base qw(EnsEMBL::Web::Document::HTML);

sub render {
  my $self  = shift;
  my $sd    = $self->hub->species_defs;

  my $html = sprintf '<h2 class="box-header">%s %s Release %s (%s)</h2>', $sd->ENSEMBL_SITETYPE, 
                $sd->ENSEMBL_SUBTYPE, $sd->ENSEMBL_VERSION, $sd->ENSEMBL_RELEASE_DATE;

  ## Static headlines
  $html .= EnsEMBL::Web::Controller::SSI::template_INCLUDE($self, "/ssi/whatsnew.html");
  
  ## Link to release news on blog
  $html .= qq(<p class="right"><a href="http://www.ensembl.info/category/01-release/">More release news</a> on our blog</p>); 

  ## Rapid Release panel
  unless ($sd->ENSEMBL_SUBTYPE eq 'GRCh37') {
    $html .= EnsEMBL::Web::Controller::SSI::template_INCLUDE($self, "/ssi/rapid_release.html");
  }
  
  return $html;
}

1;

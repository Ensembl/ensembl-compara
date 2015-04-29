=head1 LICENSE

Copyright [1999-2015] Wellcome Trust Sanger Institute and the EMBL-European Bioinformatics Institute

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

# Constructs the html needed to launch jalview for fasta and nh file urls

package EnsEMBL::Web::ZMenu::Jalview;

use URI::Escape qw(uri_unescape);

use base qw(EnsEMBL::Web::ZMenu);

sub content {
  my $self     = shift;
  my $hub      = $self->hub;
  my $url_site = $hub->species_defs->ENSEMBL_BASE_URL;
  my $html     = sprintf(
    '<applet code="jalview.bin.JalviewLite" width="140" height="35" archive="%s/jalview/jalviewApplet.jar">
      <param name="file" value="%s" />
      <param name="treeFile" value="%s" />
      <param name="sortByTree" value="true" />
      <param name="showFullId" value="false" />
      <param name="defaultColour" value="clustal" />
      <param name="showSequenceLogo" value="true" />
      <param name="showGroupConsensus" value="true" />
      <param name="nojmol" value="true" />
      <param name="application_url" value="http://www.jalview.org/services/launchApp" />
    </applet>', 
    $url_site, 
    $url_site . uri_unescape($hub->param('file')),
    $url_site . uri_unescape($hub->param('treeFile'))
  );
  
  $self->add_entry({
    type       => 'View Sub-tree',
    label      => '[Requires Java]',
    label_html => $html
  });
}

1;

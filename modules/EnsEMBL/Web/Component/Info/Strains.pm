=head1 LICENSE

Copyright [1999-2015] Wellcome Trust Sanger Institute and the EMBL-European Bioinformatics Institute
Copyright [2016] EMBL-European Bioinformatics Institute

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

package EnsEMBL::Web::Component::Info::Strains;

use strict;
use warnings;
no warnings "uninitialized";

use EnsEMBL::Web::Document::Table;

use base qw(EnsEMBL::Web::Component);

sub _init {
  my $self = shift;
  $self->cacheable( 0 );
  $self->ajaxable(  0 );
}


sub content {
  my $self  = shift;
  my $hub   = $self->hub;
  my $sd    = $hub->species_defs;
  my $html;

  $html .= sprintf '<h1>%s strains</h1>', $sd->SPECIES_COMMON_NAME;

  my $strains = $sd->ALL_STRAINS || [];
  if (scalar @$strains) {
    my $columns = [];
    my $table = EnsEMBL::Web::Document::Table->new([      
        { key => 'strain',      title => 'Strain',          width => '30%', align => 'left', sort => 'html'   },
        { key => 'species',     title => 'Scientific name', width => '30%', align => 'left', sort => 'string' },
        { key => 'assembly',    title => 'Ensembl Assembly',width => '20%', align => 'left' },
        { key => 'accession',   title => 'Accession',       width => '20%', align => 'left' },
      ], [], { data_table => 1, exportable => 1 }
    );

    my $ref_samples   = $sd->SAMPLE_DATA;
    my $ref_location  = $ref_samples->{'LOCATION_PARAM'}; 

    foreach my $strain (@$strains) {
      my $sample_data = $sd->get_config($strain, 'SAMPLE_DATA');
      my $location    = $sample_data->{'LOCATION_PARAM'} || $ref_location;
      my $url         = $hub->url({
                                    'species' => $strain,
                                    'type'    => 'Location',
                                    'action'  => 'View',
                                    'r'       => $location,
                                  });

      my $link    = sprintf('<a href="%s">View example location</a>', $url);
      my $species_badge = sprintf '<img src="/i/species/48/%s.png" alt="icon" style="float:left;padding-right:4px;" /><span class="bigtext">%s</span><br />%s', $strain, $sd->get_config($strain, 'SPECIES_COMMON_NAME'), $link; 

      $table->add_row({
                        'strain'    => $species_badge,
                        'species'   => $sd->get_config($strain, 'SPECIES_SCIENTIFIC_NAME'),
                        'assembly'  => $sd->get_config($strain, 'ASSEMBLY_NAME'),
                        'accession' => $sd->get_config($strain, 'ASSEMBLY_ACCESSION'),
                      });
    }

    $html .= $table->render;
  }
  else {
    $html = "<p>Sorry, couldn't find any strains for this species.</p>";
  }

  return $html;
}

1;

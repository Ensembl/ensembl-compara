=head1 LICENSE

Copyright [1999-2015] Wellcome Trust Sanger Institute and the EMBL-European Bioinformatics Institute
Copyright [2016-2018] EMBL-European Bioinformatics Institute

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

use EnsEMBL::Web::Controller::SSI;
use EnsEMBL::Web::Document::Table;
use EnsEMBL::Web::Utils::FormatText;

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

  my $strain_type = $sd->STRAIN_TYPE;
  my $name = $sd->USE_COMMON_NAMES ? $sd->SPECIES_DISPLAY_NAME : $sd->SPECIES_SCIENTIFIC_NAME;
  $html .= sprintf '<h1>%s %s</h1>', $name, pluralise($strain_type);

  $html .= EnsEMBL::Web::Controller::SSI::template_INCLUDE($self, sprintf('/%s_strains.inc', $hub->species), 1);

  my $strains = $sd->ALL_STRAINS || [];
  if (scalar @$strains) {
    my $columns = [
        { key => 'strain',      title => ucfirst $strain_type, width => '30%', align => 'left', sort => 'html'   },
        { key => 'species',     title => 'Scientific name', width => '20%', align => 'left', sort => 'string' },
        { key => 'assembly',    title => 'Ensembl Assembly',width => '15%', align => 'left' },
        { key => 'accession',   title => 'Accession',       width => '15%', align => 'left' },
        { key => 'more',        title => 'More information', width => '20%', align => 'left' },
    ];
    my $table = EnsEMBL::Web::Document::Table->new($columns, [], { data_table => 1, exportable => 1 });

    my $ref_samples   = $sd->SAMPLE_DATA;
    my $ref_location  = $ref_samples->{'LOCATION_PARAM'}; 

    foreach my $strain (@$strains) {
      my $sample_data = $sd->get_config($strain, 'SAMPLE_DATA');
      my $location    = $sample_data->{'LOCATION_PARAM'} || $ref_location;
      my $loc_url     = $hub->url({
                                    'species' => $strain,
                                    'type'    => 'Location',
                                    'action'  => 'View',
                                    'r'       => $location,
                                  });

      my $kar_url     = $hub->url({
                                    'species' => $strain,
                                    'type'    => 'Location',
                                    'action'  => 'Genome',
                                  });

      my $link    = sprintf('<a href="%s">View example location</a> | <a href="%s">Karyotype and statistics</a>', $loc_url, $kar_url);
      my $image       = $sd->get_config($strain, 'SPECIES_IMAGE');
      my $species_badge = sprintf '<img src="/i/species/%s.png" alt="icon" class="badge-48" style="float:left;padding-right:4px;" /><span class="bigtext">%s</span><br />%s', $image, $sd->get_config($strain, 'SPECIES_DISPLAY_NAME'), $link; 

      ## Link to Jackson Labs for mouse strains
      my $info_link;
      my $jax_id = $sd->get_config($strain, 'JAX_ID');
      if ($jax_id) {
        $info_link = $hub->get_ExtURL_link("Strain datasheet (Jackson Labs)", 'JAX_STRAINS', { ID => $jax_id });
      }

      $table->add_row({
                        'strain'    => $species_badge,
                        'species'   => $sd->get_config($strain, 'SPECIES_SCIENTIFIC_NAME'),
                        'assembly'  => $sd->get_config($strain, 'ASSEMBLY_NAME'),
                        'accession' => $sd->get_config($strain, 'ASSEMBLY_ACCESSION'),
                        'more'      => $info_link,
                      });
    }

    $html .= $table->render;
  }
  else {
    $html = "<p>Sorry, couldn't find any ${strain_type}s for this species.</p>";
  }

  return $html;
}

1;

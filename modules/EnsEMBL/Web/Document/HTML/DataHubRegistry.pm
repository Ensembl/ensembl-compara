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

package EnsEMBL::Web::Document::HTML::DataHubRegistry;

### Renders the content of the  "Find a species page" linked to from the SpeciesList module

use strict;

use EnsEMBL::Web::Document::Table;

use base qw(EnsEMBL::Web::Document::HTML);

sub render {
  my ($self, $request) = @_;

  my $hub           = $self->hub;
  my $species_defs  = $hub->species_defs;
  my $sitename      = $species_defs->ENSEMBL_SITETYPE;
  my $static_server = $species_defs->ENSEMBL_STATIC_SERVER;

  ## Get current Ensembl species
  my @valid_species = $species_defs->valid_species;

  my %datahubs;
  my $has_grch37;
  foreach my $sp (@valid_species) {
    my $sp_hubs = $species_defs->get_config($sp, 'PUBLIC_DATAHUBS');
    if (keys %{$sp_hubs||{}}) {
      while (my($key,$menu) = each (%$sp_hubs)) {
        my %config = %{$species_defs->get_config($sp, $key)||{}};
        next unless keys %config;
        $has_grch37++ if $config{'assembly'} eq 'GRCh37';
        $config{'priority'} = 0 unless $config{'priority'};
        $datahubs{$key} = {'menu' => $menu, %config};
        if ($datahubs{$key}{'species'}) {
          push @{$datahubs{$key}{'species'}}, {'dir' => $sp, 'common' => $species_defs->get_config($sp, 'SPECIES_COMMON_NAME')};
        }
        else {
          $datahubs{$key}{'species'} = [{'dir' => $sp, 'common' => $species_defs->get_config($sp, 'SPECIES_COMMON_NAME')}];
        }
      }
    }
  }
  my @order = sort { $datahubs{$b}->{'priority'} <=> $datahubs{$a}->{'priority'} 
                    || $datahubs{$a}->{'name'} cmp $datahubs{$b}->{'name'}
                    } keys %datahubs;

  my $html;
  
  $html .= '<p>IMPORTANT NOTE: Human assembly GRCh37 is no longer available in the main Ensembl release. The links below will take you to our long-term archive,
<a href="">grch37.ensembl.org</a>.</p>' if $has_grch37;

  my $table = EnsEMBL::Web::Document::Table->new([
      { key => 'name',     title => 'Datahub name', width => '30%', align => 'left', sort => 'html' },
      { key => 'description',    title => 'Description', width => '30%', align => 'left', sort => 'string' },
      { key => 'species',      title => 'Species and assembly', width => '40%', align => 'left', sort => 'html' },
  ], [], { data_table => 1, exportable => 1 });


  foreach my $key (@order) {
    my $hub_info = $datahubs{$key};
    my @species_links;
    foreach my $sp_info (@{$hub_info->{'species'}}) {
      my $location = $species_defs->get_config($sp_info->{'dir'}, 'SAMPLE_DATA')->{'LOCATION_PARAM'};
      my $site = ($sp_info->{'dir'} eq 'Homo_sapiens' && $hub_info->{'assembly'} eq 'GRCh37') ? 'http://grch37.ensembl.org' : '';
      my $link = sprintf('%s/%s/Location/View?r=%s;contigviewbottom=url:%s;format=DATAHUB;menu=%s',
                        $site, $sp_info->{'dir'}, $location,
                        $hub_info->{'url'}, $hub_info->{'menu'}
                        );
      my $text = sprintf('<a href="%s"><img src="/i/species/16/%s.png" alt="%s" style="float:left;padding-right:4px" /></a> <a href="%s">%s (%s)</a>', 
                          $link, $sp_info->{'dir'}, $sp_info->{'common'}, 
                          $link, $sp_info->{'common'}, $hub_info->{'assembly'},
                        );
      push @species_links, $text;
    } 
    $table->add_row({
              'name'        => $hub_info->{'name'},
              'description' => $hub_info->{'description'},
              'species'     => join('<br/>', @species_links),
    });
  }

  $html .= $table->render;
  $html .= '</div>';
  return $html;  
}

1;

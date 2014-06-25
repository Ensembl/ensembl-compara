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
use EnsEMBL::Web::DBSQL::ArchiveAdaptor;

use base qw(EnsEMBL::Web::Document::HTML);

sub render {
  my ($self, $request) = @_;

  my $hub           = $self->hub;
  my $species_defs  = $hub->species_defs;
  my $sitename      = $species_defs->ENSEMBL_SITETYPE;
  my $adaptor       = EnsEMBL::Web::DBSQL::ArchiveAdaptor->new($hub); 

  ## Get current Ensembl species
  my @valid_species = $species_defs->valid_species;

  my %datahubs;
  foreach my $sp (@valid_species) {
    ## This is all a bit hacky, but makes configuration of multi-species datahubs simpler
    my %sp_hubs = (%{$species_defs->get_config($sp, 'PUBLIC_DATAHUBS')||{}}, $species_defs->multiX('PUBLIC_MULTISPECIES_DATAHUBS'));
    if (keys %sp_hubs) {
      while (my($key,$menu) = each (%sp_hubs)) {
        ## multiX returns a hash, not a hash ref, and Perl gets confused
        ## if you try to assign hashes and hashrefs to same variable
        my %multi = $species_defs->multiX($key);
        my %config = keys %multi ? %multi : %{$species_defs->get_config($sp, $key)||{}};
        next unless keys %config;
        my %assemblies = $config{'assemblies'} ? @{$config{'assemblies'}} : ($sp => $config{'assembly'});
        $config{'priority'} = 0 unless $config{'priority'};
        $datahubs{$key} = {'menu' => $menu, %config};
        while (my ($sp, $assembly) = each (%assemblies)) {
          if ($datahubs{$key}{'species'}) {
            push @{$datahubs{$key}{'species'}}, {'dir' => $sp, 'common' => $species_defs->get_config($sp, 'SPECIES_COMMON_NAME'), 'assembly' => $assembly};
          }
          else {
            $datahubs{$key}{'species'} = [{'dir' => $sp, 'common' => $species_defs->get_config($sp, 'SPECIES_COMMON_NAME'), 'assembly' => $assembly}];
          }
        }
      }
    }
  }

  my @order = sort { $datahubs{$b}->{'priority'} <=> $datahubs{$a}->{'priority'} 
                    || lc($datahubs{$a}->{'name'}) cmp lc($datahubs{$b}->{'name'})
                    } keys %datahubs;

  my $html;
  
  my $table = EnsEMBL::Web::Document::Table->new([
      { key => 'name',     title => 'Datahub name', width => '30%', align => 'left', sort => 'html' },
      { key => 'description',    title => 'Description', width => '30%', align => 'left', sort => 'string' },
      { key => 'species',      title => 'Species and assembly', width => '40%', align => 'left', sort => 'html' },
  ], [], {});

  foreach my $key (@order) {
    my $hub_info = $datahubs{$key};
    my (@species_links, $species_html);
    foreach my $sp_info (@{$hub_info->{'species'}}) {
      my $species = $sp_info->{'dir'};

      my $site = '';
      if ($species_defs->multidb->{'DATABASE_ARCHIVE'}{'NAME'}) {
        ## Get best archive for older releases
        my $archive_version = $species_defs->ENSEMBL_VERSION;
        ## Spaces are problematic in ini file arrays
        (my $assembly_name = $species_defs->get_config($species, 'ASSEMBLY_NAME')) =~ s/ /_/; 
        unless ($assembly_name =~ /$sp_info->{'assembly'}/i) {
          if ($species eq 'Homo_sapiens' && $sp_info->{'assembly'} eq 'GRCh37') {
            $site = 'http://grch37.ensembl.org'; 
          }
          else {
            my $archives = $adaptor->fetch_archives_by_species($species);
            foreach (reverse sort keys %$archives) {
              (my $assembly = $archives->{$_}{'assembly'}) =~ s/ /_/; 
              if ($assembly =~ /$sp_info->{'assembly'}/i) {
                $archive_version = $_;
                $site = sprintf('http://%s.archive.ensembl.org', $archives->{$_}{'archive'});
                last;
              }
            }
          }
        }
        ## Don't link back to archives with no datahub support!
        next if $archive_version < 69;
      }

      my $location = $species_defs->get_config($species, 'SAMPLE_DATA')->{'LOCATION_PARAM'};
      my $link = sprintf('%s/%s/Location/View?r=%s;contigviewbottom=url:%s;format=DATAHUB;menu=%s#modal_config_viewbottom-%s',
                        $site, $sp_info->{'dir'}, $location,
                        $hub_info->{'url'}, $hub_info->{'menu'}, $hub_info->{'menu'}
                        );
      $species_html .= sprintf('<p><a href="%s"><img src="/i/species/16/%s.png" alt="%s" style="float:left;padding-right:4px" /></a> <a href="%s">%s (%s)</a></p>', 
                          $link, $sp_info->{'dir'}, $sp_info->{'common'}, 
                          $link, $sp_info->{'common'}, $sp_info->{'assembly'},
                        );
    } 
    $table->add_row({
              'name'        => $hub_info->{'name'},
              'description' => $hub_info->{'description'},
              'species'     => $species_html,
    });
  }

  $html .= $table->render;
  $html .= '</div>';
  return $html;  
}

1;

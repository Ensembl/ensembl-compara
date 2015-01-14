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

package EnsEMBL::Web::Configuration::Info;

use strict;

use EnsEMBL::Web::Constants;

use base qw(EnsEMBL::Web::Configuration);

sub set_default_action {
  my $self = shift;
  $self->{'_data'}{'default'} = 'Index';
}

sub caption { 
  my $self         = shift;
  my $hub          = $self->hub;
  my $species_defs = $hub->species_defs;
  my $species      = $hub->species;
  my $path         = $hub->species_path;
  my $sound        = $species_defs->SAMPLE_DATA->{'ENSEMBL_SOUND'};
  my ($heading, $subhead);

  $heading .= qq(<a href="$path"><img src="/i/species/48/$species.png" class="species-img float-left" alt="" title="$sound" /></a>);
  my $common_name = $species_defs->SPECIES_COMMON_NAME;
  if ($common_name =~ /\./) {
    $heading .= $species_defs->SPECIES_BIO_NAME;
  }
  else {
    $heading .= $common_name;
    $subhead = '('.$species_defs->SPECIES_BIO_NAME.')';
  }
  return [$heading, $subhead];
}

sub short_caption { return 'About this species'; }

sub availability {
  my $self = shift;
  my $hash = $self->get_availability;
  $hash->{'database.variation'} = exists $self->hub->species_defs->databases->{'DATABASE_VARIATION'} ? 1 : 0;
  return $hash;
}

sub populate_tree {
  my $self           = shift;
  my $species_defs   = $self->hub->species_defs;
  my %error_messages = EnsEMBL::Web::Constants::ERROR_MESSAGES;

  my $index = $self->create_node('Index', '',
    [qw(homepage EnsEMBL::Web::Component::Info::HomePage)],
    { title => 'Description' }
  );

  $self->create_node('Annotation', '',
    [qw(blurb EnsEMBL::Web::Component::Info::SpeciesBlurb)]
  );

  $index->append($self->create_subnode('Error', 'Unknown error',
    [qw(error EnsEMBL::Web::Component::Info::SpeciesBurp)],
    { no_menu_entry => 1, }
  ));
  
  foreach (keys %error_messages) {
    $index->append($self->create_subnode("Error/$_", "Error $_",
      [qw(error EnsEMBL::Web::Component::Info::SpeciesBurp)],
      { no_menu_entry => 1 }
    ));
  }

  $self->create_node('Expression', 'Gene Expression',
    [qw(
      rnaseq_table  EnsEMBL::Web::Component::Info::ExpressionTable
    )],
    { 'availability' => 'database:rnaseq' }
  );

  my $stats_menu = $self->create_submenu('Stats', 'Genome Statistics');
  
  $stats_menu->append($self->create_node('StatsTable', 'Assembly and Genebuild',
    [qw(stats EnsEMBL::Web::Component::Info::SpeciesStats)]
  ));
  
  $stats_menu->append($self->create_node('IPtop500', 'Top 500 InterPro hits',
    [qw(ip500 EnsEMBL::Web::Component::Info::IPtop500)]
  ));
  $self->create_node('WhatsNew', '',
    [qw(whatsnew EnsEMBL::Web::Component::Info::WhatsNew)]
  );

  ## SAMPLE DATA
  my $sample_data  = $species_defs->SAMPLE_DATA;
  my $species_path = $species_defs->species_path($self->species);
  
  if ($sample_data && keys %$sample_data) {
    my $data_menu       = $self->create_submenu('Data', 'Sample entry points');
    my $karyotype_url   = $sample_data->{'KARYOTYPE_PARAM'} ? "$species_path/Location/Genome?r=$sample_data->{'KARYOTYPE_PARAM'}" : "$species_path/Location/Genome?r=$sample_data->{'LOCATION_PARAM'}";
    my $location_url    = "$species_path/Location/View?r=$sample_data->{'LOCATION_PARAM'}";
    my $gene_url        = "$species_path/Gene/Summary?g=$sample_data->{'GENE_PARAM'}";
    my $transcript_url  = "$species_path/Transcript/Summary?t=$sample_data->{'TRANSCRIPT_PARAM'}";
    my $karyotype_text  = scalar @{$species_defs->ENSEMBL_CHROMOSOMES || []} ? 'Karyotype' : 'Karyotype (not available)';
    my $location_text   = $sample_data->{'LOCATION_TEXT'}   || 'not available';
    my $gene_text       = $sample_data->{'GENE_TEXT'}       || 'not available';
    my $transcript_text = $sample_data->{'TRANSCRIPT_TEXT'} || 'not available';
    
    $data_menu->append($self->create_node('Karyotype', $karyotype_text, [],
      { availability => scalar @{$species_defs->ENSEMBL_CHROMOSOMES || []}, url => $karyotype_url }
    ));

    $data_menu->append($self->create_node('Location', "Location ($location_text)", [],
      { url => $location_url, raw => 1 }
    ));
    
    $data_menu->append($self->create_node('Gene', "Gene ($gene_text)", [],
      { url => $gene_url, raw => 1 }
    ));
    
    $data_menu->append( $self->create_node('Transcript', "Transcript ($transcript_text)", [],
      { url => $transcript_url, raw => 1 }
    ));
    
    if ($sample_data->{'VARIATION_PARAM'}) {
      my $variation_url  = "$species_path/Variation/Explore?v=$sample_data->{'VARIATION_PARAM'}";
      my $variation_text = $sample_data->{'VARIATION_TEXT'} || 'not available';
      
      $data_menu->append($self->create_node('Variation', "Variation ($variation_text)", [],
        { url => $variation_url, raw => 1 }
      ));
    }

    if ($sample_data->{'PHENOTYPE_PARAM'}) {
      my $phenotype_url  = "$species_path/Phenotype/Locations?ph=$sample_data->{'PHENOTYPE_PARAM'}";
      my $phenotype_text = $sample_data->{'PHENOTYPE_TEXT'} || 'not available';
      
      $data_menu->append($self->create_node('Phenotype', "Phenotype ($phenotype_text)", [],
        { url => $phenotype_url, raw => 1 }
      ));
    }

    if ($sample_data->{'REGULATION_PARAM'}){
      my $regulation_url  = "$species_path/Regulation/Summary?fdb=funcgen;rf=$sample_data->{'REGULATION_PARAM'}";
      my $regulation_text = $sample_data->{'REGULATION_TEXT'} || 'not_available';

      $data_menu->append($self->create_node('Regulation', "Regulation ($regulation_text)", [],
        { url => $regulation_url, raw => 1 }
      ));
    }  
  }

  ## Generic node for including arbitrary HTML files about a species
  $self->create_node('Content', '',
    [qw(content EnsEMBL::Web::Component::Info::Content)]
  );
}

1;

# $Id$

package EnsEMBL::Web::Configuration::Info;

use strict;

use EnsEMBL::Web::Constants;

use base qw(EnsEMBL::Web::Configuration);

sub set_default_action {
  my $self = shift;
  $self->{'_data'}{'default'} = 'Index';
}

sub caption { 
  my $self = shift;
  my $species_defs = $self->hub->species_defs;
  return sprintf 'Search %s %s', $species_defs->ENSEMBL_SITETYPE, $species_defs->SPECIES_COMMON_NAME;
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

  my $index = $self->create_node('Index', 'Description',
    [qw(blurb EnsEMBL::Web::Component::Info::SpeciesBlurb)],
    { availability => 1 }
  );
  
  $index->append($self->create_subnode('Error', 'Unknown error',
    [qw(error EnsEMBL::Web::Component::Info::SpeciesBurp)],
    { availability  => 1, no_menu_entry => 1, }
  ));
  
  
  foreach (keys %error_messages) {
    $index->append($self->create_subnode("Error/$_", "$_ error: $error_messages{$_}->[0]",
      [qw(error EnsEMBL::Web::Component::Info::SpeciesBurp)],
      { availability  => 1, no_menu_entry => 1 }
    ));
  }

  my $stats_menu = $self->create_submenu('Stats', 'Genome Statistics');
  
  $stats_menu->append($self->create_node('StatsTable', 'Assembly and Genebuild',
    [qw(stats EnsEMBL::Web::Component::Info::SpeciesStats)],
    { availability => 1 }
  ));
  
  $stats_menu->append($self->create_node('IPtop40', 'Top 40 InterPro hits',
    [qw(ip40  EnsEMBL::Web::Component::Info::IPtop40)],
    { availability => 1}
  ));
  
  $stats_menu->append($self->create_node('IPtop500', 'Top 500 InterPro hits',
    [qw(ip500 EnsEMBL::Web::Component::Info::IPtop500)],
    { availability => 1 }
  ));

  $self->create_node('WhatsNew', "What's New",
    [qw(whatsnew EnsEMBL::Web::Component::Info::WhatsNew)],
    { availability => 1 }
  );

  ## SAMPLE DATA
  my $sample_data  = $species_defs->SAMPLE_DATA;
  my $species_path = $species_defs->species_path($self->species);
  
  if ($sample_data && keys %$sample_data) {
    my $data_menu       = $self->create_submenu('Data', 'Sample entry points');
    my $karyotype_url   = $sample_data->{'KARYOTYPE_PARAM'} ? "$species_path/Location/Genome?r=$sample_data->{'KARYOTYPE_PARAM'}" : "$species_path/Location/Genome";
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
      { availability => 1, url => $location_url, raw => 1 }
    ));
    
    $data_menu->append($self->create_node('Gene', "Gene ($gene_text)", [],
      { availability => 1, url => $gene_url, raw => 1 }
    ));
    
    $data_menu->append( $self->create_node('Transcript', "Transcript ($transcript_text)", [],
      { availability => 1, url => $transcript_url, raw => 1 }
    ));
    
    if ($sample_data->{'VARIATION_PARAM'}) {
      my $variation_url  = "$species_path/Variation/Summary?v=$sample_data->{'VARIATION_PARAM'}";
      my $variation_text = $sample_data->{'VARIATION_TEXT'} || 'not available';
      
      $data_menu->append($self->create_node('Variation', "Variation ($variation_text)", [],
        { availability => 1, url => $variation_url, raw => 1 }
      ));
    }

    if ($sample_data->{'REGULATION_PARAM'}){
      my $regulation_url  = "$species_path/Regulation/Cell_line?fdb=funcgen;rf=$sample_data->{'REGULATION_PARAM'}";
      my $regulation_text = $sample_data->{'REGULATION_TEXT'} || 'not_available';

      $data_menu->append($self->create_node('Regulation', "Regulation ($regulation_text)", [],
        { availability => 1, url => $regulation_url, raw => 1 }
      ));
    }  
  }

  $self->create_node('Content', '',
    [qw(content EnsEMBL::Web::Component::Info::Content)],
    { no_menu_entry => 1 }
  );
}

1;

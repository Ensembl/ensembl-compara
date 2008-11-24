package EnsEMBL::Web::Configuration::Info;

use strict;
use EnsEMBL::Web::Apache::Error;
use base qw( EnsEMBL::Web::Configuration );

sub set_default_action {
  my $self = shift;
  $self->{_data}{default} = 'Index';
}

sub global_context { return undef; }
sub ajax_content   { return undef;   }
sub local_context  { return $_[0]->_local_context;  }
sub local_tools    { return $_[0]->_local_tools;  }
sub content_panel  { return $_[0]->_content_panel;  }
sub context_panel  { return $_[0]->_context_panel(1);  } ## RAW AS CONTAINS <i> tags

sub populate_tree {
  my $self   = shift;
  my $object = $self->object;
  my $sd     = $object->species_defs;

  my $index = $self->create_node( 'Index', "Description",
    [qw(blurb    EnsEMBL::Web::Component::Info::SpeciesBlurb)],
    { 'availability' => 1}
  );

  my $error_messages = \%EnsEMBL::Web::Apache::Error::error_messages;
  $index->append($self->create_subnode( "Error", "Unknown error",
    [qw(error EnsEMBL::Web::Component::Info::SpeciesBurp)],
    { availability  => 1, no_menu_entry => 1, }
  ));

  while (my ($code,$message) = each %$error_messages) {
    $index->append($self->create_subnode( "Error/$code", "$code error: $message->[0]",
      [qw(error EnsEMBL::Web::Component::Info::SpeciesBurp)],
      {
        availability  => 1,
        no_menu_entry => 1,
      }
    ));
  }

  my $stats_menu = $self->create_submenu( 'Stats', 'Genome Statistics' );
  $stats_menu->append( $self->create_node( 'StatsTable', 'Assembly and Genebuild',
    [qw(stats     EnsEMBL::Web::Component::Info::SpeciesStats)],
    { 'availability' => 1}
  ));
  $stats_menu->append( $self->create_node( 'IPtop40', 'Top 40 InterPro hits',
    [qw(ip40     EnsEMBL::Web::Component::Info::IPtop40)],
    { 'availability' => 1}
  ));
  $stats_menu->append( $self->create_node( 'IPtop500', 'Top 500 InterPro hits',
    [qw(ip500     EnsEMBL::Web::Component::Info::IPtop500)],
    { 'availability' => 1}
  ));

  $self->create_node( 'WhatsNew', "What's New",
    [qw(whatsnew    EnsEMBL::Web::Component::Info::WhatsNew)],
    { 'availability' => 1}
  );

  $self->create_node( 'Content', "",
    [qw(content    EnsEMBL::Web::Component::Info::Content)],
    { 'no_menu_entry' => 1}
  );

  ## SAMPLE DATA
  my $sample_data = $sd->SAMPLE_DATA;
  my $species_path = $self->species;
  if($sample_data && keys %$sample_data) {
    my $data_menu = $self->create_submenu( 'Data', 'Sample entry points' );

    my $location_url    = "/$species_path/Location/View?r=".$sample_data->{'LOCATION_PARAM'};
    my $location_text   = $sample_data->{'LOCATION_TEXT'} || 'not available';
    my $loc_available   = $location_text eq 'not available' ? 0 : 1;

    my $gene_url        = "/$species_path/Gene/Summary?g=".$sample_data->{'GENE_PARAM'};
    my $gene_text       = $sample_data->{'GENE_TEXT'} || 'not available';
    my $gene_available  = $gene_text eq 'not available' ? 0 : 1;

    my $transcript_url  = "/$species_path/Transcript/Summary?t=".$sample_data->{'TRANSCRIPT_PARAM'};
    my $transcript_text = $sample_data->{'TRANSCRIPT_TEXT'} || 'not available';
    my $trans_available = $transcript_text eq 'not available' ? 0 : 1;

    my $karyotype = scalar(@{$sd->ENSEMBL_CHROMOSOMES||[]}) ? 'Karyotype' : 'Karyotype (not available)';

    $data_menu->append( $self->create_node( 'Karyotype', $karyotype,
      [qw(location      EnsEMBL::Web::Component::Location::Genome)],
      { 'availability' => scalar(@{$sd->ENSEMBL_CHROMOSOMES||[]}),
        'url' => '/'.$self->species.'/Location/Genome' }
    ));
    $data_menu->append( $self->create_node( 'Location', "Location ($location_text)",
      [qw(location      EnsEMBL::Web::Component::Location::Summary)],
      { 'availability' => $loc_available, 'url' => $location_url, 'raw' => 1 }
    ));
    $data_menu->append( $self->create_node( 'Gene', "Gene ($gene_text)",
      [],
      { 'availability' => $gene_available, 'url' => $gene_url, 'raw' => 1 }
    ));
    $data_menu->append( $self->create_node( 'Transcript', "Transcript ($transcript_text)",
      [qw(location      EnsEMBL::Web::Component::Transcript::Summary)],
      { 'availability' => $trans_available, 'url' => $transcript_url, 'raw' => 1 }
    ));

  }
}

1;

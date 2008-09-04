package EnsEMBL::Web::Configuration::Info;

use strict;
use base qw( EnsEMBL::Web::Configuration );

sub set_default_action {
  my $self = shift;
  $self->{_data}{default} = 'Description';
}

sub global_context { return undef; }
sub ajax_content   { return undef;   }
sub local_context  { return $_[0]->_local_context;  }
sub local_tools    { return undef;  }
sub content_panel  { return $_[0]->_content_panel;  }
sub context_panel  { return $_[0]->_context_panel;  }

sub populate_tree {
  my $self = shift;

  $self->create_node( 'Description', "Description",
    [qw(
      blurb    EnsEMBL::Web::Component::Info::SpeciesBlurb
    )],
    { 'availability' => 1}
  );
  $self->create_node( 'Stats', 'Genome Statistics',
    [qw(
      stats     EnsEMBL::Web::Component::Info::SpeciesStats
    )],
    { 'availability' => 1}
  );
  $self->create_node( 'WhatsNew', "What's New",
    [qw(
      whatsnew    EnsEMBL::Web::Component::Info::WhatsNew
    )],
    { 'availability' => 1}
  );
  ## SAMPLE DATA
  my $data_menu = $self->create_submenu( 'Data', 'Sample entry points' );
  my %sample_data = %{$self->{object}->species_defs->SAMPLE_DATA};
  my $location_url    = '/'.$self->species.'/Location/Summary?r='.$sample_data{'LOCATION_PARAM'};
  my $location_text   = $sample_data{'LOCATION_TEXT'};
  my $gene_url        = '/'.$self->species.'/Gene/Summary?r='.$sample_data{'GENE_PARAM'};
  my $gene_text       = $sample_data{'GENE_TEXT'};
  my $transcript_url  = '/'.$self->species.'/Transcript/Summary?r='.$sample_data{'TRANSCRIPT_PARAM'};
  my $transcript_text = $sample_data{'TRANSCRIPT_TEXT'};
  my $karyotype = scalar(@{$self->{object}->species_defs->ENSEMBL_CHROMOSOMES||[]}) ? 'Karyotype' : 'Karyotype (not available)';
  $data_menu->append( $self->create_node( 'Karyotype', $karyotype,
    [qw(location      EnsEMBL::Web::Component::Location::Karyotype)],
    { 'availability' => scalar(@{$self->{object}->species_defs->ENSEMBL_CHROMOSOMES||[]}), 
      'url' => '/'.$self->species.'/Location/Karyotype' }
  ));
  $data_menu->append( $self->create_node( 'Location', "Location ($location_text)",
    [qw(location      EnsEMBL::Web::Component::Location::Summary)],
    { 'availability' => 1, 'url' => $location_url }
  ));
  $data_menu->append( $self->create_node( 'Gene', "Gene ($gene_text)",
    [],
    { 'availability' => 1, 'url' => $gene_url }
  ));
  $data_menu->append( $self->create_node( 'Transcript', "Transcript ($transcript_text)",
    [qw(location      EnsEMBL::Web::Component::Transcript::Summary)],
    { 'availability' => 1, 'url' => $transcript_url }
  ));

  ## Menu also needs to link to any static content for this species
}

1;

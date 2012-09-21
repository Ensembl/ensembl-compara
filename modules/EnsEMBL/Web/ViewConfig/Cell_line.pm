# $Id$

package EnsEMBL::Web::ViewConfig::Cell_line;

use strict;

use base qw(EnsEMBL::Web::ViewConfig::Matrix);

sub init {
  my $self = shift;
  
  
  my $funcgen_tables = $self->species_defs->databases->{'DATABASE_FUNCGEN'}{'tables'};
  my $cell_lines     = $funcgen_tables->{'cell_type'}{'ids'};
  
  return $self->SUPER::init unless scalar keys %$cell_lines;
  
  my $evidence_features = $funcgen_tables->{'feature_type'}{'ids'};
  my $defaults;
  
  my %default_evidence_types = (
    CTCF     => 1,
    DNase1   => 1,
    H3K4me3  => 1,
    H3K36me3 => 1,
    H3K27me3 => 1,
    H3K9me3  => 1,
    PolII    => 1,
    PolIII   => 1,
  );
  
  foreach my $cell_line (keys %$cell_lines) {
    $cell_line =~ s/:\w*//;
    
    foreach my $evidence_type (keys %$evidence_features) {
      my ($name, $id) = split /:/, $evidence_type;
      
      while (my ($set, $conf) = each %{$self->{'matrix_config'}{'regulatory_features'}}) {
        if (exists $conf->{'features'}{$cell_line}{$id}) {
          $conf->{'features'}{$cell_line}{$name} = 1;
          $conf->{'defaults'}{$cell_line}{$name} = exists $default_evidence_types{$name} ? 'on' : 'off';
          delete $conf->{'features'}{$cell_line}{$id};
        }
      }
    }
  }
  
  $self->SUPER::init;
}

sub set_columns {
  my ($self, $image_config) = @_;
     $image_config   = ref $image_config ? $image_config : $self->hub->get_imageconfig($image_config);
  my $funcgen_tables = $self->species_defs->databases->{'DATABASE_FUNCGEN'}{'tables'};
  
  foreach (grep $_->data->{'set'}, map $_ ? $_->nodes : (), $image_config->get_node('regulatory_features_core'), $image_config->get_node('regulatory_features_other')) {
    my $set       = $_->data->{'set'};
    my $cell_line = $_->data->{'cell_line'};
    my $renderers = $_->get('renderers');
    my %renderers = @$renderers;
    my $conf      = $self->{'matrix_config'}{$_->data->{'menu_key'}}{$set} ||= {
      menu         => "regulatory_features_$set",
      track_prefix => 'reg_feats',
      section      => 'Regulation',
      caption      => $set eq 'core' ? 'Open chromatin & TFBS' : 'Histones & polymerases',
      header       => $set eq 'core' ? 'Open chromatin & Transcription Factor Binding Sites' : 'Histones & Polymerases',
      description  => $funcgen_tables->{'feature_set'}{'analyses'}{'Regulatory_Build'}{'desc'}{$set},
      axes         => { x => 'cell', y => 'evidence type' },
    };
    
    push @{$conf->{'columns'}}, { display => $_->get('display'), renderers => $renderers, x => $cell_line };
    
    $conf->{'features'}{$cell_line} = $self->deepcopy($funcgen_tables->{'regbuild_string'}{'feature_type_ids'}{$cell_line});
    $conf->{'renderers'}{$_}++ for keys %renderers;
  }
  
  $self->SUPER::set_columns($image_config);
}

sub matrix_data {
  my ($self, $menu, $set) = @_;
  
  return $self->SUPER::matrix_data($menu, $set) unless $menu eq 'regulatory_features';
  
  my $adaptor = $self->hub->get_adaptor('get_FeatureTypeAdaptor', 'funcgen');
  
  return map {
    sort { $a->{'id'} cmp $b->{'id'} } map { id => $_->name, class => $_->class }, @{$adaptor->fetch_all_by_class($_)}
  } $set eq 'core' ? ('Open Chromatin', 'Transcription Factor') : qw(Polymerase Histone);
}

1;

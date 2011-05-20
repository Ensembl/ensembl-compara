# $Id$

package EnsEMBL::Web::ImageConfig::regulation_view;

use strict;

use base qw(EnsEMBL::Web::ImageConfig);

sub init {
  my $self         = shift;
  my @feature_sets = ('cisRED', 'VISTA', 'miRanda', 'NestedMICA', 'REDfly CRM', 'REDfly TFBS', 'search');
  my @cell_lines   = sort keys %{$self->species_defs->databases->{'DATABASE_FUNCGEN'}{'tables'}{'cell_type'}{'ids'}};
  
  s/\:\d*// for @cell_lines;
  
  $self->set_parameters({
    title       => 'Details by cell line',
    show_labels => 'yes',
    label_width => 113,
    opt_lines   => 1
  });
  
  $self->create_menus(
    sequence       => 'Sequence',
    transcript     => 'Genes',
    prediction     => 'Prediction transcripts',
    dna_align_rna  => 'RNA alignments',
    oligo          => 'Probe features',
    simple         => 'Simple features',
    misc_feature   => 'Misc. regions',
    repeat         => 'Repeats',
    functional     => 'Regulation', 
    multiple_align => 'Multiple alignments',
    variation      => 'Germline variation',
    other          => '',
    information    => 'Information'
  );
  
  $self->load_tracks;
  
  $self->add_tracks('sequence',
    [ 'contig', 'Contigs', 'stranded_contig', { display => 'normal', strand => 'r' }]
  );
  
  $self->modify_configs(
    [ 'transcript_core_ensembl' ],
    { display => 'collapsed_nolabel' }
  );
  
  $self->modify_configs(
    [ map "regulatory_regions_funcgen_$_", @feature_sets ],
    { menu => 'yes' }
  );
  
  $self->modify_configs(
    [ 'information' ],
    { menu => 'no', display => 'off' }
  );
  
  $self->get_node('opt_empty_tracks')->set('display', 'normal');
  
  foreach my $cell_line (@cell_lines) {
    my $display = $cell_line =~ /^(MultiCell|CD4)$/ ? 'tiling_feature' : 'compact';

    # Turn on reg_feats track
    $self->modify_configs(
      [ "reg_feats_$cell_line" ],
      { display => 'normal', menu => 'yes' }
    );
    
    # Turn on core evidence track
    $self->modify_configs(
      [ "reg_feats_core_$cell_line" ],
      { display => $display , menu => 'yes' }
    );
    
    push @{$self->{'tracks_to_remove'}}, "reg_feats_$cell_line", "reg_feats_core_$cell_line";
    
    next if $cell_line eq 'MultiCell';
    
    # Turn on supporting evidence track
    $self->modify_configs(
      [ "reg_feats_other_$cell_line" ],
      { display => 'compact', menu => 'yes' }
    );
    
    push @{$self->{'tracks_to_remove'}}, "reg_feats_other_$cell_line";
  }
  
  if ($self->{'code'} ne $self->{'type'}) {
    my $func = "init_$self->{'code'}";
    $self->$func if $self->can($func);
  }
}

sub init_top {
  my $self = shift;

  $self->add_tracks('other',
    [ 'scalebar',                 '', 'scalebar',                 { display => 'normal', strand => 'f', menu => 'no', name => 'Scale bar' }],
    [ 'ruler',                    '', 'ruler',                    { display => 'normal', strand => 'f', menu => 'no', name => 'Ruler'     }],
    [ 'fg_background_regulation', '', 'fg_background_regulation', { display => 'normal', strand => 'r', menu => 'no', tag => 0            }],
  );
  
  $self->get_node($_)->remove for @{$self->{'tracks_to_remove'}};
}

sub init_cell_line {
  my $self = shift;
  $self->get_node($_)->remove for 'contig', 'transcript_core_ensembl';
}

sub init_bottom {
  my $self = shift;
  
  $self->add_tracks('other',
    [ 'fg_background_regulation', '', 'fg_background_regulation', { display => 'normal', strand => 'r', menu => 'no', tag => 0            }],
    [ 'scalebar',                 '', 'scalebar',                 { display => 'normal', strand => 'r', menu => 'no', name => 'Scale bar' }],
    [ 'ruler',                    '', 'ruler',                    { display => 'normal', strand => 'r', menu => 'no', name => 'Ruler'     }],
  );
  
  $self->get_node($_)->remove for @{$self->{'tracks_to_remove'}}, 'contig', 'transcript_core_ensembl';
  
  $self->modify_configs(
    [ 'fg_regulatory_features_legend' ],
    { display => 'normal' }
  );
}

1;

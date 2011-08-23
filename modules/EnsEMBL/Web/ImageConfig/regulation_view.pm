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
    opt_lines => 1
  });
  
  $self->create_menus(qw(
    sequence
    transcript
    prediction
    dna_align_rna
    simple
    misc_feature
    functional
    multiple_align
    conservation
    variation
    oligo
    repeat
    other
    information
  ));
  
  $self->load_tracks;
  $self->load_configured_das('functional');
  
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
      { display => 'normal' }
    );
    
    # Turn on core evidence track
    $self->modify_configs(
      [ "reg_feats_core_$cell_line" ],
      { display => $display, menu => 'hidden' }
    );
   
    # Turn on supporting evidence track
    $self->modify_configs(
      [ "reg_feats_other_$cell_line" ],
      { display => 'compact', menu => 'hidden' }
    );
    
    $self->{'reg_feats_tracks'}{$_} = 1 for "reg_feats_$cell_line", "reg_feats_core_$cell_line", "reg_feats_other_$cell_line";
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
  
  $_->remove for map $self->get_node($_) || (), keys %{$self->{'reg_feats_tracks'}};
}

sub init_cell_line {
  my $self = shift;
  $_->remove for grep !$self->{'reg_feats_tracks'}{$_->id}, $self->get_tracks;
  
  $self->add_tracks('other',
    [ 'draggable', '', 'draggable', { display => 'normal', strand => 'b', menu => 'no' }]
  );
}

sub init_bottom {
  my $self = shift;
  
  $_->remove for grep $_->id ne 'fg_regulatory_features_legend', $self->get_tracks;
  
  $self->add_tracks('other',
    [ 'fg_background_regulation', '', 'fg_background_regulation', { display => 'normal', strand => 'r', menu => 'no', tag => 0            }],
    [ 'scalebar',                 '', 'scalebar',                 { display => 'normal', strand => 'r', menu => 'no', name => 'Scale bar' }],
    [ 'ruler',                    '', 'ruler',                    { display => 'normal', strand => 'r', menu => 'no', name => 'Ruler'     }],
  );
  
  $self->modify_configs(
    [ 'fg_regulatory_features_legend' ],
    { display => 'normal' }
  );
}

1;

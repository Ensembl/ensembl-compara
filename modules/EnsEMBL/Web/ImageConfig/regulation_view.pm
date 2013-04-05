# $Id$

package EnsEMBL::Web::ImageConfig::regulation_view;

use strict;

use base qw(EnsEMBL::Web::ImageConfig);

sub cache_key        { return $_[0]->code eq 'cell_line' ? '' : $_[0]->SUPER::cache_key; }
sub load_user_tracks { return $_[0]->SUPER::load_user_tracks($_[1]) unless $_[0]->code eq 'set_evidence_types'; } # Stops unwanted cache tags being added for the main page (not the component)

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
  $self->image_resize = 1;
  
  $self->add_tracks('sequence',
    [ 'contig', 'Contigs', 'contig', { display => 'normal', strand => 'r' }]
  );
  
  $self->modify_configs(
    [ 'transcript_core_ensembl' ],
    { display => 'collapsed_nolabel' }
  );
  
  $self->modify_configs(
    [ 'gene_legend', 'variation_legend' ],
    { display => 'off', menu => 'no' }
  );
  
  $self->modify_configs(
    [ map "regulatory_regions_funcgen_$_", @feature_sets ],
    { menu => 'yes' }
  );

  $self->get_node('opt_empty_tracks')->set('display', 'normal');	

  foreach my $cell_line (@cell_lines) {
    $_->set('display', 'normal') for map $self->get_node("${_}_$cell_line") || (), 'reg_feats', 'seg';
    
    # Turn on core evidence track
    $self->modify_configs(
      [ "reg_feats_core_$cell_line" ],
      { display => $cell_line =~ /^(MultiCell|CD4)$/ ? 'tiling_feature' : 'compact' }
    );
   
    # Turn on supporting evidence track
    $self->modify_configs(
      [ "reg_feats_non_core_$cell_line" ],
      { display => 'compact' }
    );
    
    $self->{'reg_feats_tracks'}{$_} = 1 for "reg_feats_$cell_line", "reg_feats_core_$cell_line", "reg_feats_non_core_$cell_line", "seg_$cell_line";
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
    [ 'draggable',                '', 'draggable',                { display => 'normal', strand => 'b', menu => 'no'                      }]
  );
  
  $_->remove for map $self->get_node($_) || (), keys %{$self->{'reg_feats_tracks'}};
  $_->remove for grep $_->id =~ /_legend/, $self->get_tracks;
}

sub init_cell_line {
  my $self = shift;
  my (%on, $i);
  
  $_->remove for grep !$self->{'reg_feats_tracks'}{$_->id}, $self->get_tracks;
  
  $on{$_->data->{'cell_line'}} ||= [ $_, $i++ ] for grep $_->get('display') ne 'off', $self->get_tracks;
  
  foreach (grep $_->[1], values %on) {
    my $spacer = $_->[0]->before($self->create_track("spacer_$_->[1]", '', { glyphset => 'spacer', strand => 'r', colour => 'grey40', width => $self->image_width, height => 2 }));
    my $after  = $_->[0]->get('track_after');
    
    if ($after) {
      $spacer->set('track_after', $after);
      $_->[0]->set('track_after', $spacer);
    }
  }
  
  $self->add_tracks('other',
    [ 'draggable', '', 'draggable', { display => 'normal', strand => 'b', menu => 'no' }]
  );
}

sub init_bottom {
  my $self = shift;
  
  $_->remove for grep $_->id !~ /_legend/, $self->get_tracks;

  $self->add_tracks('other',
    [ 'fg_background_regulation', '', 'fg_background_regulation', { display => 'normal', strand => 'r', menu => 'no', tag => 0            }],
    [ 'scalebar',                 '', 'scalebar',                 { display => 'normal', strand => 'r', menu => 'no', name => 'Scale bar' }],
    [ 'ruler',                    '', 'ruler',                    { display => 'normal', strand => 'r', menu => 'no', name => 'Ruler'     }],
  );
}

1;

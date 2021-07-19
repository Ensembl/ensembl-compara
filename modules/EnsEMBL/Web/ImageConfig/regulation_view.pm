=head1 LICENSE

Copyright [1999-2015] Wellcome Trust Sanger Institute and the EMBL-European Bioinformatics Institute
Copyright [2016-2021] EMBL-European Bioinformatics Institute

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

package EnsEMBL::Web::ImageConfig::regulation_view;

use strict;
use warnings;

use EnsEMBL::Web::Utils::Sanitize qw(clean_id);

use parent qw(EnsEMBL::Web::ImageConfig);

sub cache_key        { return $_[0]->cache_code eq 'cell_line' ? '' : $_[0]->SUPER::cache_key; }
sub load_user_tracks { return $_[0]->SUPER::load_user_tracks($_[1]) unless $_[0]->cache_code eq 'set_evidence_types'; } # Stops unwanted cache tags being added for the main page (not the component)

sub init_cacheable {
  ## @override
  my $self = shift;

  $self->SUPER::init_cacheable(@_);

  my @feature_sets  = ('cisRED', 'VISTA', 'miRanda', 'NestedMICA', 'REDfly CRM', 'REDfly TFBS', 'search');
  my $cell_info     = {};
  if ( $self->species_defs->databases->{'DATABASE_FUNCGEN'} ) {
    $cell_info      = $self->species_defs->databases->{'DATABASE_FUNCGEN'}{'tables'}{'cell_type'}{'ids'};
  }
  my @cell_lines    = grep { $cell_info->{$_} > 0 } sort keys %$cell_info;

  s/\:\d*$// for @cell_lines;

  $self->set_parameters({
    image_resizeable  => 1,
    opt_lines         => 1
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

  # my $cell_line = clean_id($self->hub->species_defs->get_config($self->species, 'REGULATION_DEFAULT_CELL')); # Eugh, modifies arg.
  # foreach my $type (qw(reg_feats seg reg_feats_non_core reg_feats_core)) {
  #   my $node = $self->get_node("${type}_$cell_line");
  #   next unless $node;
  #   $node->set('display',$type =~ /_core/ ? 'compact' : 'normal');
  # }

  # foreach my $cell_line (@cell_lines) {
  #   $cell_line = clean_id($cell_line); # Eugh, modifies arg.
  #   $self->{'reg_feats_tracks'}{$_} = 1 for "reg_feats_$cell_line", "reg_feats_core_$cell_line", "reg_feats_non_core_$cell_line", "seg_$cell_line";
  # }

  if ($self->cache_code ne $self->type) {
    my $func = "init_".$self->cache_code;
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
  $_->remove for grep $_->id =~ /_legend/, @{$self->get_tracks};
}

sub init_cell_line {
  my $self = shift;

  $_->remove for grep !$self->{'reg_feats_tracks'}{$_->id}, @{$self->get_tracks};

  $self->add_tracks('other',
    [ 'draggable', '', 'draggable', { display => 'normal', strand => 'b', menu => 'no' }]
  );
}

sub init_bottom {
  my $self = shift;

  $_->remove for grep $_->id !~ /_legend/, @{$self->get_tracks};

  $self->add_tracks('other',
    [ 'fg_background_regulation', '', 'fg_background_regulation', { display => 'normal', strand => 'r', menu => 'no', tag => 0            }],
    [ 'scalebar',                 '', 'scalebar',                 { display => 'normal', strand => 'r', menu => 'no', name => 'Scale bar' }],
    [ 'ruler',                    '', 'ruler',                    { display => 'normal', strand => 'r', menu => 'no', name => 'Ruler'     }],
  );
}

1;

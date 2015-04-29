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

package EnsEMBL::Web::ImageConfig::regulation_view;

use strict;

use base qw(EnsEMBL::Web::ImageConfig);

use EnsEMBL::Web::Tree;

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
  
  my $gencode_version = $self->hub->species_defs->GENCODE ? $self->hub->species_defs->GENCODE->{'version'} : '';
  $self->add_track('transcript', 'gencode', "Basic Gene Annotations from GENCODE $gencode_version", '_gencode', {
    labelcaption => "Genes (Basic set from GENCODE $gencode_version)",
    display     => 'off',       
    description => 'The GENCODE set is the gene set for human and mouse. GENCODE Basic is a subset of representative transcripts (splice variants).',
    sortable    => 1,
    colours     => $self->species_defs->colour('gene'), 
    label_key  => '[biotype]',
    logic_names => ['proj_ensembl',  'proj_ncrna', 'proj_havana_ig_gene', 'havana_ig_gene', 'ensembl_havana_ig_gene', 'proj_ensembl_havana_lincrna', 'proj_havana', 'ensembl', 'mt_genbank_import', 'ensembl_havana_lincrna', 'proj_ensembl_havana_ig_gene', 'ncrna', 'assembly_patch_ensembl', 'ensembl_havana_gene', 'ensembl_lincrna', 'proj_ensembl_havana_gene', 'havana'], 
    renderers   =>  [
      'off',                     'Off',
      'gene_nolabel',            'No exon structure without labels',
      'gene_label',              'No exon structure with labels',
      'transcript_nolabel',      'Expanded without labels',
      'transcript_label',        'Expanded with labels',
      'collapsed_nolabel',       'Collapsed without labels',
      'collapsed_label',         'Collapsed with labels',
      'transcript_label_coding', 'Coding transcripts only (in coding genes)',
    ],
  }) if($gencode_version);
  
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

  my $cell_line = $self->hub->species_defs->get_config($self->species, 'REGULATION_DEFAULT_CELL');
  EnsEMBL::Web::Tree->clean_id($cell_line); # Eugh, modifies arg.
  foreach my $type (qw(reg_feats seg reg_feats_non_core reg_feats_core)) {
    my $node = $self->get_node("${type}_$cell_line");
    next unless $node;
    $node->set('display',$type =~ /_core/ ? 'compact' : 'normal');
  }
  foreach my $cell_line (@cell_lines) {
    EnsEMBL::Web::Tree->clean_id($cell_line); # Eugh, modifies arg.
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

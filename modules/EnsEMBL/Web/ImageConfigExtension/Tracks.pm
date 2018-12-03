=head1 LICENSE

Copyright [1999-2016] Wellcome Trust Sanger Institute and the EMBL-European Bioinformatics Institute

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

package EnsEMBL::Web::ImageConfigExtension::Tracks;

### An Extension to EnsEMBL::Web::ImageConfig
### Methods to load default tracks

package EnsEMBL::Web::ImageConfig;

use strict;
use warnings;
no warnings qw(uninitialized);

use List::MoreUtils qw(firstidx);

use EnsEMBL::Web::Utils::Sanitize qw(clean_id);

sub load_tracks {
  ## Loop through core/compara/funcgen/variation like dbs and loads in various database derived tracks
  ## @params List of arguments to be passed on the individual method to add a specific type of track
  my $self          = shift;
  my $species       = $self->species;
  my $species_defs  = $self->species_defs;
  my $dbs_hash      = $self->databases;

  my %methods_for_dbtypes = (
    'core' => [
      'add_dna_align_features',           # Add to cDNA/mRNA, est, RNA, other_alignment trees
      'add_data_files',                   # Add to gene/rnaseq tree
      'add_genes',                        # Add to gene, transcript, align_slice_transcript, tsv_transcript trees
      'add_trans_associated',             # Add to features associated with transcripts
      'add_marker_features',              # Add to marker tree
      'add_qtl_features',                 # Add to marker tree
      'add_genome_attribs',               # Add to genome_attribs tree
      'add_misc_features',                # Add to misc_feature tree
      'add_prediction_transcripts',       # Add to prediction_transcript tree
      'add_protein_align_features',       # Add to protein_align_feature_tree
      'add_protein_features',             # Add to protein_feature_tree
      'add_repeat_features',              # Add to repeat_feature tree
      'add_simple_features',              # Add to simple_feature tree
      'add_decorations'
    ],
    'compara' => [
      'add_synteny',                      # Add to synteny tree
      'add_alignments'                    # Add to compara_align tree
    ],
    'funcgen' => [
      'add_regulation_builds',            # Add to regulation_feature tree
      'add_regulation_features',          # Add to regulation_feature tree
      'add_oligo_probes'                  # Add to oligo tree
    ],
    'variation' => [
      'add_sequence_variations',          # Add to variation_feature tree
      'add_phenotypes',                   # Add to variation_feature tree
      'add_structural_variations',        # Add to variation_feature tree
      'add_copy_number_variant_probes',   # Add to variation_feature tree
      'add_recombination',                # Moves recombination menu to the end of the variation_feature tree
      'add_somatic_mutations',            # Add to somatic tree
      'add_somatic_structural_variations' # Add to somatic tree
    ],
  );

  foreach my $db_type (keys %methods_for_dbtypes) {
    my ($db_hash, $databases) = $db_type eq 'compara'
      ? ($species_defs->multi_hash, $species_defs->compara_like_databases)
      : ($dbs_hash, $species_defs->get_config($species, "${db_type}_like_databases"));

    # For all the dbs belonging to a particular db type, call all the methods, one be one, to add tracks for that db type
    foreach my $db_key (grep exists $db_hash->{$_}, @{$databases || []}) {
      my $db_name = lc substr $db_key, 9;

      foreach my $method (@{$methods_for_dbtypes{$db_type}}) {
        $self->$method($db_name, $db_hash->{$db_key}{'tables'} || $db_hash->{$db_key}, $species, @_);
      }
    }
  }

  $self->add_option('information', 'opt_empty_tracks',      'Display empty tracks',       'off'     ) unless $self->get_parameter('opt_empty_tracks') eq '0';
  $self->add_option('information', 'opt_subtitles',         'Display in-track labels',    'normal'  );
  $self->add_option('information', 'opt_highlight_feature', 'Highlight current feature',  'normal'  );
  $self->tree->root->append_child($self->create_option('track_order')) if $self->get_parameter('sortable_tracks'); ## TODO - Why this?
}

sub _merge {
  my ($self, $_sub_tree, $sub_type) = @_;
  my $tree        = $_sub_tree->{'analyses'};
  my $config_name = $self->{'type'};
  my $data        = {};

  foreach my $analysis (keys %$tree){
    my $sub_tree = $tree->{$analysis};

    next unless $sub_tree->{'disp'}; # Don't include non-displayable tracks
    next if $sub_type && exists $sub_tree->{'web'}{$sub_type}{'do_not_display'};

    my $key = $sub_tree->{'web'}{'key'} || $analysis;

    foreach (grep $_ ne 'desc', keys %{$sub_tree->{'web'} || {}}) {
      if ($_ eq 'default') {
        $data->{$key}{'display'} ||= ref $sub_tree->{'web'}{$_} eq 'HASH' ? $sub_tree->{'web'}{$_}{$config_name} : $sub_tree->{'web'}{$_};
      } else {
        $data->{$key}{$_} ||= $sub_tree->{'web'}{$_}; # Longer form for help and configuration
      }
    }

    if ($sub_tree->{'web'}{'key'}) {
      if ($sub_tree->{'desc'}) {
        $data->{$key}{'multiple'}      = "This track comprises multiple analyses;" if $data->{$key}{'description'};
        $data->{$key}{'description'} ||= '';
        $data->{$key}{'description'}  .= ($data->{$key}{'description'} ? '; ' : '') . $sub_tree->{'desc'};
      }
    } else {
      $data->{$key}{'description'} = $sub_tree->{'desc'};
    }

    $data->{$key}{'format'} = $sub_tree->{'format'};

    push @{$data->{$key}{'logic_names'}}, $analysis;
  }

  foreach my $key (keys %$data) {
    $data->{$key}{'name'}      ||= $tree->{$key}{'name'};
    $data->{$key}{'caption'}   ||= $data->{$key}{'name'} || $tree->{$key}{'name'};
    $data->{$key}{'display'}   ||= 'off';
    $data->{$key}{'strand'}    ||= 'r';
    $data->{$key}{'description'} = "$data->{$key}{'multiple'} $data->{$key}{'description'}" if $data->{$key}{'multiple'};
  }

  return ([ sort { $data->{$a}{'name'} cmp $data->{$b}{'name'} } keys %$data ], $data);
}

sub _add_track {
  my ($self, $menu, $key, $name, $data, $options) = @_;

  $data = {
    %$data,
    db        => $key,
    renderers => [ 'off', 'Off', 'normal', 'On' ],
    %$options
  };

  $self->_add_matrix($data, $menu) if $data->{'matrix'};

  return $menu->append_child($self->create_track_node($name, $data->{'name'}, $data));
}

sub _add_matrix {
  my ($self, $data, $menu) = @_;
  my $menu_data    = $menu->data;
  my $matrix       = $data->{'matrix'};
  my $caption      = $data->{'caption'};
  my $column       = $matrix->{'column'};
  my $subset       = $matrix->{'menu'};
  my @rows         = $matrix->{'rows'} ? @{$matrix->{'rows'}} : $matrix;
  my $column_key   = clean_id("${subset}_$column");
  my $column_track = $self->get_node($column_key);

  unless ($column_track && $column_track->parent_node) {
    $column_track = $self->create_track_node($column_key, $data->{'track_name'} || $column, {
      renderers   => $data->{'renderers'},
      label_x     => $column,
      c_header    => $matrix->{'column_label'},
      display     => 'off',
      subset      => $subset,
      $matrix->{'row'} ? (matrix => 'column') : (),
      column_order => $matrix->{'column_order'} || 999999,
      %{$data->{'column_data'} || {}}
    });

    $menu->insert_alphabetically($column_track, 'label_x');
  }

  if ($matrix->{'row'}) {
    push @{$column_track->data->{'subtrack_list'}}, [ $caption, $column_track->data->{'no_subtrack_description'} ? () : $data->{'description'} ];
    $data->{'option_key'} = clean_id("${subset}_${column}_$matrix->{'row'}");
  }

  $data->{'column_key'}  = $column_key;
  $data->{'menu'}        = 'matrix_subtrack';
  $data->{'source_name'} = $data->{'name'};

  if (!$data->{'display'} || $data->{'display'} eq 'off') {
    $data->{'display'} = 'default';
  }

  if (!$menu_data->{'matrix'}) {
    my $hub = $self->hub;

    $menu_data->{'menu'}   = 'matrix';
    $menu_data->{'url'}    = $hub->url('Config', { 'matrix' => 1, 'menu' => $menu->id });
    $menu_data->{'matrix'} = {
      section => $menu->parent_node->data->{'caption'},
      header  => $menu_data->{'caption'},
    }
  }

  foreach (@rows) {
    my $option_key  = "${subset}_${column}_$_->{'row'}";
    my $node        = $self->get_node($option_key);
    my $display     = ($_->{'on'} || ($data->{'display'} ne 'off' && $data->{'display'} ne 'default')) ? 'on' : 'off';

    if ($node) {
      $node->set_data('display', 'on') if $display eq 'on';
    } else {

      $node = $column_track->append_child($self->create_option_node($option_key, $_->{'row'}, $display, undef, [qw(on on off off)]));

      $node->set_data('menu', 'no');
      $node->set_data('caption', "$column - $_->{'row'}");
      $node->set_data('group', $_->{'group'}) if $_->{'group'};
      $menu_data->{'matrix'}{'rows'}{$_->{'row'}} = { id => $_->{'row'}, group => $_->{'group'}, group_order => $_->{'group_order'}, column_order => $_->{'column_order'}, row_order => $_->{'row_order'}, column => $column };
    }
  }

  return $column_track;
}

sub add_dna_align_features {
  ## Loop through all core databases - and attach the dna align features from the dna_align_feature tables...
  ## These are added to one of five menus: transcript, cdna/mrna, est, rna, other depending whats in the web_data column in the database
  my ($self, $key, $hashref) = @_;

  return unless $self->get_node('dna_align_cdna') || $key eq 'rnaseq';

  my ($keys, $data) = $self->_merge($hashref->{'dna_align_feature'}, 'dna_align_feature');

  foreach my $key_2 (@$keys) {
    my $k    = $data->{$key_2}{'type'} || 'other';
    my $menu = ($k =~ /rnaseq|simple|transcript/) ? $self->get_node($k) : $self->get_node("dna_align_$k");

    if ($menu) {
      my $alignment_renderers = ['off','Off'];

      $alignment_renderers = [ @{$self->_alignment_renderers} ] unless($data->{$key_2}{'no_default_renderers'});

      if (my @other_renderers = @{$data->{$key_2}{'additional_renderers'} || [] }) {
        my $i = 0;
        while ($i < scalar(@other_renderers)) {
          splice @$alignment_renderers, $i+2, 0, $other_renderers[$i];
          splice @$alignment_renderers, $i+3, 0, $other_renderers[$i+1];
          $i += 2;
        }
      }

      # my $display = (grep { $data->{$key_2}{'display'} eq $_ } @$alignment_renderers )             ? $data->{$key_2}{'display'}
      #             : (grep { $data->{$key_2}{'display'} eq $_ } @{$self->_alignment_renderers} )    ? $data->{$key_2}{'display'}
      #             : 'off'; # needed because the same logic_name can be a gene and an alignment

      my $display  = $data->{$key_2}{'display'} ? $data->{$key_2}{'display'} : 'off';
      my $glyphset = '_alignment';
      my $strand   = 'b';

      if ($key_2 eq 'alt_seq_mapping') {
        $display             = 'simple';
        $alignment_renderers = [ 'off', 'Off', 'normal', 'On' ];
        $glyphset            = 'patch_ref_alignment';
        $strand              = 'f';
      }

      $self->_add_track($menu, $key, "dna_align_${key}_$key_2", $data->{$key_2}, {
        glyphset  => $glyphset,
        sub_type  => lc $k,
        colourset => 'feature',
        display   => $display,
        renderers => $alignment_renderers,
        strand    => $strand,
      });
    }
  }

  $self->add_track('information', 'diff_legend', 'Alignment Difference Legend', 'diff_legend', { strand => 'r' });
}

sub add_data_files {
  my ($self, $key, $hashref) = @_;
  my $menu = $self->get_node('rnaseq');

  return unless $menu;

  my ($keys, $data) = $self->_merge($hashref->{'data_file'});

  foreach (@$keys) {
    my $glyphset = $data->{$_}{'format'} || '_alignment';

    my $renderers;
    if ($glyphset eq 'bamcov') {
      $renderers = [
                    'off',                  'Off',
                    'signal',               'Coverage (BigWig)',
                    'coverage_with_reads',  'Normal',
                    'unlimited',            'Unlimited',
                    ];
    }
    else {
      $renderers = [
                    'off',                  'Off',
                    'coverage_with_reads',  'Normal',
                    'unlimited',            'Unlimited',
                    'histogram',            'Coverage only'
                    ];
    }

    $self->_add_track($menu, $key, "data_file_${key}_$_", $data->{$_}, {
      glyphset  => $glyphset,
      colourset => $data->{$_}{'colour_key'} || 'feature',
      strand    => 'f',
      renderers => $renderers,
      gang      => 'rnaseq',
      on_error  => 555,
    });
  }
}

# add_genes
# loop through all core databases - and attach the gene
# features from the gene tables...
# there are a number of menus sub-types these are added to:
# * transcript              # ordinary transcripts
# * alignslice_transcript   # transcripts in align slice co-ordinates
# * tse_transcript          # transcripts in collapsed intro co-ords
# * tsv_transcript          # transcripts in collapsed intro co-ords
# * gsv_transcript          # transcripts in collapsed gene co-ords
# depending on which menus are configured
sub add_genes {
  my ($self, $key, $hashref, $species) = @_;

  # Gene features end up in each of these menus
  return unless grep $self->get_node($_), $self->_transcript_types;

  my ($keys, $data) = $self->_merge($hashref->{'gene'}, 'gene');
  my $colours       = $self->species_defs->colour('gene');

  my $flag          = 0;

  my $renderers = [
          'off',                     'Off',
          'gene_nolabel',            'No exon structure without labels',
          'gene_label',              'No exon structure with labels',
          'transcript_nolabel',      'Expanded without labels',
          'transcript_label',        'Expanded with labels',
          'collapsed_nolabel',       'Collapsed without labels',
          'collapsed_label',         'Collapsed with labels',
          'transcript_label_coding', 'Coding transcripts only (in coding genes)',
        ];

  foreach my $type ($self->_transcript_types) {
    my $menu = $self->get_node($type);
    next unless $menu;

    foreach my $key2 (@$keys) {
      my $t = $type;

      # force genes into a seperate menu if so specified in web_data (ie rna-seq); unless you're on a transcript page that is
      if ($data->{$key2}{'type'}){
        unless (ref($self) =~ /transcript/) {
          $t = $data->{$key2}{'type'};
        }
      }

      my $menu = $self->get_node($t);
      next unless $menu;

      $self->_add_track($menu, $key, "${t}_${key}_$key2", $data->{$key2}, {
        glyphset  => ($t =~ /_/ ? '' : '_') . $type, # QUICK HACK
        colours   => $colours,
        strand    => $t eq 'gene' ? 'r' : 'b',
        label_key => '[biotype]',
        renderers => $t eq 'transcript' ? $renderers : $t eq 'rnaseq' ? [
         'off',                'Off',
         'transcript_nolabel', 'Expanded without labels',
         'transcript_label',   'Expanded with labels',
        ] : [
         'off',          'Off',
         'gene_nolabel', 'No labels',
         'gene_label',   'With labels'
        ]
      });
      $flag = 1;
    }
  }

  # Adding gencode basic track, this has been moved from each image config to this generic one
  if (my $gencode_version = $self->species_defs->GENCODE_VERSION || "") {
    $self->add_track('transcript', 'gencode', "Basic Gene Annotations from $gencode_version", '_gencode', {
      labelcaption  => "Genes (Basic set from $gencode_version)",
      display       => 'off',
      description   => 'The GENCODE set is the gene set for human and mouse. <a href="/Help/Glossary?id=500" class="popup">GENCODE Basic</a> is a subset of representative transcripts (splice variants).',
      sortable      => 1,
      colours       => $self->species_defs->colour('gene'),
      label_key     => '[biotype]',
      logic_names   => ['proj_ensembl',  'proj_ncrna', 'proj_havana_ig_gene', 'havana_ig_gene', 'ensembl_havana_ig_gene', 'proj_ensembl_havana_lincrna', 'proj_havana', 'ensembl', 'mt_genbank_import', 'ensembl_havana_lincrna', 'proj_ensembl_havana_ig_gene', 'ncrna', 'assembly_patch_ensembl', 'ensembl_havana_gene', 'ensembl_lincrna', 'proj_ensembl_havana_gene', 'havana'],
      renderers     =>  [
        'off',                     'Off',
        'gene_nolabel',            'No exon structure without labels',
        'gene_label',              'No exon structure with labels',
        'transcript_nolabel',      'Expanded without labels',
        'transcript_label',        'Expanded with labels',
        'collapsed_nolabel',       'Collapsed without labels',
        'collapsed_label',         'Collapsed with labels',
        'transcript_label_coding', 'Coding transcripts only (in coding genes)',
      ],
    });
  }


  # Need to add the gene menu track here
  $self->add_track('information', 'gene_legend', 'Gene Legend', 'gene_legend', { strand => 'r' }) if $flag;

  # overwriting Genes comprehensive track description to not be the big concatenation of many description (only gencode gene track)
  $self->modify_configs(['transcript_core_ensembl'],{ description => 'The <a class="popup" href="/Help/Glossary?id=487">GENCODE Comprehensive</a> set is the gene set for human and mouse' }) if($self->species_defs->GENCODE_VERSION);
}

sub add_trans_associated {
  my ($self, $key, $hashref) = @_;
  my $menu = $self->get_node('trans_associated');

  return unless $menu;

  my ($keys, $data) = $self->_merge($hashref->{'simple_feature'});
  $self->_add_track($menu, $key, "simple_${key}_$_", $data->{$_}, { glyphset => '_simple', colourset => 'simple' }) for grep $data->{$_}{'transcript_associated'}, @$keys;
}

sub add_marker_features {
  my($self, $key, $hashref) = @_;
  my $menu = $self->get_node('marker');

  return unless $menu;

  my ($keys, $data) = $self->_merge($hashref->{'marker_feature'});
  my $colours = $self->species_defs->colour('marker');

  foreach (@$keys) {
    $self->_add_track($menu, $key, "marker_${key}_$_", $data->{$_}, {
      glyphset => 'marker',
      labels   => 'on',
      colours  => $colours,
      strand   => 'r',
    });
  }
}

sub add_qtl_features {
  my ($self, $key, $hashref) = @_;

  my $menu = $self->get_node('marker');

  return unless $menu && $hashref->{'qtl'} && $hashref->{'qtl'}{'rows'} > 0;

  $menu->append_child($self->create_track_node("qtl_$key", 'QTLs', {
    db          => $key,
    glyphset    => '_qtl',
    caption     => 'QTLs',
    colourset   => 'qtl',
    description => 'Quantative trait loci',
    display     => 'normal',
    renderers   => [ 'off', 'Off', 'normal', 'On' ],
    strand      => 'r',
  }));
}

sub add_genome_attribs {
  my ($self, $key, $hashref) = @_;
  my $menu = $self->get_node('genome_attribs');

  return unless $menu;

  my $default_tracks = {};
  my $config_name = $self->{'type'};
  my $data        = $hashref->{'genome_attribs'}{'sets'}; # Different loop - no analyses - just misc_sets

  foreach (sort { $data->{$a}{'name'} cmp $data->{$b}{'name'} } keys %$data) {
    next if $_ eq 'NoAnnotation' || $default_tracks->{$config_name}{$_}{'available'} eq 'no';

    $self->_add_track($menu, $key, "genome_attribs_${key}_$_", $data->{$_}, {
      glyphset          => '_clone',
      set               => $_,
      colourset         => 'clone',
      caption           => $data->{$_}{'name'},
      description       => $data->{$_}{'desc'},
      strand            => 'r',
      display           => $default_tracks->{$config_name}{$_}{'default'} || $data->{$_}{'display'} || 'off',
      outline_threshold => $default_tracks->{$config_name}{$_}{'threshold'} eq 'no' ? undef : 350000,
    });
  }
}

sub add_misc_features {
  my ($self, $key, $hashref) = @_;
  my $menu = $self->get_node('misc_feature');

  return unless $menu;

  # set some defaults and available tracks
  my $default_tracks = {
    cytoview   => {
      tilepath => { default   => 'normal' },
      encode   => { threshold => 'no'     }
    },
    contigviewbottom => {
      ntctgs => { available => 'no' },
      encode => { threshold => 'no' }
    }
  };

  my $config_name = $self->{'type'};
  my $data        = $hashref->{'misc_feature'}{'sets'}; # Different loop - no analyses - just misc_sets

  foreach (sort { $data->{$a}{'name'} cmp $data->{$b}{'name'} } keys %$data) {
    next if $_ eq 'NoAnnotation' || $default_tracks->{$config_name}{$_}{'available'} eq 'no';

    $self->_add_track($menu, $key, "misc_feature_${key}_$_", $data->{$_}, {
      glyphset          => '_clone',
      set               => $_,
      colourset         => 'clone',
      caption           => $data->{$_}{'name'},
      description       => $data->{$_}{'desc'},
      strand            => 'r',
      display           => $default_tracks->{$config_name}{$_}{'default'} || $data->{$_}{'display'} || 'off',
      outline_threshold => $default_tracks->{$config_name}{$_}{'threshold'} eq 'no' ? undef : 350000,
    });
  }
}

sub add_prediction_transcripts {
  my ($self, $key, $hashref) = @_;
  my $menu = $self->get_node('prediction');

  return unless $menu;

  my ($keys, $data) = $self->_merge($hashref->{'prediction_transcript'});

  foreach (@$keys) {
    $self->_add_track($menu, $key, "transcript_${key}_$_", $data->{$_}, {
      glyphset   => '_prediction_transcript',
      colourset  => 'prediction',
      label_key  => '[display_label]',
      colour_key => lc $_,
      renderers  => [ 'off', 'Off', 'transcript_nolabel', 'No labels', 'transcript_label', 'With labels' ],
      strand     => 'b',
    });
  }
}

# add_protein_align_features
# loop through all core databases - and attach the protein align
# features from the protein_align_feature tables...
sub add_protein_align_features {
  my ($self, $key, $hashref) = @_;
  my $menu = $self->get_node('protein_align');

  return unless $menu;

  my ($keys, $data) = $self->_merge($hashref->{'protein_align_feature'}, 'protein_align_feature');

  foreach my $key_2 (@$keys) {
    # needed because the same logic_name can be a gene and an alignment, need to fix default rederer  the web_data
    my $display = (grep { $data->{$key_2}{'display'} eq $_ } @{$self->_alignment_renderers}) ? $data->{$key_2}{'display'} : 'off';

    $self->_add_track($menu, $key, "protein_${key}_$key_2", $data->{$key_2}, {
      glyphset    => '_alignment',
      sub_type    => 'protein',
      colourset   => 'feature',
      object_type => 'ProteinAlignFeature',
      display     => $display,
      renderers   => $self->_alignment_renderers,
      strand      => 'b',
    });
  }
}

sub add_protein_features {
  my ($self, $key, $hashref) = @_;

  # We have two separate glyphsets in this in this case
  # P_feature and P_domain - plus domains get copied onto gsv_domain as well
  my %menus = (
    domain     => [ 'domain',    'P_domain',   'normal' ],
    feature    => [ 'feature',   'P_feature',  'normal' ],
    alignment  => [ 'alignment', 'P_domain',   'off'    ],
    gsv_domain => [ 'domain',    'gsv_domain', 'normal' ]
  );

  return unless grep $self->get_node($_), keys %menus;

  my ($keys, $data) = $self->_merge($hashref->{'protein_feature'});

  foreach my $menu_code (keys %menus) {
    my $menu = $self->get_node($menu_code);

    next unless $menu;

    my $type     = $menus{$menu_code}[0];
    my $gset     = $menus{$menu_code}[1];
    my $renderer = $menus{$menu_code}[2];

    foreach (@$keys) {
      next if $self->get_node("${type}_$_");
      next if $type ne ($data->{$_}{'type'} || 'feature'); # Don't separate by db in this case

      $self->_add_track($menu, $key, "${type}_$_", $data->{$_}, {
        glyphset  => $gset,
        colourset => 'protein_feature',
        display   => $renderer,
        depth     => 1e6,
        strand    => $gset =~ /P_/ ? 'f' : 'b',
      });
    }
  }
}

sub add_repeat_features {
  my ($self, $key, $hashref) = @_;
  my $menu = $self->get_node('repeat');

  return unless $menu && $hashref->{'repeat_feature'}{'rows'} > 0;

  my $data    = $hashref->{'repeat_feature'}{'analyses'};
  my %options = (
    glyphset    => 'repeat',
    depth       => 0.5,
    bump_width  => 0,
    strand      => 'r',
  );

  $menu->append_child($self->create_track_node("repeat_$key", 'All repeats', {
    db          => $key,
    logic_names => [ undef ], # All logic names
    types       => [ undef ], # All repeat types
    name        => 'All repeats',
    description => 'All repeats',
    colourset   => 'repeat',
    display     => 'off',
    renderers   => [qw(off Off compact Compact normal Expanded)],
    %options
  }));

  my $flag    = keys %$data > 1;
  my $colours = $self->species_defs->colour('repeat');

  foreach my $key_2 (sort { $data->{$a}{'name'} cmp $data->{$b}{'name'} } keys %$data) {
    if ($flag) {
      # Add track for each analysis
      $self->_add_track($menu, $key, "repeat_${key}_$key_2", $data->{$key_2}, {
        logic_names => [ $key_2 ], # Restrict to a single supset of logic names
        types       => [ undef  ],
        colours     => $colours,
        description => $data->{$key_2}{'desc'},
        display     => 'off',
        %options
      });
    }

    my $d2 = $data->{$key_2}{'types'};

    if (keys %$d2 > 1) {
      foreach my $key_3 (sort keys %$d2) {
        my $n  = $key_3;
           $n .= " ($data->{$key_2}{'name'})" unless $data->{$key_2}{'name'} eq 'Repeats';

        # Add track for each repeat_type;
        $menu->append_child($self->create_track_node('repeat_' . $key . '_' . $key_2 . '_' . $key_3, $n, {
          db          => $key,
          logic_names => [ $key_2 ],
          types       => [ $key_3 ],
          name        => $n,
          colours     => $colours,
          description => "$data->{$key_2}{'desc'} ($key_3)",
          display     => 'off',
          renderers   => [qw(off Off compact Compact normal Expanded)],
          %options
        }));
      }
    }
  }
}

sub add_simple_features {
  my ($self, $key, $hashref) = @_;
  my $menu = $self->get_node('simple');

  return unless $menu;

  my ($keys, $data) = $self->_merge($hashref->{'simple_feature'});

  foreach (grep !$data->{$_}{'transcript_associated'}, @$keys) {
    # Allow override of default glyphset, menu etc.
    $menu = $self->get_node($data->{$_}{'menu'}) if $data->{$_}{'menu'};

    next unless $menu;

    my $glyphset = $data->{$_}{'glyphset'} ? $data->{$_}{'glyphset'}: 'simple_features';
    my %options  = (
      glyphset  => $glyphset,
      colourset => 'simple',
      strand    => 'r',
      renderers => ['off', 'Off', 'normal', 'On', 'labels', 'With labels'],
    );

    foreach my $opt ('renderers', 'height') {
      $options{$opt} = $data->{$_}{$opt} if $data->{$_}{$opt};
    }

    $self->_add_track($menu, $key, "simple_${key}_$_", $data->{$_}, \%options);
  }
}

sub add_decorations {
  my ($self, $key, $hashref) = @_;
  my $menu = $self->get_node('decorations');

  return unless $menu;

  if ($key eq 'core' && $hashref->{'karyotype'}{'rows'} > 0 && !$self->get_node('ideogram')) {
    $menu->append_child($self->create_track_node("chr_band_$key", 'Chromosome bands', {
      db          => $key,
      glyphset    => 'chr_band',
      display     => 'normal',
      strand      => 'f',
      description => 'Cytogenetic bands',
      colourset   => 'ideogram',
      sortable    => 1,
    }));
  }

  if ($key eq 'core' && $hashref->{'assembly_exception'}{'rows'} > 0) {
    $menu->append_child($self->create_track_node("assembly_exception_$key", 'Assembly exceptions', {
      db           => $key,
      glyphset     => 'assemblyexception',
      height       => 2,
      display      => 'collapsed',
      renderers    => [ 'off', 'Off', 'collapsed', 'Collapsed', 'collapsed_label', 'Collapsed with labels', 'normal', 'Expanded' ],
      strand       => 'x',
      label_strand => 'r',
      short_labels => 0,
      description  => 'GRC assembly patches, haplotype (HAPs) and pseudo autosomal regions (PARs)',
      colourset    => 'assembly_exception',
    }));
  }

  if ($key eq 'core' && $hashref->{'misc_feature'}{'sets'}{'NoAnnotation'}) {
    $menu->append_child($self->create_track_node('annotation_status', 'Annotation status', {
      db            => $key,
      glyphset      => 'annotation_status',
      height        => 2,
      display       => 'normal',
      strand        => 'f',
      label_strand  => 'r',
      short_labels  => 0,
      depth         => 0,
      description   => 'Unannotated regions',
      colourset     => 'annotation_status',
    }));
  }
}

#----------------------------------------------------------------------#
# Functions to add tracks from compara like databases                  #
#----------------------------------------------------------------------#

sub add_synteny {
  my ($self, $key, $hashref, $species) = @_;
  my $menu = $self->get_node('synteny');

  return unless $menu;

  my @synteny_species = sort keys %{$hashref->{'SYNTENY'}{$species} || {}};

  return unless @synteny_species;

  my $species_defs = $self->species_defs;
  my $colours      = $species_defs->colour('synteny');
  my $self_label   = $species_defs->species_label($species, 'no_formatting');

  foreach my $species_2 (@synteny_species) {
    (my $species_readable = $species_2) =~ s/_/ /g;
    my ($a, $b) = split / /, $species_readable;
    my $caption = substr($a, 0, 1) . ".$b synteny";
    my $label   = $species_defs->species_label($species_2, 'no_formatting');
    (my $name   = "Synteny with $label") =~ s/<.*?>//g;

    $menu->append_child($self->create_track_node("synteny_$species_2", $name, {
      db          => $key,
      glyphset    => '_synteny',
      species     => $species_2,
      species_hr  => $species_readable,
      caption     => $caption,
      description => qq{<a href="/info/genome/compara/analyses.html#synteny" class="cp-external">Synteny regions</a> between $self_label and $label},
      colours     => $colours,
      display     => 'off',
      renderers   => [qw(off Off normal On)],
      height      => 4,
      strand      => 'r',
    }));
  }
}

sub add_alignments {
  my ($self, $key, $hashref, $species) = @_;

  return unless grep $self->get_node($_), qw(multiple_align pairwise_tblat pairwise_blastz pairwise_other conservation cactus_hal_pw);

  my $species_defs = $self->species_defs;

  return if $species_defs->ENSEMBL_SUBTYPE eq 'Pre';

  my $alignments = {};
  my $self_label = $species_defs->species_label($species, 'no_formatting');
  my $static     = '/info/genome/compara/analyses.html';
  my $prod_name  = $species_defs->get_config($species, 'SPECIES_PRODUCTION_NAME');
  my $map        = $species_defs->multi_val('ENSEMBL_SPECIES_URL_MAP');
  my $comp_key   = ucfirst($prod_name);

  foreach my $row (values %{$hashref->{'ALIGNMENTS'}}) {
    next unless $row->{'species'}{$comp_key};

    if ($row->{'class'} =~ /pairwise_alignment/) {
      my ($other_species) = grep { !/^$comp_key$|ancestral_sequences$/ } keys %{$row->{'species'}};
      $other_species ||= $comp_key if scalar keys %{$row->{'species'}} == 1;
      ## Map back to actual species URL
      $other_species = $map->{lc $other_species};
      my $other_label     = $species_defs->species_label($other_species, 'no_formatting');
      my ($menu_key, $description, $type);

      if ($row->{'type'} =~ /(B?)LASTZ_(\w+)/) {
        next if $2 eq 'PATCH';

        $menu_key    = 'pairwise_blastz';
        $type        = sprintf '%sLASTz %s', $1, lc $2;
        $description = "$type pairwise alignments";
      } elsif ($row->{'type'} =~ /TRANSLATED_BLAT/) {
        $type        = 'TBLAT';
        $menu_key    = 'pairwise_tblat';
        $description = 'Trans. BLAT net pairwise alignments';
      } else {
        $type        = ucfirst lc $row->{'type'};
        $type        =~ s/\W/ /g;
        $menu_key    = 'pairwise_other';
        $description = 'Pairwise alignments';
      }

      $description  = qq{<a href="$static" class="cp-external">$description</a> between $self_label and $other_label};
      $description .= " $1" if $row->{'name'} =~ /\((on.+)\)/;

      $alignments->{$menu_key}{$row->{'id'}} = {
        db                         => $key,
        glyphset                   => '_alignment_pairwise',
        name                       => $other_label . ($type ?  " - $type" : ''),
        caption                    => $other_label,
        type                       => $row->{'type'},
        species                    => $other_species,
        method_link_species_set_id => $row->{'id'},
        description                => $description,
        order                      => $other_label,
        colourset                  => 'pairwise',
        strand                     => 'r',
        display                    => 'off',
        renderers                  => [ 'off', 'Off', 'compact', 'Compact', 'normal', 'Normal' ],
      };
    } else {
      my $n_species = grep { $_ ne 'ancestral_sequences' } keys %{$row->{'species'}};

      my %options = (
        db                         => $key,
        glyphset                   => '_alignment_multiple',
        short_name                 => $row->{'name'},
        type                       => $row->{'type'},
        species_set_id             => $row->{'species_set_id'},
        method_link_species_set_id => $row->{'id'},
        class                      => $row->{'class'},
        colourset                  => 'multiple',
        strand                     => 'f',
      );

      if ($row->{'conservation_score'}) {
        my ($program) = $hashref->{'CONSERVATION_SCORES'}{$row->{'conservation_score'}}{'type'} =~ /(.+)_CONSERVATION_SCORE/;

        $options{'description'} = qq{<a href="/info/genome/compara/analyses.html#conservation">$program conservation scores</a> based on the $row->{'name'}};

        $alignments->{'conservation'}{"$row->{'id'}_scores"} = {
          %options,
          conservation_score => $row->{'conservation_score'},
          name               => "Conservation score for $row->{'name'}",
          caption            => "$n_species way $program scores",
          order              => sprintf('%12d::%s::%s', 1e12-$n_species*10, $row->{'type'}, $row->{'name'}),
          display            => 'off',
          renderers          => [ 'off', 'Off', 'tiling', 'Tiling array' ],
        };

        $alignments->{'conservation'}{"$row->{'id'}_constrained"} = {
          %options,
          constrained_element => $row->{'constrained_element'},
          name                => "Constrained elements for $row->{'name'}",
          caption             => "$n_species way $program elements",
          order               => sprintf('%12d::%s::%s', 1e12-$n_species*10+1, $row->{'type'}, $row->{'name'}),
          display             => 'off',
          renderers           => [ 'off', 'Off', 'compact', 'On' ],
        };
      }

      $alignments->{'multiple_align'}{$row->{'id'}} = {
        %options,
        name        => $row->{'name'},
        caption     => $row->{'name'},
        order       => sprintf('%12d::%s::%s', 1e12-$n_species*10-1, $row->{'type'}, $row->{'name'}),
        display     => 'off',
        renderers   => [ 'off', 'Off', 'compact', 'On' ],
        description => qq{<a href="/info/genome/compara/analyses.html#conservation">$n_species way whole-genome multiple alignments</a>.; } .
                       join('; ', sort map { $species_defs->species_label($_, 'no_formatting') } grep { $_ ne 'ancestral_sequences' } keys %{$row->{'species'}}),
      };
    }
  }

  foreach my $menu_key (keys %$alignments) {
    my $menu = $self->get_node($menu_key);
    next unless $menu;

    foreach my $key_2 (sort { $alignments->{$menu_key}{$a}{'order'} cmp  $alignments->{$menu_key}{$b}{'order'} } keys %{$alignments->{$menu_key}}) {
      my $row = $alignments->{$menu_key}{$key_2};
      $menu->append_child($self->create_track_node("alignment_${key}_$key_2", $row->{'caption'}, $row));
    }
  }
}

#----------------------------------------------------------------------#
# Functions to add tracks from functional genomics like database       #
#----------------------------------------------------------------------#

# needs configuring so tracks only display if data in species fg_database
sub add_regulation_features {
  my ($self, $key, $hashref) = @_;
  my $menu = $self->get_node('functional');

  return unless $menu;

  my $reg_regions       = $menu->append_child($self->create_menu_node('functional_other_regulatory_regions', 'Other regulatory regions'));

  my ($keys_1, $data_1) = $self->_merge($hashref->{'feature_set'});
  my ($keys_2, $data_2) = $self->_merge($hashref->{'alignment'});
  my %fg_data           = (%$data_1, %$data_2);

  foreach my $key_2 (sort grep { !/Regulatory_Build|seg_/ } @$keys_1, @$keys_2) {
    my $type = $fg_data{$key_2}{'type'};

    next if !$type || $type eq 'ctcf';

    my @renderers;

    if ($fg_data{$key_2}{'renderers'}) {
      push @renderers, $_, $fg_data{$key_2}{'renderers'}{$_} for sort keys %{$fg_data{$key_2}{'renderers'}};
    } else {
      @renderers = qw(off Off normal On);
    }

    $reg_regions->append_child($self->create_track_node("${type}_${key}_$key_2", $fg_data{$key_2}{'name'}, {
      db          => $key,
      glyphset    => $type,
      sources     => 'undef',
      strand      => 'r',
      labels      => 'on',
      depth       => $fg_data{$key_2}{'depth'}     || 0.5,
      colourset   => $fg_data{$key_2}{'colourset'} || $type,
      display     => $fg_data{$key_2}{'display'}   || 'off',
      description => $fg_data{$key_2}{'description'},
      priority    => $fg_data{$key_2}{'priority'},
      logic_name  => $fg_data{$key_2}{'logic_names'}[0],
      renderers   => \@renderers,
    }));

    if ($fg_data{$key_2}{'description'} =~ /cisRED/) {
      $reg_regions->append_child($self->create_track_node("${type}_${key}_search", 'cisRED Search Regions', {
        db          => $key,
        glyphset    => 'regulatory_search_regions',
        sources     => 'undef',
        strand      => 'r',
        labels      => 'on',
        depth       => 0.5,
        colourset   => 'regulatory_search_regions',
        description => 'cisRED Search Regions',
        display     => 'off',
      }));
    }
  }

  # Add other bigBed-based tracks
  my $methylation_menu  = $reg_regions->before($self->create_menu_node('functional_dna_methylation', 'DNA Methylation'));
  my $db_tables         = {};
  if ( $self->databases->{'DATABASE_FUNCGEN'} ) {
    $db_tables          = $self->databases->{'DATABASE_FUNCGEN'}{'tables'};
  }
  my %file_tracks = ( 'methylation' => {'menu'      => $methylation_menu,
                                        'renderers' => [ qw(off Off compact On) ],
                                        'default'   => 'compact',
                                        'strand'    => 'r'},
                      'crispr'      => {'menu'      => $reg_regions,
                                        'renderers' => $self->_transcript_renderers,
                                        'default'   => 'as_transcript_label',
                                        'strand'    => 'b'},
                    );

  while (my ($key, $settings) = each (%file_tracks)) {
    my $dataset = $db_tables->{$key};
    foreach my $k (sort { $dataset->{$a}{'description'} cmp $dataset->{$b}{'description'} } keys %$dataset) {
      (my $name = $dataset->{$k}{'name'}) =~ s/_/ /g;
      $settings->{'menu'}->append_child($self->create_track_node($key.'_'.$k, $name, {
        data_id      => $k,
        description  => $dataset->{$k}{'description'},
        strand       => $settings->{'strand'},
        nobump       => 1,
        addhiddenbgd => 1,
        display      => 'off',
        default_display => $settings->{'default'},
        renderers       => $settings->{'renderers'},
        glyphset        => 'fg_'.$key,
        colourset    => 'seq',
      }));
    }
  }

  $self->add_track('information', 'fg_methylation_legend', 'Methylation Legend', 'fg_methylation_legend', { strand => 'r' });

  ## Add motif features
  my $motif_feats = $reg_regions->append_child($self->create_track_node('fg_motif_features', 'Motif features'), {
      db          => $key,
      glyphset    => 'fg_motif_features',
      sources     => 'undef',
      strand      => 'r',
      labels      => 'on',
      depth       => 1,
      colourset   => 'fg_motif_features',
      display     => 'off',
      description => 'Transcription Factor Binding Motif sites', 
      renderers   => ['off', 'Off', 'compact', 'Compact'],
  });
  $self->add_track('information', 'fg_motif_features_legend',      'Motif Feature Legend',              'fg_motif_features_legend',   { strand => 'r', colourset => 'fg_motif_features'   });
}

sub add_regulation_builds {
  my ($self, $key, $hashref,$species,$params) = @_;
  my $menu = $self->get_node('functional');

  return unless $menu;

  my ($keys, $data) = $self->_merge($hashref->{'regulatory_build'});
  my $key_2         = 'Regulatory_Build';
  my $build         = $data->{$key_2};
  my $type          = $data->{$key_2}{'type'};

  return unless $type;

  my $hub = $self->hub;
  my $db  = $hub->database('funcgen', $self->species);

  return unless $db;

  $menu = $menu->append_child($self->create_menu_node('regulatory_features', 'Regulatory features'));

  ## Main regulation track - replaces 'MultiCell'
  $menu->append_child($self->create_track_node("regbuild", "Regulatory Build", {
    glyphset    => 'fg_regulatory_features',
    sources     => 'undef',
    strand      => 'r',
    labels      => 'on',
    depth       => 0,
    colourset   => 'fg_regulatory_features',
    display     => 'normal',
    description => $self->databases->{'DATABASE_FUNCGEN'}{'tables'}{'regulatory_build'}{'analyses'}{'Regulatory_Build'}{'desc'}{'reg_feats'},
    renderers   => [qw(off Off normal On)],
    caption     => 'Regulatory Build',
  }));

  my $db_tables     = {};
  if ( defined $self->databases->{'DATABASE_FUNCGEN'} ) {
    $db_tables      = $self->databases->{'DATABASE_FUNCGEN'}{'tables'};
  }
  my $reg_feats     = $menu->append_child($self->create_menu_node('reg_features', 'Epigenomic activity'));
  my $reg_segs      = $menu->append_child($self->create_menu_node('seg_features', 'Segmentation features'));
  my $adaptor       = $db->get_FeatureTypeAdaptor;
  my $evidence_info = $adaptor->get_regulatory_evidence_info;

  my (@cell_lines, %cell_names, %epi_desc, %regbuild);

  foreach (keys %{$db_tables->{'cell_type'}{'ids'}||{}}) {
    (my $name = $_) =~ s/:\w+$//;
    push @cell_lines, $name;
    $cell_names{$name} = $db_tables->{'cell_type'}{'names'}{$_}||$name;
    $epi_desc{$name} = $db_tables->{'cell_type'}{'epi_desc'}{$_}||$name;
    ## Add to lookup for regulatory build cell lines
    $regbuild{$name} = 1 if $db_tables->{'cell_type'}{'regbuild_ids'}{$_};
  }
  @cell_lines = sort { $a cmp $b } @cell_lines;

  my (@renderers, %matrix_menus, %matrix_rows);

  # FIXME: put this in db
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

  if ($data->{$key_2}{'renderers'}) {
    push @renderers, $_, $data->{$key_2}{'renderers'}{$_} for sort keys %{$data->{$key_2}{'renderers'}};
  } else {
    @renderers = qw(off Off normal On);
  }

  my %all_types;
  foreach my $set (qw(core non_core)) {
    $all_types{$set} = [];
    foreach (@{$evidence_info->{$set}{'classes'}}) {
      foreach (@{$adaptor->fetch_all_by_class($_)}) {
        push @{$all_types{$set}},$_;
      }
    }
  }

  my @sets = qw(core non_core);

  foreach my $cell_line (@cell_lines) {
    ### Add tracks for cell_line peaks and wiggles only if we have data to display
    my $set_info;
    $set_info->{'core'}     = $db_tables->{'feature_types'}{'core'}{$cell_line} || {};
    $set_info->{'non_core'} = $db_tables->{'feature_types'}{'non_core'}{$cell_line}      || {};
  
    #use Data::Dumper; 
    #$Data::Dumper::Maxdepth = 2;
    #warn Dumper($set_info->{'core'});

    my $core_count      = scalar keys %{$set_info->{'core'}};
    my $non_core_count  = scalar keys %{$set_info->{'non_core'}};

    foreach my $set (@sets) {
      $matrix_menus{$set} ||= [ "reg_feats_$set", $evidence_info->{$set}{'name'}, {
        menu   => 'matrix',
        url    => $hub->url('Config', { 'matrix' => 1, 'menu' => "reg_feats_$set" }),
        matrix => {
          section     => $menu->data->{'caption'},
          header      => $evidence_info->{$set}{'long_name'},
          description => $db_tables->{'regulatory_build'}{'analyses'}{'Regulatory_Build'}{'desc'}{$set},
          axes        => { x => 'Cell type', y => 'Evidence type' },
        }
      }];

      foreach (@{$all_types{$set}||[]}) {
        #warn ">>> ADDING TRACKS TO MATRIX FOR ID ".$_->dbID;
        if ($set_info->{$set}{$_->dbID}) {
          $matrix_rows{$cell_line}{$set}{$_->name} ||= {
                            row         => $_->name,
                            group       => $_->class,
                            group_order => $_->class =~ /^(Polymerase|Open Chromatin)$/ ? 1 : 2,
                            on          => $default_evidence_types{$_->name}
                          };
        }
      }
    }
  }

  $matrix_menus{$_} = $menu->after($self->create_menu_node(@{$matrix_menus{$_}})) for 'non_core', 'core';

  # Segmentation tracks
  my $segs = $hashref->{'segmentation'};

  # Skip the rows property as it throws an exception
  my @seg_keys = grep { $_ ne 'rows' } keys %$segs;

  foreach my $key (sort { $segs->{$a}{'desc'} cmp $segs->{$b}{'desc'} } @seg_keys) {
    my $name = $segs->{$key}{'name'};
    my $cell_line = $key;
    my $epi_desc = $segs->{$key}{'epi_desc'} ? " ($segs->{$key}{'epi_desc'})" : "";
    $reg_segs->append_child($self->create_track_node("seg_$key", $name, {
      db            => $key,
      glyphset      => 'fg_segmentation_features',
      sources       => 'undef',
      strand        => 'r',
      labels        => 'on',
      depth         => 0,
      colourset     => 'fg_segmentation_features',
      display       => 'off',
      description   => $segs->{$key}{'desc'} . $epi_desc,
      renderers     => [qw(off Off compact On)],
      celltype      => $segs->{$key}{'web'}{'celltype'},
      seg_name      => $segs->{$key}{'web'}{'seg_name'},
      caption       => "Segmentation features",
      section_zmenu => { type => 'regulation', cell_line => $cell_line, _id => "regulation:$cell_line" },
      section       => $segs->{$key}{'web'}{'celltypename'},
      height        => 4,
    }));
  }
  foreach my $cell_line (@cell_lines) {
    my $track_key = "reg_feats_$cell_line";
    my $display   = 'off';
    my $label     = ": $cell_line";
    my %evidence_tracks;

    ## Only add regulatory features if they're in the main build
    if ($regbuild{$cell_line}) {

      my $epi_desc = $epi_desc{$cell_line} ? " ($epi_desc{$cell_line})" : '';
      $reg_feats->append_child($self->create_track_node($track_key, "$cell_names{$cell_line}", {
        db            => $key,
        glyphset      => $type,
        sources       => 'undef',
        strand        => 'r',
        depth         => $data->{$key_2}{'depth'}     || 0.5,
        colourset     => $data->{$key_2}{'colourset'} || $type,
        description   => "Activity types in epigenome $cell_names{$cell_line}" . $epi_desc,
        display       => $display,
        renderers     => \@renderers,
        cell_line     => $cell_line,
        section       => $cell_names{$cell_line},
        section_zmenu => { type => 'regulation', cell_line => $cell_line, _id => "regulation:$cell_line" },
        caption       => "Epigenome Activity",
      }));
    }

    my %column_data = (
      db        => $key,
      glyphset  => 'fg_multi_wiggle',
      strand    => 'r',
      depth     => $data->{$key_2}{'depth'} || 0.5,
      colourset => 'feature_set',
      cell_line => $cell_line,
      section   => $cell_line,
      menu_key  => 'regulatory_features',
      renderers => [
        'off',            'Off',
        'compact',        'Peaks',
        'signal',         'Signal',
        'signal_feature', 'Both',
      ],
    );

    next if $params->{'reg_minimal'};
    foreach (grep exists $matrix_rows{$cell_line}{$_}, keys %matrix_menus) {
      $self->_add_matrix({
        track_name  => "$evidence_info->{$_}{'name'}$label",
        section     => $cell_line,
        matrix      => {
                        menu          => $matrix_menus{$_}->id,
                        column        => $cell_line,
                        column_label  => $cell_names{$cell_line},
                        section       => $cell_line,
                        rows          => [ values %{$matrix_rows{$cell_line}{$_}} ],
                        },
        column_data => {
                        set         => $_,
                        label       => "$evidence_info->{$_}{'label'}",
                        description => $data->{$key_2}{'description'}{$_},
                        %column_data
                        },
      }, $matrix_menus{$_});
    }
  }

  if ($db_tables->{'cell_type'}{'ids'}) {
    $self->add_track('information', 'fg_regulatory_features_legend',      'Regulation Legend',              'fg_regulatory_features_legend',   { strand => 'r', colourset => 'fg_regulatory_features'   });
    $self->add_track('information', 'fg_segmentation_features_legend',    'Segmentation Legend',            'fg_segmentation_features_legend', { strand => 'r', colourset => 'fg_segmentation_features' });
    $self->add_track('information', 'fg_multi_wiggle_legend',             'Cell/Tissue Regulation Legend',  'fg_multi_wiggle_legend',          { strand => 'r', display => 'off' });
  }
}

sub add_oligo_probes {
  my ($self, $key, $hashref) = @_;
  my $menu = $self->get_node('oligo');

  return unless $menu;

  my $data        = $hashref->{'oligo_feature'}{'arrays'};
  my $description = $hashref->{'oligo_feature'}{'analyses'}{'AlignAffy'}{'desc'};  # Different loop - no analyses - base on probeset query results

  foreach my $key_2 (sort keys %$data) {
    my $key_3 = $key_2;
    $key_2    =~ s/:/__/;

    $menu->append_child($self->create_track_node("oligo_${key}_" . uc $key_2, $key_3, {
      glyphset    => '_oligo',
      db          => $key,
      sub_type    => 'oligo',
      array       => $key_2,
      object_type => 'ProbeFeature',
      colourset   => 'feature',
      description => $description,
      caption     => $key_3,
      strand      => 'b',
      display     => 'off',
      renderers   => $self->_alignment_renderers
    }));
  }
}

sub update_cell_type {
  ## Updates user settings for cell types for reg based image configs
  my ($self, $changes) = @_;

  foreach my $track (grep $_->get_data('node_type') eq 'track', @{$self->tree->root->get_all_nodes}) {
    for (keys %$changes) {
      if (clean_id($track->get_data('cell_line')) eq clean_id($_)) {
        $self->update_track_renderer($track, $changes->{$_});
      }
    }
  }

  $self->save_user_settings;
}

sub update_evidence {
  ## Updates user settings for evidences for reg based image configs
  my ($self, $changes) = @_;

  foreach my $type (qw(reg_feats_core reg_feats_non_core)) {
    my $menu = $self->get_node($type);
    next unless $menu;

    foreach my $option (@{$menu->get_all_nodes}) {
      for (keys %$changes) {
        if (clean_id($option->get_data('name')) eq clean_id($_)) {
          $self->update_track_renderer($option, $changes->{$_});
        }
      }
    }
  }

  $self->save_user_settings;
}

sub update_reg_renderer {
  ## Updates user settings for reg track renderer - signal, peak or both
  my ($self, $renderer, $state) = @_;

  my $mask = firstidx { $renderer eq $_ } qw(x peaks signals);

  foreach my $type (qw(reg_features seg_features reg_feats_core reg_feats_non_core)) {
    my $menu = $self->get_node($type);
    next unless $menu;
    foreach my $node (@{$menu->child_nodes}) {
      my $old = $node->get('display');
      my $renderer = firstidx { $old eq $_ }
        qw(off compact signal signal_feature);
      next if $renderer <= 0;
      $renderer |= $mask if $state;
      $renderer &=~ $mask unless $state;
      $renderer = 1 unless $renderer;
      $renderer = [ qw(off compact signal signal_feature) ]->[$renderer];
      $self->update_track_renderer($node, $renderer);
    }
  }

  $self->save_user_settings;
}

#----------------------------------------------------------------------#
# Functions to add tracks from variation like databases                #
#----------------------------------------------------------------------#

sub add_sequence_variations {
  my ($self, $key, $hashref) = @_;
  my $menu = $self->get_node('variation');

  return unless $menu && $hashref->{'variation_feature'}{'rows'} > 0;

  my $options = {
    db         => $key,
    glyphset   => 'variation',
    strand     => 'r',
    depth      => 0.5,
    bump_width => 0,
    colourset  => 'variation',
    display    => 'off',
    renderers  => [ 'off', 'Off', 'normal', 'Normal (collapsed for windows over 200kb)', 'compact', 'Collapsed', 'labels', 'Expanded with name (hidden for windows over 10kb)', 'nolabels', 'Expanded without name' ],
  };

  if (defined($hashref->{'menu'}) && scalar @{$hashref->{'menu'}}) {
    $self->add_sequence_variations_meta($key, $hashref, $options);
  } else {
    $self->add_sequence_variations_default($key, $hashref, $options);
  }

  $self->add_sequence_variations_vcf($key, $hashref, $options);

  $self->add_track('information', 'variation_legend', 'Variant Legend', 'variation_legend', { strand => 'r' });
}

# adds variation tracks in structure defined in variation meta table
sub add_sequence_variations_meta {
  my ($self, $key, $hashref, $options) = @_;
  my $menu = $self->get_node('variation');
  my $suffix_caption = ' - short variants (SNPs and indels)';
  my $short_suffix_caption = ' SNPs/indels';
  my $regexp_suffix_caption = $suffix_caption;
     $regexp_suffix_caption =~ s/\(/\\\(/;
     $regexp_suffix_caption =~ s/\)/\\\)/;

  my @menus;
  foreach my $menu_item (@{$hashref->{'menu'}}) {
    next if $menu_item->{'type'} =~  /^sv_/; # exclude structural variant items

    $menu_item->{order} = 5; # Default value

    if ($menu_item->{type} =~ /menu/) {
      if ($menu_item->{'long_name'} =~ /^sequence variants/i){
        $menu_item->{order} = 1;
      }
      elsif ($menu_item->{'long_name'} =~ /phenotype/i) {
        $menu_item->{order} = 2;
      }
    }
    else {
      if ($menu_item->{'long_name'} =~ /clinvar/i) {
        $menu_item->{order} = ($menu_item->{'long_name'} =~ /all /i) ? 1 : 2;
      }
      elsif ($menu_item->{'long_name'} =~ /all( |$)/i) {
        $menu_item->{order} = 3;
      }
      elsif ($menu_item->{'long_name'} =~ /dbsnp/i) {
        $menu_item->{order} = 4;
      }
    }
    push(@menus, $menu_item);
  }
  foreach my $menu_item (sort {$a->{type} !~ /menu/ cmp $b->{type} !~ /menu/ || $a->{parent} cmp $b->{parent} ||
                               $a->{order} <=> $b->{order} || $a->{'long_name'} cmp $b->{'long_name'}
                              } @menus) {
    my $node;
    my $track_options = $options;
    $track_options->{'db'} = 'variation_private' if ($menu_item->{'long_name'} =~ /(DECIPHER|LOVD)/i);

    if ($menu_item->{'type'} eq 'menu' || $menu_item->{'type'} eq 'menu_sub') { # just a named submenu
      $node = $self->create_menu_node($menu_item->{'key'}, $menu_item->{'long_name'});
    } elsif ($menu_item->{'type'} eq 'source') { # source type

      my $other_sources = ($menu_item->{'long_name'} =~ /all other sources/);

      (my $source_name   = $menu_item->{'long_name'}) =~ s/\svariants$//i;
      (my $caption       = $menu_item->{'long_name'}) =~ s/\svariants$/$suffix_caption/;
      (my $label_caption = $menu_item->{'short_name'}) =~ s/\svariants$/$short_suffix_caption/;
      $label_caption .= $short_suffix_caption if ($label_caption !~ /$short_suffix_caption/);

      $node = $self->create_track_node($menu_item->{'key'}, $menu_item->{'long_name'}, {
        %$track_options,
        caption      => $caption,
        labelcaption => $label_caption,
        sources      => $other_sources ? undef : [ $source_name ],
        description  => $other_sources ? 'Sequence variants from all sources' : $hashref->{'source'}{'descriptions'}{$source_name},
      });

      # Study tracks
    } elsif ($menu_item->{'type'} eq 'study') {
      my $study_name    = $menu_item->{'long_name'};
      my $caption       = $menu_item->{'long_name'};
      my $label_caption = $menu_item->{'short_name'};
      my $description   = $hashref->{'study'}{'descriptions'}{$study_name};

      $node = $self->create_track($menu_item->{'key'}, $menu_item->{'long_name'}, {
        %$track_options,
        caption      => $caption,
        labelcaption => $label_caption,
        study_name   => $study_name,
        description  => ($description) ? $description : $study_name,
      });

    } elsif ($menu_item->{'type'} eq 'set') { # set type
      if ($menu_item->{'long_name'} =~ /\svariants$/i) {
        $menu_item->{'long_name'} =~ s/\svariants$/$suffix_caption/;
      }
      elsif ($menu_item->{'long_name'} !~ /$regexp_suffix_caption$/){# / short variants \(SNPs and indels\)$/){
        $menu_item->{'long_name'} .= $suffix_caption;
      }

      (my $temp_name = $menu_item->{'key'})       =~ s/^variation_set_//;
      (my $caption   = $menu_item->{'long_name'});
      (my $label_caption   = $menu_item->{'short_name'}) =~ s/1000 Genomes/1KG/;  # shorten name for side of image
      $label_caption .= $short_suffix_caption;
      (my $set_name  = $menu_item->{'long_name'}) =~ s/All HapMap/HapMap/; # hack for HapMap set name - remove once variation team fix data for 68

      $node = $self->create_track_node($menu_item->{'key'}, $menu_item->{'long_name'}, {
        %$track_options,
        caption      => $caption,
        labelcaption => $label_caption,
        sources      => undef,
        sets         => [ $temp_name ],
        set_name     => $set_name,
        description  => $hashref->{'variation_set'}{'descriptions'}{$temp_name}
      });
    }

    # get the node onto which we're going to add this item, then append it
#    if ($menu_item->{'long_name'} =~ /^all/i || $menu_item->{'long_name'} =~ /^sequence variants/i) {
    if ($menu_item->{'long_name'} =~ /^sequence variants/i) {
      ($menu_item->{'parent'} && $self->get_node($menu_item->{'parent'}) || $menu)->prepend($node) if $node;
    }
    else {
      ($menu_item->{'parent'} && $self->get_node($menu_item->{'parent'}) || $menu)->append_child($node) if $node;
    }
  }
}

# adds variation tracks the old, hacky way
sub add_sequence_variations_default {
  my ($self, $key, $hashref, $options) = @_;
  my $menu = $self->get_node('variation');
  my $sequence_variation = ($menu->get_node('variants')) ? $menu->get_node('variants') : $self->create_menu_node('variants', 'Sequence variants');
  my $prefix_caption = 'Variant - ';

  my $title = 'Sequence variants (all sources)';

  $sequence_variation->append_child($self->create_track_node("variation_feature_$key", $title, {
    %$options,
    caption     => $prefix_caption.'All sources',
    sources     => undef,
    description => 'Sequence variants from all sources',
  }));

  foreach my $key_2 (sort{$a !~ /dbsnp/i cmp $b !~ /dbsnp/i} keys %{$hashref->{'source'}{'counts'} || {}}) {
    next unless $hashref->{'source'}{'counts'}{$key_2} > 0;
    next if     $hashref->{'source'}{'somatic'}{$key_2} == 1;

    $sequence_variation->append_child($self->create_track_node("variation_feature_${key}_$key_2", "$key_2 variants", {
      %$options,
      caption     => $prefix_caption.$key_2,
      sources     => [ $key_2 ],
      description => $hashref->{'source'}{'descriptions'}{$key_2},
    }));
  }

  $menu->append_child($sequence_variation);

  # add in variation sets
  if ($hashref->{'variation_set'}{'rows'} > 0 ) {
    my $variation_sets = $self->create_menu_node('variation_sets', 'Variation sets');

    $menu->append_child($variation_sets);

    foreach my $toplevel_set (
      sort { !!scalar @{$a->{'subsets'}} <=> !!scalar @{$b->{'subsets'}} }
      sort { $a->{'name'} =~ /^failed/i  <=> $b->{'name'} =~ /^failed/i  }
      sort { $a->{'name'} cmp $b->{'name'} }
      values %{$hashref->{'variation_set'}{'supersets'}}
    ) {
      my $name          = $toplevel_set->{'name'};
      my $caption       = $name . (scalar @{$toplevel_set->{'subsets'}} ? ' (all data)' : '');
      my $key           = $toplevel_set->{'short_name'};
      my $set_variation = scalar @{$toplevel_set->{'subsets'}} ? $self->create_menu_node("set_variation_$key", $name) : $variation_sets;

      $set_variation->append_child($self->create_track_node("variation_set_$key", $caption, {
        %$options,
        caption     => $prefix_caption.$caption,
        sources     => undef,
        sets        => [ $key ],
        set_name    => $name,
        description => $toplevel_set->{'description'},
      }));

      # add in sub sets
      if (scalar @{$toplevel_set->{'subsets'}}) {
        foreach my $subset_id (sort @{$toplevel_set->{'subsets'}}) {
          my $sub_set             = $hashref->{'variation_set'}{'subsets'}{$subset_id};
          my $sub_set_name        = $sub_set->{'name'};
          my $sub_set_description = $sub_set->{'description'};
          my $sub_set_key         = $sub_set->{'short_name'};

          $set_variation->append_child($self->create_track_node("variation_set_$sub_set_key", $sub_set_name, {
            %$options,
            caption     => $prefix_caption.$sub_set_name,
            sources     => undef,
            sets        => [ $sub_set_key ],
            set_name    => $sub_set_name,
            description => $sub_set_description
          }));
        }

        $variation_sets->append_child($set_variation);
      }
    }
  }
}

sub add_sequence_variations_vcf {
  my ($self, $key, $hashref, $options) = @_;

  my $hub = $self->hub;
  my $c = $hub->species_defs->multi_val('ENSEMBL_VCF_COLLECTIONS');
  return unless $c->{'ENABLED'};

  # my $sequence_variation = ($menu->get_node('variants')) ? $menu->get_node('variants') : $self->create_menu_node('variants', 'Sequence variants');
  my $menu = $self->get_node('variation');

  my $vcf_menu = $self->create_menu_node('vcf_collections', 'VCF tracks');
  $menu->append_child($vcf_menu);

  my $db  = $hub->database('variation', $self->species);
  my $ad  = $db->get_VCFCollectionAdaptor();

  foreach my $coll(@{$ad->fetch_all_for_web}) {
    $vcf_menu->append_child($self->create_track_node("variation_vcf_".$coll->id, $coll->id, {
      %$options,
      caption     => $coll->id,
      description => $coll->description,
      db          => 'variation',
    }));
  }
}

sub add_phenotypes {
  my ($self, $key, $hashref) = @_;

  return unless $hashref->{'phenotypes'}{'rows'} > 0;

  my $p_menu = $self->get_node('phenotype');

  unless($p_menu) {
    my $menu = $self->get_node('variation');
    return unless $menu;
    $p_menu = $self->create_menu_node('phenotype', 'Phenotype annotations');
    $menu->append_child($p_menu);
  }

  return unless $p_menu;

  my $pf_menu = $self->create_menu_node('phenotype_features', 'Phenotype annotations');

  my %options = (
    db => $key,
    glyphset => 'phenotype_feature',
    depth      => '5',
    bump_width => 0,
    colourset  => 'phenotype_feature',
    display    => 'off',
    strand     => 'r',
    renderers  => [ 'off', 'Off', 'gene_nolabel', 'Expanded', 'compact', 'Compact' ],
  );

  my $track_desc = 'Disease, Trait and Phenotype annotations on ';

  foreach my $type( sort {$a cmp $b} keys %{$hashref->{'phenotypes'}{'types'}}) {
    next unless ref $hashref->{'phenotypes'}{'types'}{$type} eq 'HASH';
    my $pf_sources = $hashref->{'phenotypes'}{'types'}{$type}{'sources'};
    $pf_menu->prepend($self->create_track_node('phenotype_'.lc($type), 'Phenotype annotations ('.$type.'s)', {
      %options,
      caption => 'Phenotypes ('.$type.'s)',
      type => $type,
      description => $track_desc.$type.'s (from '.$pf_sources.')',
    }));
  }

  $pf_menu->prepend($self->create_track_node('phenotype_all', 'Phenotype annotations (all types)', {
    %options,
    caption => 'Phenotypes',
    type => undef,
    description => $track_desc.(join ", ", map {$_.'s'} keys %{$hashref->{'phenotypes'}{'types'}}),
  }));
  $p_menu->append_child($pf_menu);
}

sub add_structural_variations {
  my ($self, $key, $hashref) = @_;
  my $menu = $self->get_node('variation');
  my @A = keys %$hashref;

  return unless $menu && scalar(keys(%{$hashref->{'structural_variation'}{'counts'}})) > 0;
  my $prefix_caption      = 'SV - ';
  my $suffix              = '(structural variants)';
  my $sv_menu             = $self->create_menu_node('structural_variation', 'Structural variants');
  my $structural_variants = $self->create_menu_node('structural_variants',  'Structural variants');
  my $desc                = 'The colours correspond to the structural variant classes.';
     $desc               .= '<br />For an explanation of the display, see the <a rel="external" href="http://www.ncbi.nlm.nih.gov/dbvar/content/overview/#representation">dbVar documentation</a>.';
  my %options             = (
    glyphset   => 'structural_variation',
    strand     => 'r',
    bump_width => 0,
    height     => 6,
    depth      => 100,
    colourset  => 'structural_variant',
    display    => 'off',
    renderers  => [ 'off', 'Off', 'compact', 'Compact', 'gene_nolabel', 'Expanded' ],
  );

  # Complete overlap (Larger structural variants)
  $structural_variants->prepend($self->create_track_node('variation_feature_structural_larger', 'Larger structural variants (all sources)', {
    %options,
    db          => 'variation',
    caption     => $prefix_caption.'Larger variants',
    source      => undef,
    description => "Structural variants from all sources which are at least 1Mb in length. $desc",
    min_size    => 1e6,
  }));

  # Partial overlap (Smaller structural variants)
  $structural_variants->prepend($self->create_track_node('variation_feature_structural_smaller', 'Smaller structural variants (all sources)', {
    %options,
    db         => 'variation',
    caption     => $prefix_caption.'Smaller variants',
    source      => undef,
    description => "Structural variants from all sources which are less than 1Mb in length. $desc",
    depth       => 10,
    max_size    => 1e6 - 1,
  }));

  foreach my $key_2 (sort keys %{$hashref->{'structural_variation'}{'counts'} || {}}) {
    ## FIXME - Nasty hack to get variation tracks correctly configured
    next if ($key_2 =~ /(DECIPHER|LOVD)/);
    $structural_variants->append_child($self->create_track_node("variation_feature_structural_$key_2", "$key_2 $suffix", {
      %options,
      db          => 'variation',
      caption     => $prefix_caption.$key_2,
      source      => $key_2,
      description => $hashref->{'source'}{'descriptions'}{$key_2},
    }));
  }

  # DECIPHER and LOVD structural variants (Human)
  foreach my $menu_item (grep {$_->{'type'} eq 'sv_private'} @{$hashref->{'menu'} || []}) {

    my $node_name = "$menu_item->{'long_name'} $suffix";
    my $caption   = "$prefix_caption$menu_item->{'long_name'}";

    my $name = $menu_item->{'key'};
    $structural_variants->append_child($self->create_track_node("variation_feature_structural_$name", "$node_name", {
      %options,
      db          => 'variation_private',
      caption     => $prefix_caption.$name,
      source      => $name,
      description => $hashref->{'source'}{'descriptions'}{$name},
    }));
  }

  # Structural variation sets and studies
  foreach my $menu_item (sort {$a->{type} cmp $b->{type} || $a->{long_name} cmp $b->{long_name}} @{$hashref->{'menu'} || []}) {
    next if $menu_item->{'type'} !~ /^sv_/ || $menu_item->{'type'} eq 'sv_private';

    my $node_name = "$menu_item->{'long_name'} $suffix";
    my $caption   = "$prefix_caption$menu_item->{'long_name'}";
    my $labelcaption = $caption;
    $labelcaption   =~ s/1000 Genomes/1KG/;

    my $db = 'variation';

    if ($menu_item->{'type'} eq 'sv_set') {
      my $temp_name = $menu_item->{'key'};
         $temp_name =~ s/^sv_set_//;

      $structural_variants->append_child($self->create_track_node($menu_item->{'key'}, $node_name, {
        %options,
        db          => $db,
        caption     => $caption,
        labelcaption => $labelcaption,
        source      => undef,
        sets        => [ $menu_item->{'long_name'} ],
        set_name    => $menu_item->{'long_name'},
        description => $hashref->{'variation_set'}{'descriptions'}{$temp_name},
      }));
    }
    elsif ($menu_item->{'type'} eq 'sv_study') {
      my $name = $menu_item->{'key'};

      $structural_variants->append_child($self->create_track_node($name, $node_name, {
        %options,
        db          => $db,
        caption     => $caption,
        source      => undef,
        study       => [ $name ],
        study_name  => $name,
        description => 'DGVa study: '.$hashref->{'structural_variation'}{'study'}{'descriptions'}{$name},
      }));
    }
  }

  $self->add_track('information', 'structural_variation_legend', 'Structural Variant Legend', 'structural_variation_legend', { strand => 'r' });

  $sv_menu->append_child($structural_variants);
  $menu->append_child($sv_menu);
}

sub add_copy_number_variant_probes {
  my ($self, $key, $hashref) = @_;
  my $menu = $self->get_node('variation');

  return unless $menu && scalar(keys(%{$hashref->{'structural_variation'}{'cnv_probes'}{'counts'}})) > 0;

  my $sv_menu        = $self->get_node('structural_variation') || $menu->append_child($self->create_menu_node('structural_variation', 'Structural variants'));
  my $cnv_probe_menu = $self->create_menu_node('cnv_probe','Copy number variant probes');

  my %options = (
    db         => $key,
    glyphset   => 'cnv_probes',
    strand     => 'r',
    bump_width => 0,
    height     => 6,
    colourset  => 'structural_variant',
    display    => 'off'
  );

  $cnv_probe_menu->append_child($self->create_track_node('variation_feature_cnv', 'Copy number variant probes (all sources)', {
    %options,
    caption     => 'CNV probes',
    sources     => undef,
    depth       => 10,
    description => 'Copy number variant probes from all sources'
  }));

  foreach my $key_2 (sort keys %{$hashref->{'structural_variation'}{'cnv_probes'}{'counts'} || {}}) {
    $cnv_probe_menu->append_child($self->create_track_node("variation_feature_cnv_$key_2", "$key_2", {
      %options,
      caption     => $key_2,
      source      => $key_2,
      depth       => 0.5,
      description => $hashref->{'source'}{'descriptions'}{$key_2}
    }));
  }

  $sv_menu->append_child($cnv_probe_menu);
}

# The recombination menu contains tracks with information pertaining to variation project, but these tracks actually simple_features stored in the core database
# As core databases are loaded before variation databases, the recombination submenu appears at the top of the variation menu tree, which isn't desirable.
# This function moves it to the end of the tree.
sub add_recombination {
  my ($self, @args) = @_;
  my $menu   = $self->get_node('recombination');
  my $parent = $self->get_node('variation');

  $parent->append_child($menu) if $menu && $parent;
}

sub add_somatic_mutations {
  my ($self, $key, $hashref) = @_;

  # check we have any sources with somatic data
  return unless $hashref->{'source'}{'somatic'} && grep {$_} values %{$hashref->{'source'}{'somatic'}};

  my $menu = $self->get_node('somatic');
  return unless $menu;

  my $prefix_caption = 'Variant - ';
  my $somatic = $self->create_menu_node('somatic_mutation', 'Somatic variants');
  my %options = (
    db         => $key,
    glyphset   => 'variation',
    strand     => 'r',
    depth      => 0.5,
    bump_width => 0,
    colourset  => 'variation',
    display    => 'off',
    renderers  => [ 'off', 'Off', 'normal', 'Normal (collapsed for windows over 200kb)', 'compact', 'Collapsed', 'labels', 'Expanded with name (hidden for windows over 10kb)', 'nolabels', 'Expanded without name' ],
  );

  # All sources
  $somatic->append_child($self->create_track_node("somatic_mutation_all", "Somatic variants (all sources)", {
    %options,
    caption     => $prefix_caption.'All somatic',
    description => 'Somatic variants from all sources'
  }));


  # Mixed source(s)
  foreach my $key_1 ( ($self->species_defs->databases->{'DATABASE_VARIATION'} && keys(%{$self->species_defs->databases->{'DATABASE_VARIATION'}{'SOMATIC_MUTATIONS'}})) || [] ) {
    if ($self->species_defs->databases->{'DATABASE_VARIATION'}{'SOMATIC_MUTATIONS'}{$key_1}{'none'}) {
      (my $k = $key_1) =~ s/\W/_/g;
      $somatic->append_child($self->create_track_node("somatic_mutation_$k", "$key_1 somatic variants", {
        %options,
        caption     => $prefix_caption."$key_1 somatic",
        source      => $key_1,
        description => "Somatic variants from $key_1"
      }));
    }
  }

  # Somatic source(s)
  foreach my $key_2 (sort grep { $hashref->{'source'}{'somatic'}{$_} == 1 } keys %{$hashref->{'source'}{'somatic'}}) {
    next unless $hashref->{'source'}{'counts'}{$key_2} > 0;

    $somatic->append_child($self->create_track_node("somatic_mutation_$key_2", "$key_2 somatic mutations (all)", {
      %options,
      caption     => $prefix_caption."$key_2 somatic mutations",
      source      => $key_2,
      description => "All somatic variants from $key_2"
    }));

    my $tissue_menu = $self->create_menu_node('somatic_mutation_by_tissue', 'Somatic variants by tissue');

    ## Add tracks for each tumour site
    my %tumour_sites = ($self->species_defs->databases->{'DATABASE_VARIATION'} && %{$self->species_defs->databases->{'DATABASE_VARIATION'}{'SOMATIC_MUTATIONS'}{$key_2} || {}}) || ();

    foreach my $description (sort keys %tumour_sites) {
      next if $description eq 'none';

      my $phenotype_id           = $tumour_sites{$description};
      my ($source, $type, $site) = split /\:/, $description;
      my $formatted_site         = $site;
      $site                      =~ s/\W/_/g;
      $formatted_site            =~ s/\_/ /g;

      $tissue_menu->append_child($self->create_track_node("somatic_mutation_${key_2}_$site", "$key_2 somatic mutations in $formatted_site", {
        %options,
        caption     => "$key_2 $formatted_site tumours",
        filter      => $phenotype_id,
        description => $description
      }));
    }

    $somatic->append_child($tissue_menu);
  }

  $menu->append_child($somatic);
}

sub add_somatic_structural_variations {
  my ($self, $key, $hashref) = @_;
  my $menu = $self->get_node('somatic');

  return unless $menu && scalar(keys(%{$hashref->{'structural_variation'}{'somatic'}{'counts'}})) > 0;

  my $prefix_caption = 'SV - ';
  my $somatic = $self->create_menu_node('somatic_structural_variation', 'Somatic structural variants');

  my %options = (
    db         => $key,
    glyphset   => 'structural_variation',
    strand     => 'r',
    bump_width => 0,
    height     => 6,
    colourset  => 'structural_variant',
    display    => 'off',
    renderers  => [ 'off', 'Off', 'compact', 'Compact', 'gene_nolabel', 'Expanded' ],
  );

  $somatic->append_child($self->create_track_node('somatic_sv_feature', 'Somatic structural variants (all sources)', {
    %options,
    caption     => $prefix_caption.'Somatic',
    sources     => undef,
    description => 'Somatic structural variants from all sources. For an explanation of the display, see the <a rel="external" href="http://www.ncbi.nlm.nih.gov/dbvar/content/overview/#representation">dbVar documentation</a>. In addition, we display the breakpoints in yellow.',
    depth       => 10
  }));

  foreach my $key_2 (sort keys %{$hashref->{'structural_variation'}{'somatic'}{'counts'} || {}}) {
    $somatic->append_child($self->create_track_node("somatic_sv_feature_$key_2", "$key_2 somatic structural variants", {
      %options,
      caption     => $prefix_caption."$key_2 somatic",
      source      => $key_2,
      description => $hashref->{'source'}{'descriptions'}{$key_2},
      depth       => 100
    }));
  }

  $menu->append_child($somatic);
}

sub _transcript_types {
  return qw(transcript alignslice_transcript tsv_transcript gsv_transcript TSE_transcript);
}

sub _alignment_renderers {
  return $_[0]->{'_alignment_renderers'} ||= [
    off                   => 'Off',
    as_alignment_nolabel  => 'Normal',
    as_alignment_label    => 'Labels',
    half_height           => 'Half height',
    stack                 => 'Stacked',
    unlimited             => 'Stacked unlimited',
    ungrouped             => 'Ungrouped',
  ];
}

sub _transcript_renderers {
  return $_[0]->{'_transcript_renderers'} ||= [
    off                   => 'Off',
    as_alignment_nolabel  => 'Normal',
    as_alignment_label    => 'Labels',
    as_transcript_nolabel => 'Structure',
    as_transcript_label   => 'Structure with labels',
    half_height           => 'Half height',
    stack                 => 'Stacked',
    unlimited             => 'Stacked unlimited',
    ungrouped             => 'Ungrouped',
  ];
}

sub _gene_renderers {
  my $self = shift;

  if (!$self->{'_gene_renderers'}) {

    my @gene_renderers = @{$self->_transcript_renderers};

    splice @gene_renderers, 6, 0, 'as_collapsed_nolabel', 'Collapsed', 'as_collapsed_label', 'Collapsed with labels';

    $self->{'_gene_renderers'} = \@gene_renderers;
  }

  return $self->{'_gene_renderers'};
}

1;

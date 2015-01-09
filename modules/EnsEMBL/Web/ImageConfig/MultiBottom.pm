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

package EnsEMBL::Web::ImageConfig::MultiBottom;

use strict;

use base qw(EnsEMBL::Web::ImageConfig::MultiSpecies);

sub init {
  my $self = shift;
  
  $self->set_parameters({
    sortable_tracks => 1,  # allow the user to reorder tracks
    opt_lines       => 1,  # register lines
    spritelib       => { default => $self->species_defs->ENSEMBL_WEBROOT . '/htdocs/img/sprites' },
  });
  my $sp_img_48 = $self->species_defs->ENSEMBL_WEBROOT . '/../public-plugins/ensembl/htdocs/i/species/48'; # XXX make configurable
  if(-e $sp_img_48) {
    $self->set_parameters({ spritelib => {
      %{$self->get_parameter('spritelib')||{}},
      species => $sp_img_48,
    }});
  }

  # Add menus in the order you want them for this display
  $self->create_menus(qw(
    sequence
    marker
    transcript
    prediction
    dna_align_cdna
    dna_align_est 
    dna_align_rna 
    dna_align_other 
    protein_align
    rnaseq
    simple
    misc_feature
    variation 
    somatic 
    functional
    oligo
    repeat
    user_data
    decorations 
    information 
  ));

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
  
  # Add in additional tracks
  $self->load_tracks;
  $self->load_configured_das;
  $self->image_resize = 1;

  $self->add_tracks('sequence', 
    [ 'contig', 'Contigs',  'contig',   { display => 'normal', strand => 'r', description => 'Track showing underlying assembly contigs' }],
    [ 'seq',    'Sequence', 'sequence', { display => 'normal', strand => 'b', description => 'Track showing sequence in both directions. Only displayed at 1Kb and below.', colourset => 'seq', threshold => 1, depth => 1 }],
  );
  
  $self->add_tracks('decorations',
    [ 'scalebar',  '', 'scalebar',   { display => 'normal', strand => 'b', name => 'Scale bar', description => 'Shows the scalebar' }],
    [ 'ruler',     '', 'ruler',      { display => 'normal', strand => 'b', name => 'Ruler',     description => 'Shows the length of the region being displayed' }],
    [ 'draggable', '', 'draggable',  { display => 'normal', strand => 'b', menu => 'no' }],
    [ 'nav',       '', 'navigation', { display => 'normal', strand => 'b', menu => 'no' }]
  );
  
  $_->set('display', 'off') for grep $_->id =~ /^chr_band_/, $self->get_node('decorations')->nodes; # Turn off chromosome bands by default
}

sub multi {
  my ($self, $methods, $chr, $pos, $total, @slices) = @_;
  my $sp              = $self->{'species'};
  my $multi_hash      = $self->species_defs->multi_hash;
  my $primary_species = $self->hub->species;
  my $p               = $pos == $total && $total > 2 ? 2 : 1;
  my ($i, %alignments, @strands);
  
  foreach my $db (@{$self->species_defs->compara_like_databases || []}) {
    next unless exists $multi_hash->{$db};
    
    foreach (values %{$multi_hash->{$db}{'ALIGNMENTS'}}, @{$multi_hash->{$db}{'INTRA_SPECIES_ALIGNMENTS'}{'REGION_SUMMARY'}{$sp}{$chr} || []}) {
      next unless $methods->{$_->{'type'}};
      next unless $_->{'class'} =~ /pairwise_alignment/;
      next unless $_->{'species'}{$sp} || $_->{'species'}{"$sp--$chr"};
      
      my %align = %$_; # Make a copy for modification
      
      $i = $p;
      
      foreach (@slices) {
        if ($align{'species'}{$_->{'species'} eq $sp ? $_->{'species_check'} : $_->{'species'}} && !($_->{'species_check'} eq $primary_species && $sp eq $primary_species)) {
          $align{'order'} = $i;
          $align{'ori'}   = $_->{'strand'};
          $align{'gene'}  = $_->{'g'};
          last;
        }
        
        $i++;
      }
      
      next unless $align{'order'};
      
      $align{'db'} = lc substr $db, 9;
      
      push @{$alignments{$align{'order'}}}, \%align;
      
      $self->set_parameter('homologue', $align{'homologue'});
    }
  }
  
  if ($pos == 1) {
    @strands = $total == 2 ? qw(r) : scalar keys %alignments == 2 ? qw(f r) : [keys %alignments]->[0] == 1 ? qw(f) : qw(r); # Primary species
  } elsif ($pos == $total) {
    @strands = qw(f);   # Last species - show alignments on forward strand.
  } elsif ($pos == 2) {
    @strands = qw(r);   # First species where $total > 2
  } else {
    @strands = qw(r f); # Secondary species in the middle of the image
  }
  
  # Double up for non primary species in the middle of the image
  $alignments{2} = $alignments{1} if $pos != 1 && scalar @strands == 2 && scalar keys %alignments == 1;
  
  my $decorations = $self->get_node('decorations');
  
  foreach (sort keys %alignments) {
    my $strand = shift @strands;
    
    foreach my $align (sort { $a->{'type'} cmp $b->{'type'} } @{$alignments{$_}}) {
      my ($other_species) = grep $_ ne $sp, keys %{$align->{'species'}};
      
      $decorations->before(
        $self->create_track("$align->{'id'}:$align->{'type'}:$_", $align->{'name'}, {
          glyphset                   => '_alignment_pairwise',
          colourset                  => 'pairwise',
          name                       => $align->{'name'},
          species                    => [split '--', $other_species]->[0],
          strand                     => $strand,
          display                    => $methods->{$align->{'type'}},
          db                         => $align->{'db'},
          type                       => $align->{'type'},
          ori                        => $align->{'ori'},
          method_link_species_set_id => $align->{'id'},
          target                     => $align->{'target_name'},
          join                       => 1,
          menu                       => 'no'
        })
      );
    }
  }
  $self->add_tracks('information',
    [ 'gene_legend', 'Gene Legend','gene_legend', {  display => 'normal', strand => 'r', accumulate => 'yes' }],
    [ 'variation_legend', 'Variation Legend','variation_legend', {  display => 'normal', strand => 'r', accumulate => 'yes' }],
    [ 'fg_regulatory_features_legend',   'Reg. Features Legend', 'fg_regulatory_features_legend',   { display => 'normal', strand => 'r', colourset => 'fg_regulatory_features'   }],
    [ 'fg_methylation_legend', 'Methylation Legend', 'fg_methylation_legend', { strand => 'r' } ],
    [ 'structural_variation_legend', 'Structural Variation Legend', 'structural_variation_legend', { strand => 'r' } ],
  );
  $self->modify_configs(
    [ 'gene_legend', 'variation_legend','fg_regulatory_features_legend', 'fg_methylation_legend', 'structural_variation_legend' ],
    { accumulate => 'yes' }
  );
}

sub join_genes {
  my $self = shift;
  my ($pos, $total, @slices) = @_;
  
  my ($prev_species, $prev_target, $next_species, $next_target) = map { $_->{'species'}, $_->{'target'} } @slices;
  
  if (($pos == 1 && $total == 2) || ($pos == 2 && $total > 2)) {
     ($prev_species, $next_species) = ('', $prev_species);
     ($prev_target,  $next_target)  = ('', $prev_target);
  }
  
  if ($pos > 2 && $pos < $total && $total > 3) {
    $next_species = $prev_species;
    $next_target  = $prev_target;
  }
  
  foreach ($self->get_node('transcript')->nodes) {
    $_->set('previous_species', $prev_species) if $prev_species;
    $_->set('next_species',     $next_species) if $next_species;
    $_->set('previous_target',  $prev_target)  if $prev_target;
    $_->set('next_target',      $next_target)  if $next_target;
    $_->set('join', 1);
  }
}

sub highlight {
  my ($self, $gene) = @_;
  $_->set('g', $gene) for $self->get_node('transcript')->nodes; 
}

1;

=head1 LICENSE

Copyright [1999-2015] Wellcome Trust Sanger Institute and the EMBL-European Bioinformatics Institute
Copyright [2016-2022] EMBL-European Bioinformatics Institute

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
use warnings;

use parent qw(EnsEMBL::Web::ImageConfig::MultiSpecies);

sub init_cacheable {
  ## @override
  my $self = shift;

  $self->SUPER::init_cacheable(@_);

  $self->set_parameters({
    image_resizeable  => 1,
    sortable_tracks   => 1,  # allow the user to reorder tracks
    can_trackhubs     => 1,      # allow track hubs
    opt_lines         => 1,  # register lines
    spritelib         => { default => $self->species_defs->ENSEMBL_WEBROOT . '/htdocs/img/sprites' },
  });

  my $spritelib = {%{$self->get_parameter('spritelib')||{}}};
  my $sp_img = $self->species_defs->SPECIES_IMAGE_DIR;
  if(-e $sp_img) {
    $spritelib->{species} = $sp_img;
  }
  $self->set_parameters({spritelib => $spritelib});

  # Add menus in the order you want them for this display
  $self->create_menus(qw(
    sequence
    marker
    transcript
    longreads
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

  # Add in additional tracks
  $self->load_tracks;

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

  $_->set_data('display', 'off') for grep $_->id =~ /^chr_band_/, $self->get_node('decorations')->nodes; # Turn off chromosome bands by default
}

sub glyphset_tracks {
  ## @override
  ## Adds trackhub tracks before returning the list of tracks
  my $self = shift;

  if (!$self->{'_glyphset_tracks'}) {
    $self->get_node('user_data')->after($_) for grep $_->get_data('trackhub_menu'), $self->tree->nodes;
    $self->SUPER::glyphset_tracks;
  }

  return $self->{'_glyphset_tracks'};
}

sub multi {
  my ($self, $methods, $chr, $pos, $total,$all_slices, @slices) = @_;
  my $prodname        = $self->hub->species_defs->get_config($self->{'species'}, 'SPECIES_PRODUCTION_NAME');
  my $multi_hash      = $self->species_defs->multi_hash;
  my $primary_species = $self->hub->species;
  my $p               = $pos == $total && $total > 2 ? 2 : 1;
  my ($i, %alignments, @strands);
  my $slice_summary = join(' ',map {
    join(':',$_->[0],$_->[1]->seq_region_name,$_->[1]->start,$_->[1]->end)
  } map { [$_->{'species'},$_->{'slice'}] } @$all_slices);

  foreach my $db (@{$self->species_defs->compara_like_databases || []}) {
    next unless exists $multi_hash->{$db}; 

    foreach (values %{$multi_hash->{$db}{'ALIGNMENTS'}}, @{$multi_hash->{$db}{'INTRA_SPECIES_ALIGNMENTS'}{'REGION_SUMMARY'}{$prodname}{$chr} || []}) {

      next unless $methods->{$_->{'type'}};
      next unless $_->{'class'} =~ /pairwise_alignment/;
      next unless $_->{'species'}{$prodname} || $_->{'species'}{"$prodname--$chr"};

      my %align = %$_; # Make a copy for modification

      $i = $p;
      foreach (@slices) {
        my ($check_species, $check_chr) = split('--', $_->{'species_check'});
        my $check_prodname  = $self->species_defs->get_config($check_species, 'SPECIES_PRODUCTION_NAME');
        my $check_key       = $check_chr ? $check_prodname.'--'.$check_chr : $check_prodname;

        if ($align{'species'}{$check_key}) {
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

  if (scalar keys %alignments) {

    %alignments = %{$self->select_alignment_based_on_hierarchy(\%alignments)};

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
        my ($other_species) = grep $_ ne $prodname, keys %{$align->{'species'}};

        my $glyphset = $align->{'type'} =~ /CACTUS/ ? 'cactus_hal' : '_alignment_pairwise';

        $decorations->before(
          $self->create_track("$align->{'id'}:$align->{'type'}:$_", $align->{'name'}, {
            glyphset                   => $glyphset,
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
            menu                       => 'no',
            slice_summary              => $slice_summary,
            flip_vertical              => 1,
          })
        );
      }
    }
  }

  $self->add_tracks('information',
    [ 'gene_legend', 'Gene Legend','gene_legend', {  display => 'normal', strand => 'r', accumulate => 'yes' }],
    [ 'variation_legend', 'Variant Legend','variation_legend', {  display => 'normal', strand => 'r', accumulate => 'yes' }],
    [ 'fg_regulatory_features_legend',   'Reg. Features Legend', 'fg_regulatory_features_legend',   { display => 'normal', strand => 'r', colourset => 'fg_regulatory_features'   }],
    [ 'fg_methylation_legend', 'Methylation Legend', 'fg_methylation_legend', { strand => 'r' } ],
    [ 'structural_variation_legend', 'Structural Variant Legend', 'structural_variation_legend', { strand => 'r' } ],
  );
  $self->modify_configs(
    [ 'gene_legend', 'variation_legend','fg_regulatory_features_legend', 'fg_methylation_legend', 'structural_variation_legend' ],
    { accumulate => 'yes' }
  );
}

sub select_alignment_based_on_hierarchy {
  my $self = shift;
  my $alignments = shift || {};
  my $hierarchy = $self->hub->species_defs->ENSEMBL_ALIGNMENTS_HIERARCHY;

  my $prioritised_alignments = {};
  my $hash_flag = {};
  my ($align, $order, $i, $j, $method, $re);
  foreach $order (keys %$alignments) {
    for ($i=0; $i<=$#$hierarchy; $i++) {
      $method = $hierarchy->[$i];
      $re = qr /$method/i;

      for ($j=0; $j<=$#{$alignments->{$order}}; $j++) {
        $align = $alignments->{$order}->[$j];
        if ($align->{type} =~ $re) {
          push @{$prioritised_alignments->{$order}}, $align;
          last;
        }

        if ($i == $#$hierarchy && $j == $#{$alignments->{$order}}) {
          push @{$prioritised_alignments->{$order}}, $align;
          last;
        }
      }

      if ($prioritised_alignments->{$order}) {
        last;
      }
    }
  }
  return $prioritised_alignments || $alignments;
}

sub connect_genes {
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
    $_->set_data('previous_species', $prev_species) if $prev_species;
    $_->set_data('next_species',     $next_species) if $next_species;
    $_->set_data('previous_target',  $prev_target)  if $prev_target;
    $_->set_data('next_target',      $next_target)  if $next_target;
    $_->set_data('connect', 1);
  }
}

sub highlight {
  my ($self, $gene) = @_;
  $_->set_data('g', $gene) for $self->get_node('transcript')->nodes;
}

1;

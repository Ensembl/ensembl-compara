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

package EnsEMBL::Web::ImageConfig::alignsliceviewbottom;

use strict;
use warnings;

use parent qw(EnsEMBL::Web::ImageConfig::MultiSpecies);

sub init_cacheable {
  ## @override
  my $self    = shift;
  my $species = $self->species;

  $self->SUPER::init_cacheable(@_);

  $self->set_parameters({
    sortable_tracks => 1, # allow the user to reorder tracks
  });

  my $sp_img = $self->species_defs->SPECIES_IMAGE_DIR;
  if(-e $sp_img) {
    $self->set_parameters({ spritelib => {
      %{$self->get_parameter('spritelib')||{}},
      species => $sp_img,
    }});
  }
  $self->create_menus(qw(
    sequence
    transcript
    repeat
    variation
    somatic
    conservation
    information
  ));

  $self->add_track('sequence', 'contig', 'Contigs', 'contig', { display => 'normal', strand => 'r', description => 'Track showing underlying assembly contigs' });

  $self->add_tracks('information',
    [ 'alignscalebar',     '',                  'alignscalebar',     { display => 'normal', strand => 'b', menu => 'no' }],
    [ 'ruler',             '',                  'ruler',             { display => 'normal', strand => 'f', menu => 'no' }],
    [ 'draggable',         '',                  'draggable',         { display => 'normal', strand => 'b', menu => 'no' }], # TODO: get this working
    [ 'variation_legend',  'Variant Legend',     'variation_legend', { display => 'normal', strand => 'r', accumulate => 'yes' }],
    [ 'alignslice_legend', 'AlignSlice Legend', 'alignslice_legend', { display => 'normal', strand => 'r', accumulate => 'yes' }],
    [ 'gene_legend', 'Gene Legend','gene_legend', {  display => 'normal', strand => 'r', accumulate => 'yes' }],
  );

  if ($species eq 'Multi') {
    $self->set_parameter('sortable_tracks', 0);
  } else {
    $self->load_tracks;
  }

  $self->modify_configs(
    [ 'transcript' ],
    { renderers => [
      off                   => 'Off',
      as_transcript_label   => 'Expanded with labels',
      as_transcript_nolabel => 'Expanded without labels',
      as_collapsed_label    => 'Collapsed with labels',
      as_collapsed_nolabel  => 'Collapsed without labels'
    ]}
  );

  $self->modify_configs(
    [ 'conservation' ],
    { menu => 'no' }
  );

  # Move last gene_legend to after alignslice_legend

  my $dest;
  foreach my $track (@{$self->get_tracks}) {
    if($track->id eq 'alignslice_legend') {
      $self->modify_configs(['gene_legend'],{track_after => $track });
    }
 }
  $self->modify_configs(
    [ 'gene_legend' ],
    { accumulate => 'yes' }
  );
  $self->modify_configs(
    [ 'variation_legend' ],
    { accumulate => 'yes' }
  );
}

sub species_list {
  my $self = shift;

  if (!$self->{'species_list'}) {
    my $species_defs = $self->species_defs;
    my $referer      = $self->hub->referer;
    my ($align)      = split '--', $referer->{'params'}{'align'}[0];
    my $alignment    = $species_defs->multi_hash->{'DATABASE_COMPARA'}{'ALIGNMENTS'}{$align}{'species'} || {};
    my $primary      = $referer->{'ENSEMBL_SPECIES'};
    my @species      = scalar keys %$alignment ? () : ([ $primary, $species_defs->SPECIES_DISPLAY_NAME($primary) ]);

    my @species_list = map { $_ = $species_defs->production_name_mapping($_) || $_ } keys %$alignment;

    foreach (sort { $a->[1] cmp $b->[1] } map [ $_, $species_defs->SPECIES_DISPLAY_NAME($_) ], @species_list) {
      if ($_->[0] eq $primary) {
        unshift @species, $_;
      } elsif ($_->[0] eq 'ancestral_sequences') {
        push @species, [ 'Multi', 'Ancestral sequences' ]; # Cheating: set species to Multi to stop errors due to invalid species.
      } else {
        push @species, $_;
      }
    }

    $self->{'species_list'} = \@species;
  }

  return $self->{'species_list'};
}

1;

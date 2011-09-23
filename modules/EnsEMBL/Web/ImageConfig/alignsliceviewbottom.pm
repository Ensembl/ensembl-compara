# $Id$

package EnsEMBL::Web::ImageConfig::alignsliceviewbottom;

use strict;

use base qw(EnsEMBL::Web::ImageConfig::MultiSpecies);

sub init {
  my $self    = shift;
  my $species = $self->species;
  
  $self->set_parameters({
    sortable_tracks => 1, # allow the user to reorder tracks
    global_options  => 1,
  });

  $self->create_menus(qw(
    options
    sequence
    transcript
    repeat
    variation
    somatic
    conservation
    information
  ));
  
  my $options = $self->get_node('options');
  
  $options->set('caption', 'Comparative features');
  
  $self->add_options( 
    [ 'opt_conservation_scores',  'Conservation scores',  {qw(off 0 tiling  tiling )}, [qw(off Off tiling  On)], 'off' ],
    [ 'opt_constrained_elements', 'Constrained elements', {qw(off 0 compact compact)}, [qw(off Off compact On)], 'off' ],
  );  
  
  if ($self->species_defs->valid_species($species) || $species eq 'common') {
    if ($species eq 'common') {
      $self->set_parameters({
        active_menu     => 'sequence',
        sortable_tracks => 0
      });
    } else {
      $self->load_tracks;
    }
    
    $self->add_track('sequence', 'contig', 'Contigs', 'stranded_contig', { display => 'normal', strand => 'r', description => 'Track showing underlying assembly contigs' });
    
    $self->add_tracks('information', 
      [ 'alignscalebar',     '',                  'alignscalebar',     { display => 'normal', strand => 'b', menu => 'no' }],
      [ 'ruler',             '',                  'ruler',             { display => 'normal', strand => 'f', menu => 'no' }],
      [ 'draggable',         '',                  'draggable',         { display => 'normal', strand => 'b', menu => 'no' }], # TODO: get this working
      [ 'alignslice_legend', 'AlignSlice Legend', 'alignslice_legend', { display => 'normal', strand => 'r' }]
    );
    
    $options->remove;
    
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
    
    $self->{'extra_menus'}->{'display_options'} = 0;
  } else {
    $self->set_parameters({
      active_menu     => 'options',
      sortable_tracks => 0
    });
    
    $self->{'extra_menus'} = { display_options => 1 };
  }
}

sub species_list {
  my $self = shift;
  
  if (!$self->{'species_list'}) {
    my $species_defs = $self->species_defs;
    my $referer      = $self->hub->referer;
    my ($align)      = split '--', $referer->{'params'}{'align'}[0];
    my $alignment    = $species_defs->multi_hash->{'DATABASE_COMPARA'}{'ALIGNMENTS'}{$align}{'species'} || {};
    my $primary      = $referer->{'ENSEMBL_SPECIES'};
    my @species      = scalar keys %$alignment ? () : ([ $primary, $species_defs->SPECIES_COMMON_NAME($primary) ]);
    
    foreach (sort { $a->[1] cmp $b->[1] } map [ $_, $species_defs->SPECIES_COMMON_NAME($_) ], keys %$alignment) {
      if ($_->[0] eq $primary) {
        unshift @species, $_;
      } elsif ($_->[0] eq 'ancestral_sequences') {
        push @species, [ 'common', 'Ancestral sequences' ]; # Cheating: set species to common to stop errors due to invalid species.
      } else {
        push @species, $_;
      }
    }
    
    $self->{'species_list'} = \@species;
  }
  
  return $self->{'species_list'};
}

1;

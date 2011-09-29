# $Id$

package EnsEMBL::Web::ImageConfig::MultiBottom;

use strict;

use base qw(EnsEMBL::Web::ImageConfig::MultiSpecies);

sub init {
  my $self = shift;
  
  $self->set_parameters({
    sortable_tracks => 1,  # allow the user to reorder tracks
    opt_lines       => 1,  # register lines
    spritelib       => { default => $self->species_defs->ENSEMBL_SERVERROOT . '/htdocs/img/sprites' }
  });

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
  
  # Add in additional tracks
  $self->load_tracks;
  $self->load_configured_das;
  
  $self->add_tracks('sequence', 
    [ 'contig', 'Contigs', 'stranded_contig', { display => 'normal', strand => 'r', description => 'Track showing underlying assembly contigs' }]
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
  my ($self, $methods, $pos, $total, @slices) = @_;
 
  my $sp         = $self->{'species'};
  my $multi_hash = $self->species_defs->multi_hash;
  my $p          = $pos == $total && $total > 2 ? 2 : 1;
  my $i;
  my %alignments;
  my @strands;
  
  foreach my $db (@{$self->species_defs->compara_like_databases||[]}) {
    next unless exists $multi_hash->{$db};
    
    foreach (values %{$multi_hash->{$db}->{'ALIGNMENTS'}}) {
      next unless $methods->{$_->{'type'}};
      next unless $_->{'class'} =~ /pairwise_alignment/;
      next unless $_->{'species'}->{$sp};
      
      my %align = %$_;
      
      next unless grep $align{'species'}->{$_->{'species'}}, @slices;
      
      $i = $p;
      
      foreach (@slices) {
        if ($align{'species'}->{$_->{'species'}}) {
          $align{'order'}     = $i;
          $align{'other_ori'} = $_->{'ori'};
          $align{'gene'}      = $_->{'g'};
          last;
        }
        
        $i++;
      }
      
      $align{'db'} = lc substr $db, 9;
      
      push @{$alignments{$align{'order'}}}, \%align;
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
          species                    => $other_species,
          strand                     => $strand,
          display                    => $methods->{$align->{'type'}},
          db                         => $align->{'db'},
          type                       => $align->{'type'},
          ori                        => $align->{'other_ori'},
          method_link_species_set_id => $align->{'id'},
          join                       => 1,
        })
      );
    }
  }
}

sub join_genes {
  my $self = shift;
  my ($pos, $total, @species) = @_;
  
  my ($prev_species, $next_species) = @species;
     ($prev_species, $next_species) = ('', $prev_species) if ($pos == 1 && $total == 2) || ($pos == 2 && $total > 2);
  $next_species = $prev_species if $pos > 2 && $pos < $total && $total > 3;
  
  foreach ($self->get_node('transcript')->nodes) {
    $_->set('previous_species', $prev_species) if $prev_species;
    $_->set('next_species', $next_species) if $next_species;
    $_->set('join', 1);
  }
}

sub highlight {
  my ($self, $gene) = @_;
  $_->set('g', $gene) for $self->get_node('transcript')->nodes; 
}

1;

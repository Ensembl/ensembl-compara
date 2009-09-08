package EnsEMBL::Web::ImageConfig::MultiBottom;

use strict;
use warnings;
no warnings 'uninitialized';

use base qw(EnsEMBL::Web::ImageConfig);

sub mergeable_config {
  return 1;
}

sub init {
  my $self = shift;

  $self->set_parameters({
    title        => 'Main panel',
    show_buttons => 'no',  # show +/- buttons
    button_width => 8,     # width of red "+/-" buttons
    show_labels  => 'yes', # show track names on left-hand side
    label_width  => 113,   # width of labels on left-hand side
    margin       => 5,     # margin
    spacing      => 2,     # spacing
    opt_lines    => 1,     # register lines
    spritelib    => { default => $self->{'species_defs'}->ENSEMBL_SERVERROOT . '/htdocs/img/sprites' }
  });

  # Add menus in the order you want them for this display
  $self->create_menus(
    sequence         => 'Sequence',
    marker           => 'Markers',
    compara          => 'Compara',
    transcript       => 'Genes',
    prediction       => 'Prediction Transcripts',
    protein_align    => 'Protein alignments',
    dna_align_cdna   => 'cDNA/mRNA alignments', # Separate menus for different cDNAs/ESTs...
    dna_align_est    => 'EST alignments',
    dna_align_rna    => 'RNA alignments',
    dna_align_other  => 'Other DNA alignments', 
    oligo            => 'Oligo features',
    simple           => 'Simple features',
    misc_feature     => 'Misc. regions',
    repeat           => 'Repeats',
    variation        => 'Variation features',
    functional       => 'Functional genomics',
    decorations      => 'Additional decorations'
  );

  # Add in additional tracks
  $self->load_tracks;
  $self->load_configured_das;
  
  $self->add_tracks('sequence', 
    [ 'contig', 'Contigs', 'stranded_contig', { display => 'normal', strand => 'r', description => 'Track showing underlying assembly contigs' }],
  );
  
  $self->add_tracks('decorations',
    [ 'ruler',     '', 'ruler',      { display => 'normal', strand => 'b', name => 'Ruler', description => 'Shows the length of the region being displayed' }],
    [ 'scalebar',  '', 'scalebar',   { display => 'normal', strand => 'b', menu => 'no' }],
    [ 'draggable', '', 'draggable',  { display => 'normal', strand => 'b', menu => 'no' }],
    [ 'nav',       '', 'navigation', { display => 'normal', strand => 'r', menu => 'no' }],
  );
  
  $_->set('display', 'off') for grep $_->key =~ /^chr_band_/, $self->get_node('decorations')->nodes; # Turn off chromosome bands by default
}

sub multi {
  my ($self, $methods, $pos, $total, @slices) = @_;
  
  my $sp = $self->{'species'};
  my $multi_hash = $self->species_defs->multi_hash;
  my %alignments;
  my @strands;
  
  foreach my $db (@{$self->species_defs->compara_like_databases||[]}) {
    next unless exists $multi_hash->{$db};
    
    foreach my $align (values %{$multi_hash->{$db}->{'ALIGNMENTS'}}) {
      next if $methods->{$align->{'type'}} eq 'no';
      next unless $align->{'class'} =~ /pairwise_alignment/;
      next unless $align->{'species'}->{$sp};
      next unless grep $align->{'species'}->{$_->{'species'}}, @slices;
      
      my $i = $pos == $total && $total > 2 ? 2 : 1;
      
      foreach (@slices) {
        if ($align->{'species'}->{$_->{'species'}}) {
          $align->{'order'} = $i;
          $align->{'other_ori'} = $_->{'ori'};
          $align->{'gene'} = $_->{'g'};
          last;
        }
        
        $i++;
      };
      
      $align->{'db'} = lc(substr $db, 9);
      $alignments{$align->{'order'}} = $align;
    }
  }
  
  if ($pos == 1) {
    @strands = $total == 2 ? qw(r) : scalar keys %alignments == 2 ? qw(f r) : [keys %alignments]->[0] == 1 ? qw(f) : qw(r); # Primary species
  } elsif ($pos == $total) {
    @strands = qw(f); # Last species - show alignments on forward strand.
  } elsif ($pos == 2) {
    @strands = qw(r); # First species where $total > 2
  } else {
    @strands = qw(r f); # Secondary species in the middle of the image
  }
  
  # Double up for non primary species in the middle of the image
  $alignments{2} = $alignments{1} if $pos != 1 && scalar @strands == 2 && scalar keys %alignments == 1;
  
  foreach (sort keys %alignments) {
    my $align = $alignments{$_};
    my ($other_species) = grep !/^$sp|merged/, keys %{$align->{'species'}};
    my $other_label = $self->species_defs->species_label($other_species, 'no_formatting');
    (my $other_species_hr = $other_species) =~ s/_/ /g;
    
    $self->get_node('decorations')->add_before(
      $self->create_track("$align->{'id'}:$align->{'type'}:$_", $align->{'name'}, {
        db             => $align->{'db'},
        glyphset       => '_alignment_pairwise',
        name           => $other_label,
        caption        => $align->{'name'},
        type           => $align->{'type'},
        species_set_id => $align->{'species_set_id'},
        species        => $other_species,
        species_hr     => $other_species_hr,
        ori            => $align->{'other_ori'},
        _assembly      => $self->species_defs->get_config($other_species, 'ENSEMBL_GOLDEN_PATH'),
        colourset      => 'pairwise',
        strand         => shift @strands,
        join           => 1
      })
    );
  }
  
  foreach ($self->get_node('transcript')->nodes) {
    my ($prev_species) = grep !/^$sp|merged/, keys %{$alignments{1}->{'species'}} if exists $alignments{1};
    my ($next_species) = grep !/^$sp|merged/, keys %{$alignments{2}->{'species'}} if exists $alignments{2};
    
    ($prev_species, $next_species) = ('', $prev_species) if ($pos == 1 && $total == 2) || ($pos == 2 && $total > 2);
    ($prev_species, $next_species) = ($next_species, '') if $pos == $total && $total > 2;
    
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

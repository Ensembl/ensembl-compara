package Bio::EnsEMBL::GlyphSet::_synteny;

use strict;
use base qw(Bio::EnsEMBL::GlyphSet_simple);
use Bio::EnsEMBL::Feature;

## All Glyphset simple codes should be written with functions in
## the following order:
##  * sub features
##  * sub colour
##  * sub feature_label
##  * sub title
##  * sub href
##  * sub tag

## How do we retrieve the features from the database. in this case
## we do a get_all_compara_Syntenies
## NOTE THAT THIS IS NOT MULTI COMPARA SAFE... NEEDS TO REALLY
## KNOW ABOUT THE COMPARA DATABASE... WHICH THE WEBCODE WILL PASS IN!!

sub features {
  my ($self) = @_;
  my $species    = $self->my_config('species');
  my $species_hr = $self->human_readable( $species );

  warn "... $species $species_hr ....";
  my $T       = $self->{'container'}->get_all_compara_Syntenies( $species_hr, "SYNTENY" );
  my $offset  = $self->{'container'}->start - 1;
  my @RET     = ();
  
  foreach my $argh (@$T) {
    warn "Synteny.... $argh ....";
    my ($main_dfr, $other_dfr);
    foreach my $dfr (@{$argh->children}) {
      if($dfr->dnafrag->genome_db->name eq $species_hr) {
        $other_dfr = $dfr;
      } else {
        $main_dfr = $dfr;
      }
    }
## Glyphset simple requires real Bio::EnsEMBL::Feature objects so 
## create one and set the start/end etc..
    my $f = Bio::EnsEMBL::Feature->new(
      -start   => $main_dfr->dnafrag_start - $offset,
      -end     => $main_dfr->dnafrag_end   - $offset,
      -strand  => $main_dfr->dnafrag_strand,
      -seqname => $main_dfr->dnafrag->name
    );
    $f->{'hit_chr_name'}  = $other_dfr->dnafrag->name;
    $f->{'hit_chr_start'} = $other_dfr->dnafrag_start;
    $f->{'hit_chr_end'}   = $other_dfr->dnafrag_end;
    $f->{'chr_name'}      = $main_dfr->dnafrag->name;
    $f->{'chr_start'}     = $main_dfr->dnafrag_start;
    $f->{'chr_end'}       = $main_dfr->dnafrag_end;
    $f->{'rel_ori'}       = $main_dfr->dnafrag_strand *
                            $other_dfr->dnafrag_strand;
    push @RET, $f;
    $argh->release_tree;
  }
  return \@RET;
}

## Colour is "nasty" we have a pool of colours we allocate in a loop!
## Colour is cached on the main config by chromosome name.

sub get_colours {
  my( $self, $f ) = @_;
  unless(exists $self->{'config'}{'pool'}) {
    $self->{'config'}{'pool'} = [];
    my $colours = $self->my_config('colours');
    if( $colours ) {
      foreach (sort { $a <=> $b } keys %$colours ) {
        $self->{'config'}{'pool'}[$_] = $self->my_colour( $_ );
      }
    } else {
      $self->{'config'}{'pool'} = [qw(red blue green purple yellow orange brown black)]
    }
    $self->{'config'}{'ptr'}  = 0;
  }
  $self->{'config'}{'_synteny_colours'}||={};
  my $return = $self->{'config'}{'_synteny_colours'}{ $f->{'hit_chr_name'} };
  unless( $return ) {
    $return = $self->{'config'}{'_synteny_colours'}{$f->{'hit_chr_name'}}
            = $self->{'config'}{'pool'}[ ($self->{'config'}{'ptr'}++)%@{$self->{'config'}{'pool'}} ];
  }
  return {
    'feature' => $return,
    'label'   => $return,
    'part'    => ''
  };
}

## Return the image label and the position of the label
## (overlaid means that it is placed in the centre of the
## feature.

sub feature_label {
  my ($self, $f ) = @_;
  return(
    sprintf( '%s%s%s',
      $f->{'rel_ori'}<0 ? '<' : '',
      $f->{'hit_chr_name'},
      $f->{'rel_ori'}<0 ? ''  : '>'
    ),
    'under'
  );
}

## To be displayed when mousing over region...
## and to use as the initial pop-up menu.

sub title {
  my( $self, $f ) = @_;
  return sprintf "%s: %s:%s-%s; %s: %s:%s-%s; Orientation: %s",
    $self->human_readable( $self->web_species ),
    $self->{'chr_name'},
    $self->{'chr_start'},
    $self->{'chr_end'},
    $self->human_readable( $self->my_config('species') ),
    $f->{'hit_chr_name'},
    $f->{'hit_chr_start'},
    $f->{'hit_chr_end'},
    $f->{'rel_ori'}<0 ? 'reverse' : 'same';
}

## To be used for the default link...
## In this case jump to cytoview on the other species...
sub href { 
  my ($self, $f ) = @_;
  return $self->_url({
    'action'  => 'Overview',
    'species' => $self->my_config('species'),
    't'       => undef,
    'r'       => "$f->{'hit_chr_name'}:$f->{'hit_chr_start'}-$f->{'hit_chr_end'}"
  });
}

## There are no tags for this feature...
sub tag {
  return;
}

1;

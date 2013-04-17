package Bio::EnsEMBL::GlyphSet::_synteny;

use strict;

use Bio::EnsEMBL::Feature;

use base qw(Bio::EnsEMBL::GlyphSet_simple);

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
  my $self      = shift;
  my $species   = $self->species_defs->get_config($self->my_config('species'), 'SPECIES_PRODUCTION_NAME');
  my $syntenies = $self->{'container'}->get_all_compara_Syntenies($species, 'SYNTENY', $self->dbadaptor('multi', $self->my_config('db')));
  my $offset    = $self->{'container'}->start - 1;
  my @features;
  
  foreach (@$syntenies) {
    my ($main_dfr, $other_dfr);
    
    foreach my $dfr (@{$_->get_all_DnaFragRegions}) {
      if ($dfr->dnafrag->genome_db->name eq $species) {
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
      -seqname => $main_dfr->dnafrag->name,
      -slice   => $self->{'container'}
    );
    
    $f->{'hit_chr_name'}  = $other_dfr->dnafrag->name;
    $f->{'hit_chr_start'} = $other_dfr->dnafrag_start;
    $f->{'hit_chr_end'}   = $other_dfr->dnafrag_end;
    $f->{'chr_name'}      = $main_dfr->dnafrag->name;
    $f->{'chr_start'}     = $main_dfr->dnafrag_start;
    $f->{'chr_end'}       = $main_dfr->dnafrag_end;
    $f->{'rel_ori'}       = $main_dfr->dnafrag_strand * $other_dfr->dnafrag_strand;
    
    push @features, $f;
  }
  
  return \@features;
}

## Colour is "nasty" we have a pool of colours we allocate in a loop!
## Colour is cached on the main config by chromosome name.
sub get_colours {
  my ($self, $f) = @_;
  my $config = $self->{'config'};
  my $name   = $config->{'_synteny_colours'}{$f->{'hit_chr_name'}};
  
  if (!exists $config->{'pool'}) {
    my $colours = $self->my_config('colours');
    
    $config->{'pool'} = [ $colours ? map $self->my_colour($_), sort { $a <=> $b } keys %$colours : qw(red blue green purple yellow orange brown black) ];
    $config->{'ptr'}  = 0;
  }
  
  if (!$name) {
    $name = $config->{'_synteny_colours'}{$f->{'hit_chr_name'}}
          = $config->{'pool'}[($self->{'config'}{'ptr'}++) % scalar @{$config->{'pool'}}];
  }
  
  return {
    feature => $name,
    label   => $name,
    part    => ''
  };
}

sub feature_label {
  my ($self, $f) = @_;
  return sprintf(
    '%s%s%s',
    $f->{'rel_ori'} < 0 ? '< ' : '',
    $f->{'hit_chr_name'},
    $f->{'rel_ori'} < 0 ? ''  : ' >'
  );
}

## To be displayed when mousing over region...
## and to use as the initial pop-up menu.
sub title {
  my ($self, $f) = @_;
  return sprintf '%s: %s:%s-%s; %s: %s:%s-%s; Orientation: %s',
    $self->species_defs->get_config($self->species, 'SPECIES_SCIENTIFIC_NAME'),
    $self->{'chr_name'},
    $self->{'chr_start'},
    $self->{'chr_end'},
    $self->species_defs->get_config($self->my_config('species'), 'SPECIES_SCIENTIFIC_NAME'),
    $f->{'hit_chr_name'},
    $f->{'hit_chr_start'},
    $f->{'hit_chr_end'},
    $f->{'rel_ori'} < 0 ? 'reverse' : 'same';
}

## To be used for the default link...
## In this case jump to cytoview on the other species...
sub href { 
  my ($self, $f) = @_;
  my $ori = $f->{'rel_ori'} < 0 ? 'reverse' : 'same';
  
  return $self->_url({
    action  => 'Synteny',
    species => $self->my_config('species'),
    r       => "$f->{'hit_chr_name'}:$f->{'hit_chr_start'}-$f->{'hit_chr_end'}",
    ori     => $ori,
    __clear => 1,
  });
}

1;

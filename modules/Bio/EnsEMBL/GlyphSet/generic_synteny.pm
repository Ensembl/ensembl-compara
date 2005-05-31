package Bio::EnsEMBL::GlyphSet::generic_synteny;
use strict;
use vars qw(@ISA);
use Bio::EnsEMBL::GlyphSet_simple;
@ISA = qw(Bio::EnsEMBL::GlyphSet_simple);

sub my_label { return $_[0]->my_config('label'); }

sub help_link { return 'compara_synteny'; }

sub features {
  my ($self) = @_;
  my $species = $self->my_config('species');
  (my $species_2 = $species) =~ s/_/ /;
  return $self->{'container'}->get_all_compara_Syntenies( $species_2 );
}

sub colour {
  my ($self, $f) = @_;
  unless(exists $self->{'config'}{'pool'}) {
    $self->{'config'}{'pool'} = $self->{'config'}->colourmap->{'colour_sets'}{'synteny'};
    $self->{'config'}{'ptr'}  = 0;
  }
  my $return = $self->{'config'}{ $f->{'hit_chr_name'} };
  unless( $return ) {
    $return = $self->{'config'}{$f->{'hit_chr_name'}} = $self->{'config'}{'pool'}[ ($self->{'config'}{'ptr'}++)%@{$self->{'config'}{'pool'}} ];
  } 
  return $return, $return;
}

## Return the image label and the position of the label
## (overlaid means that it is placed in the centre of the
## feature.

sub image_label {
  my ($self, $f ) = @_;
  return ( $f->{'rel_ori'}<0 ? '<' : '' ).
         $f->{'hit_chr_name'}.
         ( $f->{'rel_ori'}<0 ? '' : '>' ) , 'under';
}

sub href { 
  my ($self, $f ) = @_;
  my $ospecies = $self->my_config('species');
  return "/$ospecies/cytoview?chr=$f->{'hit_chr_name'};".
      "vc_start=$f->{'hit_chr_start'};vc_end=$f->{'hit_chr_end'}";
}

## Create the zmenu...
## Include each accession id separately

sub zmenu {
  my ($self, $f ) = @_;
  my $ospecies = $self->my_config('species');
  my $zmenu = { 
    'caption' => "$f->{'hit_chr_name'} $f->{'hit_chr_start'}-$f->{'hit_chr_end'}",
    "01:Jump to $ospecies" => $self->href($f),
    '02:bps: '.$f->{'chr_start'}."-".$f->{'chr_end'} => '',
    '03:Orientation:'.($f->{'rel_ori'}<0 ? ' reverse' : ' same')  => '',
  };
  return $zmenu;
}

1;

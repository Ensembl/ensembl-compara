package Bio::EnsEMBL::GlyphSet::rat_synteny;
use strict;
use vars qw(@ISA);
use Bio::EnsEMBL::GlyphSet_simple;
@ISA = qw(Bio::EnsEMBL::GlyphSet_simple);

sub my_label { return "Rat synteny"; }

sub features {
    my ($self) = @_;
    return $self->{'container'}->get_all_compara_Syntenies( 'Rattus norvegicus' );
}

sub colour {
  my ($self, $f) = @_;
  unless(exists $self->{'config'}{'pool'}) {
    $self->{'config'}{'pool'} = [qw(red3 green4 cyan4 blue3 chocolate3 brown chartreuse4 grey25 deeppink4 slateblue3 olivedrab4 gold4 blueviolet seagreen4 violetred3)  ];
    $self->{'config'}{'ptr'}     = 0;
  }
  my $return = $self->{'config'}{ $f->{'hit_chr_name'} };
  warn @{$self->{'config'}{'pool'}};
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

## Link back to this page centred on the map fragment

sub href {
    my ($self, $f ) = @_;
    my $st = int( ($f->{'hit_chr_start'} + $f->{'hit_chr_end'}-1e6) / 2);
    my $en = $st + 1e6;
    return "/Rattus_norvegicus/$ENV{'ENSEMBL_SCRIPT'}?l=".$f->{'hit_chr_name'}.":$st-$en";
}

## Create the zmenu...
## Include each accession id separately

sub zmenu {
    my ($self, $f ) = @_;
    my $zmenu = { 
        'caption' => "$f->{'hit_chr_name'} $f->{'hit_chr_start'}-$f->{'hit_chr_end'}",
        '01:bps: '.$f->{'chr_start'}."-".$f->{'chr_end'} => '',
        '02:Orientation:'.($f->{'rel_ori'}<0 ? ' reverse' : ' same')  => '',
        '03:Jump to rat' => $self->href( $f )
    };
    return $zmenu;
}

1;

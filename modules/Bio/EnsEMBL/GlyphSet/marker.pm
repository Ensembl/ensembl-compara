package Bio::EnsEMBL::GlyphSet::marker;
use strict;
use vars qw(@ISA);
use Bio::EnsEMBL::GlyphSet_simple;
@ISA = qw(Bio::EnsEMBL::GlyphSet_simple);

my $PRIORITY   = 50;
my $MAP_WEIGHT = 80;

sub my_label { return "Markers"; }

sub features {
    my ($self) = @_;

    return $self->{'container'}->get_all_MarkerFeatures(undef, 
							$PRIORITY,
							$MAP_WEIGHT);
}

sub href {
    my ($self, $f ) = @_;
    return "/$ENV{'ENSEMBL_SPECIES'}/markerview?marker=".
      $f->marker->display_MarkerSynonym->name;
}
sub zmenu {
    my ($self, $f ) = @_;

    my $ms = $f->marker->display_MarkerSynonym;
    my $name = $ms->name;
    my $src = $ms->source;
    if($src && $src eq 'unists') {
      $name = "uniSTS:$name";
    }

    return { 
        'caption' => $name,
	 'Marker info' => $self->href($f)
    };
}

1;

package Bio::EnsEMBL::GlyphSet::marker;
use strict;
use vars qw(@ISA);
use Bio::EnsEMBL::GlyphSet_simple;
@ISA = qw(Bio::EnsEMBL::GlyphSet_simple);

sub squish {1;}

use constant PRIORITY   => 50;
use constant MAP_WEIGHT => 2;

sub my_label { return "Markers"; }

sub features {
    my ($self) = @_;

    return $self->{'container'}->get_all_MarkerFeatures(undef, 
							PRIORITY,
							MAP_WEIGHT);
}

sub href {
    my ($self, $f ) = @_;
    return "/@{[$self->{container}{_config_file_name_}]}/markerview?marker=".
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


sub colour {
    my ($self, $f) = @_;

    my $type = $f->marker->type;

    $type = '' unless(defined($type));

    return( $self->{'colours'}{"$type"}, $self->{'colours'}{"$type"}, '' );
}

1;

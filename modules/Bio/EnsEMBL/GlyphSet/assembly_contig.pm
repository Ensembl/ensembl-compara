package Bio::EnsEMBL::GlyphSet::assembly_contig;
use strict;
use vars qw(@ISA);
use Bio::EnsEMBL::GlyphSet_simple;
@ISA = qw(Bio::EnsEMBL::GlyphSet_simple);

sub my_label { return "Assembly Contig"; }

sub features {
    my ($self) = @_;
#    my $container_length = $self->{'container'}->length();
    return $self->{'container'}->get_all_MapFrags( 'assembly' );
}

sub href {
    my ($self, $f ) = @_;
    return "/$ENV{'ENSEMBL_SPECIES'}/$ENV{'ENSEMBL_SCRIPT'}?mapfrag=".$f->name
}

sub colour {
    my ($self, $f ) = @_;
    $self->{'_colour_flag'} = $self->{'_colour_flag'}==1 ? 2 : 1;
    return 
        $self->{'colours'}{"col$self->{'_colour_flag'}"},
        $self->{'colours'}{"lab$self->{'_colour_flag'}"};
}

sub image_label {
    my ($self, $f, $w ) = @_;
    ## Add orientation arrow to the assembly contig...
    my $label = $f->orientation == 1 ? $f->name."->" : "<-".$f->name;
    ## If the string is too long to fit - try just the arrow!
    if($w * 1.1 * length($label) > $f->length) {
        $label = $f->orientation == 1 ? "->" : "<-";
    }
    return ( $label, 'overlaid' );
}

sub zmenu {
    my ($self, $f ) = @_;
    my $zmenu = { 
        'caption'                               => $f->name,
        '01:bp: '.$f->seq_start."-".$f->seq_end => '',
        '02:length: '.$f->length.' bps'         => '',
        '03:Centre on contig'                   => $self->href($f),
    };
    return $zmenu;
}

1;

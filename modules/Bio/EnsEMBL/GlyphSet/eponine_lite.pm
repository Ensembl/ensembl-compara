package Bio::EnsEMBL::GlyphSet::eponine_lite;
use strict;
use vars qw(@ISA);
use Bio::EnsEMBL::GlyphSet_simple_hash;
@ISA = qw(Bio::EnsEMBL::GlyphSet_simple_hash);

sub my_label { return "Eponine"; }

sub my_description { return "Eponine transcription<br />&nbsp;start sites"; }

sub my_helplink { return "markers"; }

sub features {
    my ($self) = @_;
    return @{$self->{'container'}->get_all_virtualfeatures_lite(
        'eponine', .8, $self->glob_bp()
    )};
}

sub href {
    my ($self, $f ) = @_;
    return undef;
}

sub zmenu {
    my ($self, $f ) = @_;
    return {
        'caption'                                     => 'eponine',
        "01:Score: $f->{'score'}"                     => '',
        "02:bp: $f->{'chr_start'}-$f->{'chr_end'}" => ''
    };
}
1;

package Bio::EnsEMBL::GlyphSet::trna_lite;
use strict;
use vars qw(@ISA);
use Bio::EnsEMBL::GlyphSet_simple_hash;
@ISA = qw(Bio::EnsEMBL::GlyphSet_simple_hash);

sub my_label { return "tRNAs"; }

sub features {
    my ($self) = @_;
    return @{$self->{'container'}->get_all_virtualfeatures_lite(
        'trna', 25, $self->glob_bp()
    )};
}

sub href {
    my ($self, $f ) = @_;
    return undef;
}

sub zmenu {
    my ($self, $f ) = @_;
    return {
        'caption'                                     => 'tRNA',
        "01:Score: $f->{'score'}"                     => '',
        "02:bp: $f->{'chr_start'}-$f->{'chr_end'}" => ''
    };
}
1;

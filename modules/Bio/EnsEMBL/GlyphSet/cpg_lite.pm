package Bio::EnsEMBL::GlyphSet::cpg_lite;
use strict;
use vars qw(@ISA);
use Bio::EnsEMBL::GlyphSet_simple_hash;
@ISA = qw(Bio::EnsEMBL::GlyphSet_simple_hash);

sub my_label { return "CpG islands"; }

sub my_helplink { return "markers"; }

sub features {
    my ($self) = @_;
    return @{$self->{'container'}->get_all_virtualfeatures_lite(
        'cpg', 25, $self->glob_bp()
    )};
}

sub zmenu {
    my ($self, $f ) = @_;
    return {
        'caption' => 'CPG data island',
        "01:Score: $f->{'score'}" => '',
        "02:bp: $f->{'chr_start'}-$f->{'chr_end'}" => ''
    };
}
1;

package Bio::EnsEMBL::GlyphSet::snp_triangle_lite;
use strict;
use vars qw(@ISA);
use Bio::EnsEMBL::GlyphSet::snp_lite;
@ISA = qw(Bio::EnsEMBL::GlyphSet::snp_lite);

sub tag {
    my ($self, $f) = @_; 
    return ( {
        'style'  => 'triangle',
        'colour' => $self->colour($f)
    } );
}
1;

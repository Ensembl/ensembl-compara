package Bio::EnsEMBL::GlyphSet::mouse_match;
use strict;
use vars qw(@ISA);
# use Bio::EnsEMBL::GlyphSet_simple;
# @ISA = qw(Bio::EnsEMBL::GlyphSet_simple);
use Bio::EnsEMBL::GlyphSet_feature2;
@ISA = qw(Bio::EnsEMBL::GlyphSet_feature2);


sub my_label { return "Mouse matches"; }

sub features {
    my ($self) = @_;
    
    return $self->{'container'}->get_all_compara_DnaAlignFeatures('Mus_musculus' );
}

sub href {
    my ($self, $id, $chr_pos ) = @_;
    return "/Mus_musculus/$ENV{'ENSEMBL_SCRIPT'}?$chr_pos";
}

sub zmenu {
    my ($self, $id, $chr_pos ) = @_;
    return { 
		'caption'    => $id, # $f->id,
		'Jump to Mus musculus' => $self->href( $id, $chr_pos )
    };
}


sub unbumped_zmenu {
    my ($self, $ref, $target ) = @_;
    return { 
    	'caption'    => 'Dot-plot', 
    	'Jump to Mus musculus' => $self->unbumped_href( $ref, $target )
    };
}

sub unbumped_href {
    my ($self, $ref, $target ) = @_;
    return "/$ENV{'ENSEMBL_SPECIES'}/dotterview?ref=".join(':',$ENV{'ENSEMBL_SPECIES'},@$ref).
                        "&hom=".join(':','Mus_musculus', @$target ) ;
}


1;


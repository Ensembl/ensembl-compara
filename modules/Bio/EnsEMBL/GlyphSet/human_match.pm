package Bio::EnsEMBL::GlyphSet::human_match;
use strict;
use vars qw(@ISA);
# use Bio::EnsEMBL::GlyphSet_simple;
# @ISA = qw(Bio::EnsEMBL::GlyphSet_simple);
use Bio::EnsEMBL::GlyphSet_feature2;
@ISA = qw(Bio::EnsEMBL::GlyphSet_feature2);


sub my_label { return "Human matches"; }

sub features {
    my ($self) = @_;
    
    return  $self->{'container'}->get_all_compara_DnaAlignFeatures( 'Homo_sapiens' );
}

sub href {
    my ($self, $id, $chr_pos ) = @_;
    return "/Homo_sapiens/$ENV{'ENSEMBL_SCRIPT'}?$chr_pos";
}

sub zmenu {
    my ($self, $id, $chr_pos ) = @_;
    return { 
	'caption'    => $id, 
	'Jump to Homo spaiens' => $self->href( $id, $chr_pos )
    };
}


sub unbumped_zmenu {
    my ($self, $ref, $target ) = @_;
    return { 
    	'caption'    => 'Dot-plot', 
    	'Dotter' => $self->unbumped_href( $ref, $target ),
    	'THJ'    => "/$ENV{'ENSEMBL_SPECIES'}/thjview?width=50000&ref=".join(':',@$ref).
                        "&target=".join(':','Homo_sapiens', @$target ),
    };
}

sub unbumped_href {
    my ($self, $ref, $target ) = @_;
    return "/$ENV{'ENSEMBL_SPECIES'}/dotterview?ref=".join(':',$ENV{'ENSEMBL_SPECIES'},@$ref).
                        "&hom=".join(':','Homo_sapiens', @$target ) ;
}

1;

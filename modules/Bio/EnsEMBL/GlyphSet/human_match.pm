package Bio::EnsEMBL::GlyphSet::human_match;
use strict;
use vars qw(@ISA);
# use Bio::EnsEMBL::GlyphSet_simple;
# @ISA = qw(Bio::EnsEMBL::GlyphSet_simple);
use Bio::EnsEMBL::GlyphSet_feature2;
@ISA = qw(Bio::EnsEMBL::GlyphSet_feature2);


sub my_label { return "Muman matches"; }

sub features {
    my ($self) = @_;
    
    return  $self->{'container'}->get_all_DnaDnaAlignFeature( $self->{'config'}->{'_databases'}->{'compara'}, $ENV{'ENSEMBL_SPECIES'}, 'Homo_sapiens' );
}

sub href {
    my ($self, $id, $chr_pos ) = @_;
    return "/Homo_sapiens/$ENV{'ENSEMBL_SCRIPT'}?$chr_pos";
}

sub zmenu {
    my ($self, $id, $chr_pos ) = @_;
    return { 
		'caption'    => $id, # $f->id,
		'Jump to Homo spaiens' => $self->href( $id, $chr_pos )
    };
}
1;

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
    
    return grep { 
        ( $_->isa("Bio::EnsEMBL::Ext::FeaturePair") || $_->isa("Bio::EnsEMBL::FeaturePair") ) 
	        && $_->source_tag() eq "trace"
    } $self->{'container'}->get_all_ExternalFeatures( $self->glob_bp() );
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
1;

package Bio::EnsEMBL::GlyphSet::trace;
use strict;
use vars qw(@ISA);
use Bio::EnsEMBL::GlyphSet_simple;
@ISA = qw(Bio::EnsEMBL::GlyphSet_simple);


sub my_label { return "Mouse trace"; }

sub features {
    my ($self) = @_;
    return grep { 
        ( $_->isa("Bio::EnsEMBL::Ext::FeaturePair") || $_->isa("Bio::EnsEMBL::FeaturePair") ) 
	        && $_->source_tag() eq "trace"
    } $self->{'container'}->get_all_ExternalFeatures( $self->glob_bp() );
}

sub href {
    my ($self, $f ) = @_;
    return $self->{'config'}->{'ext_url'}->get_url( 'TRACE', $f->id );
}

sub zmenu {
    my ($self, $f ) = @_;
    return { 
		'caption'    => $f->id,
		'View trace' => $self->href( $f )
    };
}
1;

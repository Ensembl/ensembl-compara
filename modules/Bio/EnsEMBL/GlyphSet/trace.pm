package Bio::EnsEMBL::GlyphSet::trace;
use strict;
use vars qw(@ISA);
use Bio::EnsEMBL::GlyphSet_simple;
@ISA = qw(Bio::EnsEMBL::GlyphSet_simple);
use ExtURL;

sub my_label { return "Mouse trace"; }

sub features {
    my ($self) = @_;
    return grep { 
            ( $_->isa("Bio::EnsEMBL::Ext::FeaturePair") || $_->isa("Bio::EnsEMBL::FeaturePair") ) 
	    	    && $_->source_tag() eq "trace"
        } $self->{'container'}->get_all_ExternalFeatures( $self->glob_bp() );
}

sub zmenu {
    my ($self, $id ) = @_;
    my $ext_url = ExtURL->new;
    return { 
		'caption'    => "$id",
		'View trace' => $ext_url->get_url( 'TRACE', $id )
    };
}
1;

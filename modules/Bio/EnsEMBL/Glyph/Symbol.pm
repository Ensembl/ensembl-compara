=head1 NAME

Bio::EnsEMBL::Glyph::Symbol

=head1 DESCRIPTION

Parent class for Symbols.

Symbols are collections of Glyphs used for drawing slightly more complex
shapes. The initial reason for implementing these is to model DAS glyphs.

=head1 AUTHOR

Jim Stalker (jws@sanger.ac.uk)

=cut

package Bio::EnsEMBL::Glyph::Symbol;
use strict;

sub new {
    my ($class, $featuredata, $styledata) = @_;
    # featuredata and styledata are passed in separately, because styledata
    # comes from DAS, and could clobber keys in featuredata if they were 
    # combined.

    my $self = {
	    'feature' => $featuredata,
	    'style' => $styledata,
    };
    bless($self, $class);
    return $self;
}

sub style {
    my $self = shift;
    return $self->{'style'};
}


sub feature {
    my $self = shift;
    return $self->{'feature'};
}

1;

package Bio::EnsEMBL::GlyphSet::repeat;

use strict;
use vars qw(@ISA);
use Bio::EnsEMBL::GlyphSet;
use Bio::EnsEMBL::Glyph::Rect;
use Bio::EnsEMBL::Glyph::Text;

@ISA = qw( Bio::EnsEMBL::GlyphSet );

sub init_label {
    my ($self) = @_;
    return if( defined $self->{'config'}->{'_no_label'} );
    my $label = new Bio::EnsEMBL::Glyph::Text({
        'text'      => 'Repeats',
        'font'      => 'Small',
        'absolutey' => 1,
    });
    $self->label($label);
}

sub _init {
    my ($self) = @_;
    my $vc             = $self->{'container'};
    my $Config         = $self->{'config'};
    my $max_length     = $Config->get( 'repeat', 'threshold' ) || 2000;
    
    return unless ( $self->strand() == -1 );

    if( $vc->length() > ($max_length*1001)) {
        $self->errorTrack("Repeats only displayed for less than $max_length Kb.");
        return;
    }

    my $h              = 8;
    my $feature_colour = $Config->get( 'repeat', 'col' );

    foreach my $f ( $vc->get_all_RepeatFeatures( $self->glob_bp() ) ) {
        my $glyph = new Bio::EnsEMBL::Glyph::Rect({
            'x'         => $f->start(),
            'y'         => 0,
            'width'     => $f->length(),
            'height'    => $h,
            'colour'    => $feature_colour,
            'absolutey' => 1,
        });
        $self->push( $glyph );
    }
}

1;

package Bio::EnsEMBL::GlyphSet::annotation_status;
use strict;
use vars qw(@ISA);
use Bio::EnsEMBL::GlyphSet_simple;
@ISA = qw(Bio::EnsEMBL::GlyphSet_simple);

sub my_label { 
    my $self = shift;
    return $self->my_config('label');
}

sub features {
    my $self = shift;
    return $self->{'container'}->get_all_MiscFeatures('NoAnnotation');
}

sub tag {
    my ($self, $f) = @_;
    return {
        'style' => 'join',
        'tag' => $f->{'start'}.'-'.$f->{'end'},
        'colour' => 'gray85'
    };
}

sub zmenu {
    return { 
        'caption' => 'No manual annotation',
    };
}

sub colour {
    return 'gray50';
}

sub no_features {
    ## don't show the track if there the whole region is annotated
    return;
}

1;

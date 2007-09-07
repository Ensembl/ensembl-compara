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
    
    my @features;
    push @features,
        @{ $self->{'container'}->get_all_MiscFeatures('NoAnnotation') },
        @{ $self->{'container'}->get_all_MiscFeatures('CORFAnnotation') };

 
    foreach my $f (@features) {
        my ($ms) = @{ $f->get_all_MiscSets('NoAnnotation') };
        ($ms) = @{ $f->get_all_MiscSets('CORFAnnotation') } unless $ms;
        $f->{'_miscset_code'} = $ms->code;
    }
    
    return \@features;
}

sub tag {
    my ($self, $f) = @_;

    my %defs = (
        'NoAnnotation'      => 'gray75',
        'CORFAnnotation'    => 'EEEEFF',
    );
    
    return {
        'style' => 'join',
        'tag' => $f->{'start'}.'-'.$f->{'end'},
        'colour' => $defs{ $f->{'_miscset_code'} },
        'zindex' => -20,
    };
}

sub zmenu {
    my ($self, $f) = @_;

    my %defs = (
        'NoAnnotation'      => 'No manual annotation',
        'CORFAnnotation'    => 'Only CORF annotation',
    );
    
    return { 
        'caption' => $defs{ $f->{'_miscset_code'} }
    };
}

sub colour {
    my ($self, $f) = @_;

    my ($ms) = @{ $f->get_all_MiscSets('NoAnnotation')} ||
               @{  $f->get_all_MiscSets('CORFAnnotation') };

    my %defs = (
        'NoAnnotation'      => 'gray50',
        'CORFAnnotation'    => 'EEEEFF',
    );
    
    return $defs{ $f->{'_miscset_code'} };
}

sub no_features {
    ## don't show the track if there the whole region is annotated
    return;
}

1;

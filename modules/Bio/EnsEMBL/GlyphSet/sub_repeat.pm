package Bio::EnsEMBL::GlyphSet::sub_repeat;
use strict;
use vars qw(@ISA);
use Bio::EnsEMBL::GlyphSet::repeat_lite;
@ISA = qw( Bio::EnsEMBL::GlyphSet::repeat_lite );

sub my_label { 
    my $self = shift;
    my $name = $self->{'extras'}->{'name'};
    if(length($name)>12) {
       $name =~s/ransposons/ransp./s;
       $name =~s/epeats/ep./;
    }
    return $name;
}

sub check { return 'sub_repeat'; }

sub features {
    my $self = shift;
    return $self->{'container'}->get_all_RepeatFeatures( $self->{'extras'}->{'name'} );
}

sub managed_name {
    my $self = shift;
    (my $T = $self->{'extras'}->{'name'}) =~ s/\W+/_/g;
    return "managed_repeat_$T";
}

1 ;

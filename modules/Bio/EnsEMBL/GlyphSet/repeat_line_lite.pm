package Bio::EnsEMBL::GlyphSet::repeat_line_lite;
use strict;
use vars qw(@ISA);
use Bio::EnsEMBL::GlyphSet_simple_hash;

@ISA = qw( Bio::EnsEMBL::GlyphSet_simple_hash );

sub my_label { return "Repeats (LINE)"; }

sub features {
    my $self = shift;
    
    my $max_length = $self->{'config'}->get( 'repeat_line_lite', 'threshold' ) || 2000;
    return @{$self->{'container'}->get_all_RepeatFeatures_lite( 'LINE', $self->glob_bp() )};
}

sub zmenu {
    my( $self, $f ) = @_;
    return {
        'caption' 											=> $f->{'hid'},
		"bp: $f->{'chr_start'}-$f->{'chr_end'}" 			=> '',
		"length: ".($f->{'chr_end'}-$f->{'chr_start'}+1) 	=> ''
    }
}

1;

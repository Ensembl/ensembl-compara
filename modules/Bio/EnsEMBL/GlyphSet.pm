package Bio::EnsEMBL::GlyphSet;
use strict;
use Exporter;
use Sanger::Graphics::GlyphSet;

use vars qw(@ISA $AUTOLOAD);

@ISA=qw(Sanger::Graphics::GlyphSet);

#########
# constructor
#
sub new {
    my $class = shift;
    my $self = $class->SUPER::new( @_ );
       $self->{'label2'}     = undef;
       $self->{'bumpbutton'} = undef;
    return $self;
}

sub bumpbutton {
    my ($self, $val) = @_;
    $self->{'bumpbutton'} = $val if(defined $val);
    return $self->{'bumpbutton'};
}

sub label2 {
    my ($self, $val) = @_;
    $self->{'label2'} = $val if(defined $val);
    return $self->{'label2'};
}

sub check {
    my( $self ) = @_;
    ( my $feature_name = ref $self) =~s/.*:://;
    return $self->{'config'}->is_available_artefact( $feature_name ) ? $feature_name : undef ;
}

## Stuff copied out of scalebar.pm so that contig.pm can use it!

sub zoom_URL {
    my( $self, $PART, $interval_middle, $width, $factor, $highlights ) = @_;
    my $start = int( $interval_middle - $width / 2 / $factor);
    my $end   = int( $interval_middle + $width / 2 / $factor);        
    return qq(/$ENV{'ENSEMBL_SPECIES'}/$ENV{'ENSEMBL_SCRIPT'}?$PART&vc_start=$start&vc_end=$end&$highlights);
}

sub zoom_zmenu {
    my ($self, $chr, $interval_middle, $width, $highlights) = @_;
    return { 
            'caption'                          => "Navigation",
            '01:Zoom in (x10)'                 => $self->zoom_URL($chr, $interval_middle, $width, 10  , $highlights),
            '02:Zoom in (x5)'                  => $self->zoom_URL($chr, $interval_middle, $width,  5  , $highlights),
            '03:Zoom in (x2)'                  => $self->zoom_URL($chr, $interval_middle, $width,  2  , $highlights),
            '04:Centre on this scale interval' => $self->zoom_URL($chr, $interval_middle, $width,  1  , $highlights), 
            '05:Zoom out (x0.5)'               => $self->zoom_URL($chr, $interval_middle, $width,  0.5, $highlights), 
            '06:Zoom out (x0.2)'               => $self->zoom_URL($chr, $interval_middle, $width,  0.2, $highlights), 
            '07:Zoom out (x0.1)'               => $self->zoom_URL($chr, $interval_middle, $width,  0.1, $highlights)                 
    };
}

1;

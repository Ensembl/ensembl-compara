package Bio::EnsEMBL::GlyphSet::tilepath2;
use strict;
use vars qw(@ISA);
use Bio::EnsEMBL::GlyphSet_simple;
@ISA = qw(Bio::EnsEMBL::GlyphSet_simple);

sub my_label { return "Tilepath(2)"; }

## Retrieve all tile path clones - these are the clones in the
## subset "tilepath".

sub features {
    my ($self) = @_;
    my $container_length = $self->{'container'}->length();
    return $self->{'container'}->get_all_MapFrags( 'tilepath' );
}

## If tile path clones are very long then we draw them as "outlines" as
## we aren't convinced on their quality...

sub colour {
    my ($self, $f ) = @_;
    $self->{'_colour_flag'} = $self->{'_colour_flag'}==1 ? 2 : 1;
    return 
        $self->{'colours'}{"col$self->{'_colour_flag'}"},
        $self->{'colours'}{"lab$self->{'_colour_flag'}"},
        $f->length > $self->{'config'}->get( "tilepath2", 'outline_threshold' ) ? 'border' : ''
        ;
}

## Return the image label and the position of the label
## (overlaid means that it is placed in the centre of the
## feature.

sub image_label {
    my ($self, $f ) = @_;
    return ($f->name,'overlaid');
}

## Link back to this page centred on the map fragment

sub href {
    my ($self, $f ) = @_;
    return "/$ENV{'ENSEMBL_SPECIES'}/$ENV{'ENSEMBL_SCRIPT'}?mapfrag=".$f->name
}

sub tag {
    my ($self, $f) = @_;
    return (
        { 'style'=>'left-triangle',  'colour' => 'a' },
        { 'style'=>'right-triangle', 'colour' => 'b' },
        { 'style'=>'underline',      'colour' => 'd' }
    );
}
## Create the zmenu...
## Include each accession id separately

sub zmenu {
    my ($self, $f ) = @_;
    my $zmenu = { 
        'caption'                               => "Clone: ".$f->name,
        '01:bp: '.$f->seq_start."-".$f->seq_end => '',
        '02:length: '.$f->length.' bps'         => '',
        '03:Centre on clone'                    => $self->href($f),
    };
    foreach(keys %{$f->embl_acc}) {
        $zmenu->{"12:EMBL: $_" } = '';
    }
    return $zmenu;
}

1;

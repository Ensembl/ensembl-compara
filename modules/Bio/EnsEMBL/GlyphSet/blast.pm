package Bio::EnsEMBL::GlyphSet::blast;
use strict;
use vars qw(@ISA);
use Bio::EnsEMBL::GlyphSet;
@ISA = qw(Bio::EnsEMBL::GlyphSet);
use Bio::EnsEMBL::Glyph::Rect;
use Bio::EnsEMBL::Glyph::Text;
use ColourMap;

sub init_label {
    my ($self) = @_;
    return if( defined $self->{'config'}->{'_no_label'} );
    my $label = new Bio::EnsEMBL::Glyph::Text({
    'text'      => 'BLAST hits',
    'font'      => 'Small',
    'absolutey' => 1,
    });
    $self->label($label);
}

sub _init {
    my ($self) = @_;

    return unless ($self->strand() == 1);
    print STDERR "BLAST\n";

    # Lets see if we have a BLAST hit
    # entry in higlights of the form BLAST:start:end

    my @hits;
    
    print STDERR "HI: ",$self->highlights,"\n";
    foreach($self->highlights) { 
        if(/BLAST:(\d+):(\d+)/) { push @hits, [$1,$2-$1]; } 
    }
    return unless @hits;

    ## We have a hit!;
  
    my $vc       = $self->{'container'};
    my $Config   = $self->{'config'};
    my $cmap     = $Config->colourmap();
    my $col      = $Config->get('blast','col');

    ## Lets draw a line across the glyphset

    my $gline = new Bio::EnsEMBL::Glyph::Rect({
        'x'         => 0,# $vc->_global_start(),
        'y'         => 4,
        'width'     => $vc->_global_end() - $vc->_global_start(),
        'height'    => 0,
        'colour'    => $cmap->id_by_name('grey1'),
        'absolutey' => 1,
    });
    $self->push($gline);

    ## Lets draw a box foreach hit!
    foreach my $hit ( @hits ) {
        print STDERR "BLAST: $hit->[0] $hit->[1]\n";
        my $gbox = new Bio::EnsEMBL::Glyph::Rect({
            'x'         => $hit->[0] - $vc->_global_start(),
            'y'         => 0,
            'width'     => $hit->[1],
            'height'    => 8,
            'colour'    => $col,
            'absolutey' => 1,
        });
        $self->push($gbox);
    }
}

1;

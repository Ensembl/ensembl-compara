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

    my @blast_tickets;
    
    print STDERR "HI: ",$self->highlights,"\n";
    foreach($self->highlights) { 
        if(/BLAST:(.*)/) { push @blast_tickets, $1; } 
    }
    return unless @blast_tickets;

    my $vc   = $self->{'container'};
    my $vc_s = $vc->_global_start();
    my $vc_e = $vc->_global_end();
    my $vc_chr = $vc->_chr_name();
    my @hits;
    foreach my $ticket (@blast_tickets) {
        if( -e "/nfs/WWW/data/blastqueue/$ticket.cache" ) {
            open FH, "/nfs/WWW/data/blastqueue/$ticket.cache";
            while(<FH>) {
                chomp;
                my ($h_chr, $h_s, $h_e, $h_score, $h_percent, $h_name) = split /\|/;
                if($h_chr eq $vc_chr) {
                    push @hits, [$h_s,$h_e,$h_score,$h_percent,$ticket, $h_name] if(
                        ($h_s < $vc_s && $vc_e > $h_e) ||
                        ($vc_s <= $h_s && $h_s <= $vc_e) ||
                        ($vc_s <= $h_e && $h_e <= $vc_e)
                    )
                }
            }
            close FH;
        }
    }
    return unless @hits;
    ## We have a hit!;
  
    my $Config   = $self->{'config'};
    my $cmap     = $Config->colourmap();
    my $col      = $Config->get('blast','col');

    ## Lets draw a line across the glyphset

    my $gline = new Bio::EnsEMBL::Glyph::Rect({
        'x'         => 0,# $vc->_global_start(),
        'y'         => 4,
        'width'     => $vc_e - $vc_s,
        'height'    => 0,
        'colour'    => $cmap->id_by_name('grey1'),
        'absolutey' => 1,
    });
    $self->push($gline);

    ## Lets draw a box foreach hit!
    foreach my $hit ( @hits ) {
        my $start = $hit->[0] < $vc_s ? $vc_s : $hit->[0];
        my $end   = $hit->[1] > $vc_e ? $vc_e : $hit->[1];
        $start = 0 if $start < 0;
        print STDERR "BLAST: $hit->[0] $hit->[1]\n";
        my $gbox = new Bio::EnsEMBL::Glyph::Rect({
            'x'         => $start - $vc_s,
            'y'         => 0,
            'width'     => $end - $start,
            'height'    => 8,
            'colour'    => $col,
            'zmenu'     => {
                'caption' => 'Blast hit',
                "Score: $hit->[2]; identity: $hit->[3]%" => '',
                '&nbsp;&nbsp;Show blast alignment' =>
				    "/$ENV{'ENSEMBL_SPECIES'}/blastview?format=hit_format&id=$hit->[4]&hit=$hit->[5]",
                '&nbsp;&nbsp;Show on karyotype' =>
				    "/$ENV{'ENSEMBL_SPECIES'}/blastview?format=karyo_format&id=$hit->[4]"
            },
            'absolutey' => 1,
        });
        $self->push($gbox);
    }
}

1;

package Bio::EnsEMBL::GlyphSet::snplotype;
use strict;
use vars qw(@ISA);
use Bio::EnsEMBL::GlyphSet;
@ISA = qw(Bio::EnsEMBL::GlyphSet);
use Bio::EnsEMBL::Glyph::Rect;
use Bio::EnsEMBL::Glyph::Text;
use Bio::EnsEMBL::Glyph::Composite;
use ExtURL;

use Bump;

sub init_label {
    my ($self) = @_;
	return if( defined $self->{'config'}->{'_no_label'} );
    my $label = new Bio::EnsEMBL::Glyph::Text({
	'text'      => '',
	'font'      => 'Small',
	'absolutey' => 1,
    });
    $self->label($label);
}

sub _init {
    my ($self) = @_;

    return if ($self->strand == 1); # this is an unstranded attribute
    my $hap           = $self->{'container'};

    if (ref($hap) && $hap =~ /Haplotype/){
        #print STDERR "$hap\n";
        create_haplotype_block($self, $hap);
        
    } elsif (ref($hap) && $hap =~ /ARRAY/) {
        # we have been passed a list of haplotype objects
        #print STDERR "$hap\n";
        create_multiple_haplotype_block($self, $hap);
    }

}

###############################################################
sub create_multiple_haplotype_block {
    my ($self, $haplist) = @_;

    my @haplist = @{$haplist};
    my $Config                  = $self->{'config'};
    my $colour                  = $Config->get('snplotype','col');
    my $font                    = "Small";
    my ($fontwidth,$fontheight) = $Config->texthelper->px2bp($font);
    my $cmap                    = $Config->colourmap();
    my $black                   = $cmap->id_by_name('black');
    my $caption                 = "SNPlotype";

    my $showconsensus           = 0;
    my $pattern_id              = "";	

    my $internal_space          = 11;
    my $external_space          = 15;
    my $vertical_space          = 10;
    my $exvertical_space        = 15;
    my $xstart                  = 10;
    my $ystart                  = 10;

    # we need to work out the identity of the most common base at any place along
    # an individual haplotype sample and use this as the default base/colour
    # find the length of the pattern (no. of individuals types)
    my $global_ystart =10;

    foreach my $hap (@haplist){
        
        my $block_id = $hap->id();
        my @consensus_base_for_row = ();

        my $foo = $hap->patterns();
        #print STDERR ">> $foo<<\n";
        my @patterns = @{$foo};
        my $pattern_length = length($patterns[0]->pattern());
        #print STDERR "Pattern length: $pattern_length\n";


        # cover your eyes now....
        foreach my $i(0..$pattern_length-1){
            my %consensus_base = ();
            foreach my $pat (@patterns){        
                foreach my $s (values %{$pat->samples()}){
                    my @bases = split('',$s);
                    my $base = $bases[$i]; 
                    #print STDERR "position $i ==> $base\n";
                    $consensus_base{$base}++ if $base ne 'N';
                }
            }    
            my @k = sort {$consensus_base{$b} <=> $consensus_base{$a}} keys %consensus_base;
            $consensus_base_for_row[$i] = shift(@k);
            #print STDERR "Consensus base for row $i ==> ", $consensus_base_for_row[$i], " \n";
        }     
        # OK, its safe to open them...

        ## draw a matrix of block representing the grouped haplotype consensus pattern

        foreach my $pat (@patterns){        

            ## end of consensus column for all patterns
            ## now start looping through the sample columns...
            my %samples = %{$pat->samples()};
            my $type = "wt";
            
            foreach my $key (keys %samples){
                my $i = 0;
                my @sample = split('',$samples{$key});
                $ystart = $global_ystart;
                foreach my $b (@sample){
                    if ($b eq $consensus_base_for_row[$i]){
                        $type = 'wt';
                    } else {
                        $type = 'snp';
                    }
                    my @glyphs = draw_unlabelled_snp_block($cmap,$xstart,$ystart,$type,$b);
                    foreach (@glyphs){
                        $self->push($_);
                    }
                    $ystart += $vertical_space;
                    $i++;
                }
                $xstart += $internal_space;
            }

            #$xstart += $external_space;
            
        }
        $global_ystart = $ystart;
        $xstart = 10;
    }   
}

#########################################################################################
sub create_haplotype_block {
    my ($self, $hap) = @_;

    my $Config                  = $self->{'config'};
    my $colour                  = $Config->get('snplotype','col');
    my $font                    = "Small";
    my ($fontwidth,$fontheight) = $Config->texthelper->px2bp($font);
    my $cmap                    = $Config->colourmap();
    my $black                   = $cmap->id_by_name('black');
    my $caption                 = "SNPlotype";

    my $block_id                = $hap->id();
    my $showconsensus           = 0;
    my $pattern_id              = "";	

    my $internal_space          = 18;
    my $external_space          = 10;
    
    my $vertical_space          = 16;
    my $exvertical_space        = 10;

    my $xstart                  = 0;
    my $global_ystart           = 30;
    my $ystart                  = 30;


    # draw the SNP ID column label
    my $tglyph = new Bio::EnsEMBL::Glyph::Text({
        'x'          => $xstart,
        'y'          => $global_ystart - 30 + 1,
        'font'       => 'Small',
        'colour'     => $black,
        'text'       => "dbSNP ID",
        'absolutex'  => 1,
        'absolutey'  => 1,
    });
    $self->push($tglyph);
    foreach my $s ( @{$hap->snps()} ){
        my $tglyph = new Bio::EnsEMBL::Glyph::Text({
            'x'          => $xstart,
            'y'          => $ystart,
            'font'       => 'Small',
            'colour'     => $black,
            'text'       => uc($s),
            'absolutex'  => 1,
            'absolutey'  => 1,
        });
        $self->push($tglyph);
        $ystart += $vertical_space;
    }

    $xstart                  += 75;
    $ystart                  = 30;


    # we need to work out the identity of the most common base at any place along
    # an individual haplotype sample and use this as the default base/colour
    # find the length of the pattern (no. of individuals types)

    my @consensus_base_for_row = ();

    my @patterns = @{$hap->patterns()};
    my $pattern_length = length($patterns[0]->pattern());
    #print STDERR "Pattern length: $pattern_length\n";


    # cover your eyes now....
    foreach my $i(0..$pattern_length-1){
        my %consensus_base = ();
        foreach my $pat (@patterns){        
            foreach my $s (values %{$pat->samples()}){
                my @bases = split('',$s);
                my $base = $bases[$i]; 
                #print STDERR "position $i ==> $base\n";
                $consensus_base{$base}++ if $base ne 'N';
            }
        }    
        my @k = sort {$consensus_base{$b} <=> $consensus_base{$a}} keys %consensus_base;
        $consensus_base_for_row[$i] = shift(@k);
        #print STDERR "Consensus base for row $i ==> ", $consensus_base_for_row[$i], " \n";
    }     
    # OK, its safe to open them...
    
    ## draw a matrix of block representing the grouped haplotype consensus patters
    
    my $j = 0;
    foreach my $pat (@patterns){        
        # draw the consensus columns...
        next if ($pat->count()<2);
        my $type = "cons";
        if($showconsensus){
            foreach(split('',$pat->pattern())){
                my @glyphs = draw_labelled_snp_block($cmap,$xstart,$ystart,$type,$_);
                foreach (@glyphs){
                    $self->push($_);
                }
                $ystart += $vertical_space;
            }
            $xstart += $internal_space;
            $ystart = $global_ystart;
        }
        my $type = "wt";
        
        ## end of consensus column for all patterns
        ## now start looping through the sample columns...
        my %samples = %{$pat->samples()};
        foreach my $key (keys %samples){
            my $i = 0;
            my @sample = split('',$samples{$key});
    my $tglyph = new Bio::EnsEMBL::Glyph::Text({
        'x'          => $xstart + 5,
        'y'          => $global_ystart - 30 + 1,
        'font'       => 'Small',
        'colour'     => $black,
        'text'       => $j+1,
        'absolutex'  => 1,
        'absolutey'  => 1,
    });
    $self->push($tglyph);
    $j++;
            foreach my $b (@sample){
                if ($b eq $consensus_base_for_row[$i]){
                    $type = 'wt';
                } else {
                    $type = 'snp';
                }
                my @glyphs = draw_labelled_snp_block($cmap,$xstart,$ystart,$type,$b);
                foreach (@glyphs){
                    $self->push($_);
                }
                $ystart += $vertical_space;
                $i++;
            }
            $xstart += $internal_space;
            $ystart = $global_ystart;
        }
        $xstart += $external_space;
        $ystart = $global_ystart;
        
    }

    # draw the SNP ID column label
    #my $tglyph = new Bio::EnsEMBL::Glyph::Text({
    #    'x'          => $xstart+7,
    #    'y'          => $global_ystart - 30 + 1,
    #    'font'       => 'Small',
    #    'colour'     => $black,
    #    'text'       => "SNP ID",
    #    'absolutex'  => 1,
    #    'absolutey'  => 1,
    #});
    #$self->push($tglyph);
    
    # draw the SNP position column label
    my $tglyph = new Bio::EnsEMBL::Glyph::Text({
        'x'          => $xstart+10,
        'y'          => $global_ystart - 30 + 1,
        'font'       => 'Small',
        'colour'     => $black,
        'text'       => "Poly. Pos.",
        'absolutex'  => 1,
        'absolutey'  => 1,
    });
    $self->push($tglyph);

    # draw the row labels
    foreach my $s ( @{$hap->snps()} ){
        my $snp_info = $hap->snp_info($s);
        my $pos =  $snp_info->{'position'};
        #my $tglyph = new Bio::EnsEMBL::Glyph::Text({
        #    'x'          => $xstart+7,
        #    'y'          => $ystart,
        #    'font'       => 'Small',
        #    'colour'     => $black,
        #    'text'       => uc($s),
        #    'absolutex'  => 1,
        #    'absolutey'  => 1,
        #});

        my $pglyph = new Bio::EnsEMBL::Glyph::Text({
            'x'          => $xstart+10,
            'y'          => $ystart,
            'font'       => 'Small',
            'colour'     => $black,
            'text'       => "${pos} bp",
            'absolutex'  => 1,
            'absolutey'  => 1,
        });
        $ystart += $vertical_space;
        #$self->push($tglyph);
        $self->push($pglyph);
    }     




}



#########################################################################
sub draw_labelled_snp_block {

    my ($cmap, $x, $y, $type, $label) = @_;
    
    my $white    = $cmap->id_by_name('white');
    my $black    = $cmap->id_by_name('black');
    my $blue     = $cmap->id_by_name('blue');
    my $yellow   = $cmap->id_by_name('yellow');
    my $red      = $cmap->id_by_name('red');

    my $bg = $yellow;
    my $fg = $black;
    
    if($label eq '+') {
        $bg = $red;
        $fg = $white;
    } elsif( $label eq '-') {
        $bg = $white;
        $fg = $red;
    } elsif ($type eq "wt") {
        $bg = $blue;
        $fg = $white;        
    } elsif ($type eq "cons") {
        $bg = $red;
        $fg = $white;        
    } 
    
    if (uc($label) =~/[N|\?]/ && $type ne "cons"){
        return();
    } else {
        my $block = new Bio::EnsEMBL::Glyph::Rect({
            'x'         => $x,
            'y'         => $y,
            'width'     => 16,
            'height'    => 14,
            'colour'    => $bg,
            'bordercolour' => $black,
            'absolutey' => 1,
            'absolutex' => 1,
        });

        my $tglyph = new Bio::EnsEMBL::Glyph::Text({
            'x'          => $x+7,
            'y'          => $y+4,
            'font'       => 'Tiny',
            'colour'     => $fg,
            'text'       => uc($label),
            'absolutex'  => 1,
            'absolutey'  => 1,
        });
        return($block,$tglyph);
    }
}

#########################################################################
sub draw_unlabelled_snp_block {

    my ($cmap, $x, $y, $type, $label) = @_;
    
    my $white    = $cmap->id_by_name('white');
    my $black    = $cmap->id_by_name('black');
    my $blue     = $cmap->id_by_name('blue');
    my $yellow   = $cmap->id_by_name('yellow');
    my $red      = $cmap->id_by_name('red');

    my $bg = $yellow;
    my $fg = $black;
    
    if($label eq '+') {
        $bg = $red;
        $fg = $white;
    } elsif( $label eq '-') {
        $bg = $white;
        $fg = $red;
    } elsif ($type eq "wt") {
        $bg = $blue;
        $fg = $white;        
    } elsif ($type eq "cons") {
        $bg = $red;
        $fg = $white;        
    } 
    
    if (uc($label) =~/[N|\?]/ && $type ne "cons"){
        return();
    } else {
        my $block = new Bio::EnsEMBL::Glyph::Rect({
            'x'         => $x,
            'y'         => $y,
            'width'     => 8,
            'height'    => 7,
            'colour'    => $bg,
            'bordercolour' => $black,
            'absolutey' => 1,
            'absolutex' => 1,
        });

    }
}
#########################################################################

1;

package Bio::EnsEMBL::GlyphSet::codons;
use strict;
use vars qw(@ISA);
use Bio::EnsEMBL::GlyphSet;
@ISA = qw(Bio::EnsEMBL::GlyphSet);
use Bio::EnsEMBL::Glyph::Rect;
use Bio::EnsEMBL::Glyph::Text;

sub init_label {
    my ($self) = @_;
    return if( defined $self->{'config'}->{'_no_label'} );
    my $label = new Bio::EnsEMBL::Glyph::Text({
		'text'      => "Start/Stop",
		'font'      => 'Small',
		'absolutey' => 1
    });
    $self->label($label);
}

sub _init {
    my ($self) = @_;
	my $data;
	my $offset;
    my $vc 		 = $self->{'container'};
    my $Config   = $self->{'config'};
	my $max_len  = 50; # In Kbases...
	my $height   = 3;  # Pixels in height for glyphset
	my $padding  = 1;  # Padding
    my $red      = $Config->colourmap()->id_by_name('red');
    my $green    = $Config->colourmap()->id_by_name('green');
    my ($w,$h)   = $Config->texthelper()->real_px2bp('Tiny');
    my $length   = $vc->length() +1;
	if($length> ($max_len*1001)) {
		my $text = "Start/Stop codons only displayed for less than $max_len Kb.";
        my $bp_textwidth = $w * length($text);
        my $tglyph = new Bio::EnsEMBL::Glyph::Text({
                'x'         => int(($length - $bp_textwidth)/2),
                'y'         => 0,
    	    	'height' 	=> 8,
                'font'      => 'Tiny',
                'colour'    => $red,
                'text'      => $text,
                'absolutey' => 1,
        });
		$self->push($tglyph);
		return;
	}
	if($Config->{'__codon__cache__'}) {
# Reverse strand so we retrieve information from the codon cache	
		$offset = 3; # For drawing loop look at elements 3,4, 7,8, 11,12
		$data = $Config->{'__codon__cache__'};
	} else {
		$offset = 1; # For drawing loop look at elements 1,2, 5,6, 9,10
		my $seq = $vc->seq(); # Get the sequence
		$data = [];
# Start/stop codons on the forward strand have value 1/2
# Start/stop codons on the reverse strand have value 3/4
   		my %h = (
			'ATG'=>1,
			'TAA'=>2,'TAG'=>2,'TGA'=>2,
			'CAT'=>3,
			'TTA'=>4,'CTA'=>4,'TCA'=>4
		);
# The value is used as the index in the array to store the
# information. [ For each "phase" this is incremented by 4 ]
		my $v;
		foreach my $phase(0..2) {
# For phases 1 and 2 remove a character from the beginning of the string.			
			$_ = $phase ? substr($seq,$phase) : $seq;
# Set the offset to the phase...
			my $o = $phase;			
# Perl regexp from hell! Well not really but it's a fun line anyway....			
#      step through the string three characters at a time
#      if the three characters are in the h (codon hash) then
#      we push the co-ordinate element on to the $v'th array in the data
#      array. Also update the current offset by 3...
			s/(...)/$v=$h{$1};push @{$data->[$v]},$o if $v;$o+=3;/eg;
# At the end of the phase loop lets move the indexes forward by 4
			foreach(keys %h) {$h{$_}+=4;}
		}
# Store the information in the codon cache for the reverse strand
		$Config->{'__codon__cache__'} = $data;
	}
# The twelve elements in the @$data array (@{$Config->{'__codon__cache__'}})
# are
#  1 => coordinates of phase 0 start codons on forward strand
#  2 => coordinates of phase 0 stop  codons on forward strand
#  3 => coordinates of phase 0 start codons on reverse strand
#  4 => coordinates of phase 0 stop  codons on reverse strand
#  5 => coordinates of phase 2 start codons on forward strand
#  6 => coordinates of phase 2 stop  codons on forward strand
#  7 => coordinates of phase 2 start codons on reverse strand
#  8 => coordinates of phase 2 stop  codons on reverse strand
#  9 => coordinates of phase 3 start codons on forward strand
# 10 => coordinates of phase 3 stop  codons on forward strand
# 11 => coordinates of phase 3 start codons on reverse strand
# 12 => coordinates of phase 3 stop  codons on reverse strand
    my $strand     = $offset == 3 ? -1 : 1; # These flip
	my $base       = $offset == 3 ? 21 : 0; # the track...
	my $fullheight = $height * 2 + $padding; 
	foreach my $phase (0..2){
		my $start_row = $data->[ $offset + $phase * 4    ];
		my $stop_row  = $data->[ $offset + $phase * 4 + 1];
		foreach(@$start_row) { # Co-ordinates of glyphs 3 bp wide
			my $glyph = new Bio::EnsEMBL::Glyph::Rect({
    	        'x'      	=> $_,
		    	'y'      	=> $base + $phase * $fullheight * $strand,
		    	'width'  	=> 3,
		    	'height' 	=> $height-1,
		    	'colour' 	=> $green,
		    	'absolutey' => 1,
			});
			$self->push($glyph);
		}
		foreach(@$stop_row) {
			my $glyph = new Bio::EnsEMBL::Glyph::Rect({
    	        'x'      	=> $_,
		    	'y'      	=> $base + ($phase * $fullheight + $height) * $strand,
		    	'width'  	=> 3,
		    	'height' 	=> $height-1,
		    	'colour' 	=> $red,
		    	'absolutey' => 1,
			});
			$self->push($glyph);
		}
    }
}
1;

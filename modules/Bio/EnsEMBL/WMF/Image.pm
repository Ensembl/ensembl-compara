package Image;
# Copyright 2001 Tony Cox.  See accompanying README file for
# usage information

use strict;
use WMF::Constants;
use WMF::Colour;
use WMF::Font;
use WMF::Rectangle;
use WMF::Polygon;
use vars qw($VERSION @ISA @EXPORT $AUTOLOAD $DEBUG);
$VERSION = "1.00";
$DEBUG   = 1;

sub new {
  my ($class, $filename) = @_;
  my $obj = bless {
                _filename               =>  $filename,
                _handles                =>  [],
                _word         			=>  [],
                _maxobjectsize          =>  0,
				_wmf					=>  '',
				_header					=>  '',
				_fhandle				=>  undef,
                }, $class;

	$obj->_initialise($filename);
	return $obj;
}

sub _initialise {
    my ($self, $filename) = @_;
	if (defined $filename){
		$self->{'_filename'} = $filename;
		$self->createFile();
	}
	#$self->escape("PerlWMF, v$VERSION (c) Tony Cox, 2001");

}

sub translateFontName {
    my ($self,$fontname) = @_;
	if (defined $FONTNAME{lc($fontname)}){
		return($FONTNAME{lc($fontname)});
	} else {
		print STDERR "Unsupported font (\"$fontname\") using Arial\n";
		return ($FONTNAME{'arial'});
	}
}

sub setTranslateFontNames {
    my ($self) = shift;
	%FONTNAME = @_;
}

sub getTranslateFontNames {
    my ($self) = shift;
	return (\%FONTNAME);
}

sub createFont {
    my ($self,$font,$escapement,$is_underline,$is_strikeout) = @_;
	unless ($font->isa("Font")){
		die("Invalid font object in createFont!");
	}
	my $c = $self->toByte(0x0190);
	if($font->isBold()){
		my $c = $self->toByte(0x01BC);
	}
	return($self->createFontIndirect(
    	$font->getSize(),0,$escapement,0,$c,					#int
		$font->isItalic(),$is_underline,$is_strikeout,			#bool
	    $self->toByte(0),$self->toByte(0),$self->toByte(0),		#byte
		$self->toByte(0),$self->toByte(0), 						#byte
		$self->translateFontName($font->getFace()))				#string
	)
}
	
sub createFontIndirect {
    my ($self,$i,$j,$k,$l,$i1,					#int
		$is_italic,$is_underline,$is_strikeout,	#bool
	    $charset,$outprecision,$clipprecision,$quality,$pitchandfamily, #byte
		$facename) = @_;		#string
	$self->metaRecord(763,9 + (length($facename)+2)/2);
	$self->writeWord($i);
	$self->writeWord($j);
	$self->writeWord($k);
	$self->writeWord($l);
	$self->writeWord($i1);	
	my $j1 = 0;
	if($is_italic){
		$j1=1;
	}
	if($is_underline){
		$j1+=256;
	}
	$self->writeWord($j1);
	$j1 = $charset << 8 & 0xFF00;
	if($is_strikeout){
		$j1++;
	}
	$self->writeWord($j1);
	$self->writeWord($outprecision | $clipprecision << 8 & 0xFF00);
	$self->writeWord($quality | $pitchandfamily << 8 & 0xFF00);

	my @abytes0 = ();
	my @text = split(//,reverse($facename));
	#print STDERR "Packing string: \"$facename\"\n";
	while (@text){
		my $c = shift(@text);
		$c = $self->toByte($c);
		unshift (@abytes0, $c);
	}
	unshift (@abytes0, $self->toByte(0));	# add padding byte 
	for (my $k=0;$k < scalar(@abytes0)/2;$k++){
		if (!defined $abytes0[$k*2+1]){
			$self->writeWord($abytes0[$k*2] | $self->toByte(0) << 8 & 0xFF00);
		} else {
			$self->writeWord($abytes0[$k*2] | $abytes0[$k*2+1] << 8 & 0xFF00);
		}
	}
	my $h = $self->addHandle();
	print STDERR "Added Font handle at stack position: $h\n" if $DEBUG;
	return($h);
}

sub writeColour {
    my ($self, $c) = @_;
	$self->writeInteger(	  
							  $c->red() & 0xFF
							| $c->green() << 8 & 0xFF00
							| $c->blue() << 16 & 0xFF0000 
						);
	#print STDERR "Wrote packed RGB colour structure: ";
	#print STDERR $c->red()," ",$c->green()," ",$c->blue(),"\n";
}

sub createPenIndirect {
	my ($self, $i, $j, $c) = @_;
	$self->metaRecord(762,5);
	$self->writeWord($i);
	$self->writeInteger($j);
	$self->writeColour($c);			# need to write a color object
	my $h = $self->addHandle();
	print STDERR "Added PenIndirect handle at stack position: $h\n" if $DEBUG;
	return ($h);
}

sub createBrushIndirect {
	my ($self, $i, $c, $j) = @_;
	$self->metaRecord(764,4);
	$self->writeWord($i);
	$self->writeColour($c);			# need to write a color object
	$self->writeWord($j);
	my $h = $self->addHandle();
	print STDERR "Added BrushIndirect handle at stack position: $h\n" if $DEBUG;
	return ($h);
}

sub roundRect {
	my ($self, $i, $j, $k, $l, $m, $n) = @_;
	$self->metaRecord(1564,6);
	$self->writeWord($n);
	$self->writeWord($m);
	$self->writeWord($l);
	$self->writeWord($k);
	$self->writeWord($j);
	$self->writeWord($i);
}

sub pie {
	my ($self, $i, $j, $k, $l, $m, $n, $o, $p) = @_;
	$self->metaRecord(2078,8);
	$self->writeWord($p);
	$self->writeWord($o);
	$self->writeWord($n);
	$self->writeWord($m);
	$self->writeWord($l);
	$self->writeWord($k);
	$self->writeWord($j);
	$self->writeWord($i);
}

sub arc {
	my ($self, $i, $j, $k, $l, $m, $n, $o, $p) = @_;
	$self->metaRecord(2071,8);
	$self->writeWord($p);
	$self->writeWord($o);
	$self->writeWord($n);
	$self->writeWord($m);
	$self->writeWord($l);
	$self->writeWord($k);
	$self->writeWord($j);
	$self->writeWord($i);
}

sub chord {
	my ($self, $i, $j, $k, $l, $m, $n, $o, $p) = @_;
	$self->metaRecord(2096,8);
	$self->writeWord($p);
	$self->writeWord($o);
	$self->writeWord($n);
	$self->writeWord($m);
	$self->writeWord($l);
	$self->writeWord($k);
	$self->writeWord($j);
	$self->writeWord($i);
}

sub ellipse {
	my ($self, $i, $j, $k, $l) = @_;
	$self->metaRecord(1048,4);
	$self->writeWord($l);
	$self->writeWord($k);
	$self->writeWord($j);
	$self->writeWord($i);
}

sub rectangle {
	my ($self, $i, $j, $k, $l) = @_;
	$self->metaRecord(1051,4);
	$self->writeWord($l);
	$self->writeWord($k);
	$self->writeWord($j);
	$self->writeWord($i);
}

sub setPolyFillMode {
	my ($self, $i) = @_;
	$self->metaRecord(262,1);
	$self->writeWord($i);
}

sub setMapMode {
	my ($self, $i) = @_;
	$self->metaRecord(259,1);
	$self->writeWord($i);
}

sub setROP2 {
	my ($self, $i) = @_;
	$self->metaRecord(260,1);
	$self->writeWord($i);
}

sub setBKMode {
	my ($self, $i) = @_;
	$self->metaRecord(258,1);
	$self->writeWord($i);
}

sub setBKColour {
	my ($self, $c) = @_;
	$self->metaRecord(513,2);
	$self->writeColour($c);
}

sub setTextColour {
	my ($self, $c) = @_;
	$self->metaRecord(521,2);
	$self->writeColour($c);
}

sub setTextAlign {
	my ($self, $i) = @_;
	$self->metaRecord(302,1);
	$self->writeWord($i);
}

sub setTextCharacterExtra {
	my ($self, $i) = @_;
	$self->metaRecord(264,1);
	$self->writeWord($i);
}

sub setStretchBltMode {
	my ($self, $i) = @_;
	$self->metaRecord(263,1);
	$self->writeWord($i);
}

sub setTextJustification {
	my ($self, $i, $j) = @_;
	$self->metaRecord(522,2);
	$self->writeWord($j);
	$self->writeWord($i);
}

sub setPixel {
	my ($self, $i, $j, $c) = @_;
	$self->metaRecord(1055,4);
	$self->writeColour($c);
	$self->writeWord($j);
	$self->writeWord($i);
}

sub floodFill {
	my ($self, $i, $j, $c) = @_;
	$self->metaRecord(1049,4);
	$self->writeColour($c);
	$self->writeWord($j);
	$self->writeWord($i);
}

sub extFloodFill {
	my ($self, $i, $j, $c, $k) = @_;
	$self->metaRecord(1352,5);
	$self->writeWord($k);
	$self->writeColour($c);
	$self->writeWord($j);
	$self->writeWord($i);
}

sub lineTo {
	my ($self, $i, $j) = @_;
	$self->metaRecord(531,2);
	$self->writeWord($j);
	$self->writeWord($i);
}

sub moveTo {
	my ($self, $i, $j) = @_;
	$self->metaRecord(532,2);
	$self->writeWord($j);
	$self->writeWord($i);
}

sub setWindowOrg {
	my ($self, $i, $j) = @_;
	$self->metaRecord(523,2);
	$self->writeWord($j);
	$self->writeWord($i);
}

sub setViewportOrg {
	my ($self, $i, $j) = @_;
	$self->metaRecord(525,2);
	$self->writeWord($j);
	$self->writeWord($i);
}

sub offsetViewportOrg {
	my ($self, $i, $j) = @_;
	$self->metaRecord(529,2);
	$self->writeWord($j);
	$self->writeWord($i);
}

sub setViewportExt {
	my ($self, $i, $j) = @_;
	$self->metaRecord(526,2);
	$self->writeWord($j);
	$self->writeWord($i);
}

sub scaleWindowExt {
	my ($self, $i, $j, $k, $l) = @_;
	$self->metaRecord(1024,4);
	$self->writeWord($l);
	$self->writeWord($k);
	$self->writeWord($j);
	$self->writeWord($i);
}

sub scaleViewportExt {
	my ($self, $i, $j, $k, $l) = @_;
	$self->metaRecord(1042,4);
	$self->writeWord($l);
	$self->writeWord($k);
	$self->writeWord($j);
	$self->writeWord($i);
}

sub patBlt {
	my ($self, $i, $j, $k, $l, $m) = @_;
	$self->metaRecord(1565,4);
	$self->writeInteger($m);
	$self->writeWord($l);
	$self->writeWord($k);
	$self->writeWord($j);
	$self->writeWord($i);
}

sub offsetWindowOrg {
	my ($self, $i, $j) = @_;
	$self->metaRecord(527,2);
	$self->writeWord($j);
	$self->writeWord($i);
}

sub setWindowExt {
	my ($self, $i, $j) = @_;
	$self->metaRecord(524,2);
	$self->writeWord($j);
	$self->writeWord($i);
}

sub polygon {
	my ($self, $arrayref, $arrayref2, $i) = @_;
	$self->metaRecord(804,1+2*$i);
	$self->writeWord($i);
	for (my $k=0;$k<$i;$k++){
		$self->writeWord($arrayref->[$k]);
		$self->writeWord($arrayref2->[$k]);
	}
}

sub polyline {
	my ($self, $arrayref, $arrayref2, $i) = @_;
	$self->metaRecord(805,1+2*$i);
	$self->writeWord($i);
	for (my $k=0;$k<$i;$k++){
		$self->writeWord($arrayref->[$k]);
		$self->writeWord($arrayref2->[$k]);
	}
}

# Add an WMF comment to the file.
# Some byte fixing required here. Have to pad with a null 
# byte if using a string with odd number of characters??
sub escape {
	my ($self, $text) = @_;
	my @abytes0 = ();
	
	my @text = split(//,reverse($text));
	print STDERR "Embedded comment: \"$text\" (",length($text)," chars)\n" if $DEBUG;
	while (@text){
		my $c = shift(@text);
		$c = $self->toByte($c);
		unshift (@abytes0, $c);
	}
	if(length($text) % 2 == 0){
		unshift (@abytes0, $self->toByte(0));	# add padding byte
		print STDERR "Adding padding byte\n";
	}
	$self->metaRecord(1574, 2+(scalar(@abytes0)+1)/2);
	$self->writeWord(scalar(@abytes0));
	
	my $newArrayLen = ((scalar(@abytes0)+1)/2)*2;
	$self->writeWord(length($text)/2);
	
	for (my $j=0;$j < $newArrayLen;$j+=2){
		if (!defined $abytes0[$j+1]){
			$self->writeWord($abytes0[$j] | $self->toByte(0) << 8 & 0xFF00);
		} else {
			$self->writeWord($abytes0[$j] | $abytes0[$j+1] << 8 & 0xFF00);
		}
	}
	
}

sub textOut {
	my ($self, $i, $j, $text) = @_;
	$self->metaRecord(1313, 3+(length($text)+1)/2);
	$self->writeWord(length($text));
	
	my @abytes0 = ();
	my @text = split(//,reverse($text));
	print STDERR "Packing string: \"$text\"\n" if $DEBUG;
	while (@text){
		my $c = shift(@text);
		$c = $self->toByte($c);
		unshift (@abytes0, $c);
	}
	for (my $k=0;$k < scalar(@abytes0)/2;$k++){
		my $l = 0;
		if (!defined $abytes0[$k*2+1]){
			$l = $abytes0[$k*2] | $self->toByte(0) << 8 & 0xFF00;
		} else {
			$l = $abytes0[$k*2] | $abytes0[$k*2+1] << 8 & 0xFF00;
		}
		$self->writeWord($l);
	}
	$self->writeWord($j);
	$self->writeWord($i);
}

sub extTextOut {
	my ($self, $i, $j, $k, $rect, $text, $spacing_arrayref) = @_;
	my @spaces = ();
	if (defined ($spacing_arrayref)){
		print STDERR "Setting spacing array\n" if $DEBUG;
		@spaces = @$spacing_arrayref;
	}
	my $l = 4 + (length($text)+1)/2;
	if ($k != 0){
		$l += 4;
	}
	if (defined $spacing_arrayref){
		$l += length($text);
	}
	$self->metaRecord(2610,$l);
	$self->writeWord($j);
	$self->writeWord($i);
	$self->writeWord(length($text));
	$self->writeWord($k);
	if($k != 0){
		$self->writeWord($rect->x());
		$self->writeWord($rect->y());
		$self->writeWord($rect->width());
		$self->writeWord($rect->height());
	}
	my @abytes0 = ();
	my @text = split(//,reverse($text));
	#print STDERR "Packing string: \"$text\"\n";
	while (@text){
		my $c = shift(@text);
		$c = $self->toByte($c);
		unshift (@abytes0, $c);
	}
	print STDERR "Packing ",scalar(@abytes0)/2," bytes\n" if $DEBUG;
	for (my $k=0;$k < scalar(@abytes0)/2;$k++){
		my $l = 0;
		$l = @abytes0[$k*2] | @abytes0[$k*2+1] << 8 & 0xFF00;
		$self->writeWord($l);
	}
	if ($spacing_arrayref){
		for (my $k=0;$k < length($text);$k++){
			$self->writeWord($spaces[$k]);
		}
	}
}

sub selectObject {
	my ($self, $i) = @_;
	my $handles = $self->{'_handles'};
	if ($i < scalar(@$handles) && $handles->[$i] == 1){
		$self->metaRecord(301, 1);
		$self->writeWord($i);
		return;
	} else {
		die "GDI object handle (select) exception: array out of bounds ($i)\n"
	}
}

sub deleteObject {
	my ($self, $i) = @_;
	my $handles = $self->{'_handles'};
	if ($i < scalar(@$handles) && $handles->[$i] == 1){
		$self->metaRecord(496, 1);
		$self->writeWord($i);
		$handles->[$i] = 0;
		print STDERR "Removed GDI object handle at stack position: $i\n" if $DEBUG;
		return;
	} else {
		die "GDI object handles (delete) exception: can't remove object $i\n"
	}
}

sub deleteObjects {
	my ($self) = @_;
	my $handles = $self->{'_handles'};
	for (my $i=0;$i < scalar(@$handles);$i++){
		if($handles->[$i] == 1){
			$self->deleteObject($i);	
			print STDERR "GDI handle stack cleanup: $i\n" if $DEBUG;
		}
	} 
}

sub addHandle {
	my ($self) = @_;
	my $handles = $self->{'_handles'};
	for (my $i=0; $i < scalar(@$handles); $i++){
		if ($handles->[$i] == 0){
			$handles->[$i] = 1;
			return($i)
		}
	}
	push (@$handles,1);
	return (scalar(@$handles) - 1);	
}

sub metaRecord {
	my ($self, $i, $j) = @_;
	my $k = $j + 3;
	$self->writeInteger($k);
	$self->writeWord($i);
	$self->maxObjectSize($k);
}

sub maxObjectSize {
	my ($self, $i) = @_;
	if ($i > $self->{'_maxobjectsize'}){
		$self->{'_maxobjectsize'} = $i;
	}
}

sub getBodySize {
	my ($self) = @_;
	return (length($self->{'_wmf'})/2);
}

sub makePlaceableHeader {
	my ($self,$i,$j,$k,$l,$i1) = @_;
	$self->outputHeaderInteger(0x9ac6cdd7);
	$self->outputHeaderWord(0);
	$self->outputHeaderWord($i);
	$self->outputHeaderWord($j);
	$self->outputHeaderWord($k);
	$self->outputHeaderWord($l);
	$self->outputHeaderWord($i1);
	$self->outputHeaderInteger(0);
	$self->outputHeaderWord($self->calcChecksum($i1,$i,$j,$k,$l));
	$self->makeHeader();
}

sub makeHeader {
	my ($self) = @_;
	$self->outputHeaderWord(1);
	$self->outputHeaderWord(9);
	$self->outputHeaderWord(768);
	$self->outputHeaderInteger($self->getBodySize()+9);
	$self->outputHeaderWord(scalar(@{$self->{'_handles'}}));
	$self->outputHeaderInteger($self->{'_maxobjectsize'});
	$self->outputHeaderWord(0);
	
	print STDERR "Header words: ", $self->getBodySize(), "\n" if $DEBUG;
	print STDERR "GDI stack size: ", scalar(@{$self->{'_handles'}}), "\n" if $DEBUG;
}

sub calcChecksum {
	my ($self, $i, $j, $k, $l, $i1) = @_;
	my $j1 = 39622;
	$j1 ^= 0xcdd7;
	$j1 ^= $i;
	$j1 ^= $j;
	$j1 ^= $k;
	$j1 ^= $l;
	$j1 ^= $i1;
	return $j1;
}

sub writeBody {
    my ($self) = @_;
	if (defined $self->{'_fhandle'}){
		my $fh = $self->{'_fhandle'};
		print $fh $self->{'_wmf'};
		$self->closeFile($self->{'_filename'})
	} else {
		die "Tried to print WMF body to a non-existent file handle!\n";
	}
}

sub writeHeader {
    my ($self) = @_;
	$self->makeHeader();
	if (defined $self->{'_fhandle'}){
		my $fh = $self->{'_fhandle'};
		print $fh $self->{'_header'};
	} else {
		die "Tried to print WMF header to a non-existent file handle!\n";
	}
}

sub writePlaceableHeader {
    my ($self,$i,$j,$k,$l,$i1) = @_;
	$self->makePlaceableHeader($i,$j,$k,$l,$i1);
	if (defined $self->{'_fhandle'}){
		my $fh = $self->{'_fhandle'};
		print $fh $self->{'_header'};
	} else {
		die "Tried to print WMF header to a non-existent file handle!\n";
	}
}

sub finalise {
	my ($self) = @_;
	$self->deleteObjects();	# clean up undeleted GDI objects
	$self->metaRecord(0,0);
}

sub toByte {
	my ($self, $byte) = @_;
	$byte = unpack("C*", $byte);
	return($byte);
}

sub loWord {
    my ($self, $word) = @_;
	return ($word & 0xFFFF)
}

sub hiWord {
    my ($self, $word) = @_;
	return ($word & 0xFFFF0000) >> 16;
}

sub writeWord {
	my ($self, $int) = @_;
	$self->outputWord($int);
}

sub writeHeaderWord {
	my ($self, $int) = @_;
	$self->outputHeaderWord($int);
}

sub outputWord {
	my ($self, $int) = @_;
	$self->{'_wmf'} .= pack ("C",  ($int & 0xFF));
	$self->{'_wmf'} .= pack ("C", (($int & 0xFF00)>>8));
}

sub outputHeaderWord {
	my ($self, $int) = @_;
	$self->{'_header'} .= pack ("C",  ($int & 0xFF));
	$self->{'_header'} .= pack ("C", (($int & 0xFF00)>>8));
}

sub outputInteger {
	my ($self, $int) = @_;
	$self->outputWord($self->loWord($int));
	$self->outputWord($self->hiWord($int));
}

sub outputHeaderInteger {
	my ($self, $int) = @_;
	$self->outputHeaderWord($self->loWord($int));
	$self->outputHeaderWord($self->hiWord($int));
}

sub writeInteger {
	my ($self, $int) = @_;
	$self->writeWord($self->loWord($int));
	$self->writeWord($self->hiWord($int));
}

sub writeHeaderInteger {
	my ($self, $int) = @_;
	$self->writeHeaderWord($self->loWord($int));
	$self->writeHeaderWord($self->hiWord($int));
}

sub wmf {
	my ($self, $x, $y, $resolution) = @_;
	# $resolution is number of metafile units per inch (optional argument)
	if (defined $resolution){
		$self->makePlaceableHeader(0,0,$x,$y,$resolution);
	} else {
		$self->makePlaceableHeader(0,0,$x,$y,96);	
	}
	return($self->{'_header'} . $self->{'_wmf'});
}

sub createFile {
    my ($self, $filename) = @_;
    if ($filename) {
        $self->{'_filename'} =  $filename;
		open  (OUT, ">$filename") or die "Cannot open WMF file: $!\n";
		$self->{'_fhandle'} = \*OUT;
    } elsif (defined $self->{'_filename'}){
        my $filename = $self->{'_filename'};
		open  (OUT, ">$filename") or die "Cannot open WMF file: $!\n";	
		$self->{'_fhandle'} = \*OUT;
	} else {
		die "Trying to open a file with no name!\n";
	}
	
    return $self->{'_fhandle'};
}

sub closeFile {
    my ($self, $filename) = @_;
    if ($filename eq $self->{'_filename'}) {
		close($self->{'_fhandle'});
		$self->{'_fhandle'} = undef;
    	return 1;
    }
}


1;


package Matrix;
use strict;

sub new {
    my ($class, $xdimension, $ydimension, $coords) = @_;
    $coords ||= [[]];

    my $self = {
	'x'      => $xdimension,
	'y'      => $ydimension,
	'coords' => $coords,
    };

    bless($self, $class);
    return $self;
}

sub coords {
    my ($this, $x, $y, $val) = @_;
    $y ||= 0;
    $x ||= 0;
    @{@{$this->{'coords'}}[$x]}[$y] = $val if(defined $val);

    return @{@{$this->{'coords'}}[$x]}[$y];
}

sub dump {
    my ($this) = @_;
    print STDERR qq(matrix dump: [), $this->{'x'}, qq(, ), $this->{'y'}, qq(]\n); 
    for(my $j=0;$j<$this->{'y'};$j++) {

	my $row = join(',', @{@{$this->{'coords'}}[$j]});
	print STDERR qq($row\n);
    }
}



1;

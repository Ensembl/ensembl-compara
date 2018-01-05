# Copyright [1999-2015] Wellcome Trust Sanger Institute and the EMBL-European Bioinformatics Institute
# Copyright [2016-2018] EMBL-European Bioinformatics Institute
# 
# Licensed under the Apache License, Version 2.0 (the "License");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at
# 
#      http://www.apache.org/licenses/LICENSE-2.0
# 
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.

use strict;
use warnings;

use Data::Dumper;
use Getopt::Long qw(GetOptionsFromArray);

my ( $error_size, $output_file, $help );
GetOptionsFromArray(
	    \@ARGV,
        'e|error_size=i'  => \$error_size,
        'o|output_file=s' => \$output_file,
        'h|help'          => \$help,
);

my @files = @ARGV;

print _help_text if ($help);
$error_size ||= 100;
$output_file ||= 'breakpoint_intersection.out';
die("Please pass 2 files only") unless ( scalar(@files) == 2 );

open( FH1, '<', $files[0] );
open( FH2, '<', $files[1] );

#my %breakpoints1;
#while( my $line = <FH1> ) {
#	my @spl = split(/\s+/, $line);
#	my $id = $spl[0] . ":" . $spl[1];
#	$breakpoints1{$spl[2]} = [ $spl[0], $spl[1], $spl[3] ];
#}

my %breakpoints2;
while( my $line = <FH2> ) {
	my @spl = split(/\s+/, $line);
	my $id = $spl[0] . ":" . $spl[1];
	$breakpoints2{$spl[2]} = [ $spl[0], $spl[1], $spl[3] ];
}

open( OUT, '>', $output_file );

#foreach my $start1 ( keys %breakpoints1 ) {
 while( my $line = <FH1> ) {
        chomp $line;
        my @spl = split(/\s+/, $line);
	my $start1 = $spl[2];
	my $end1 = $spl[3];
	foreach my $start2 ( $start1-$error_size..$start1+$error_size ) {
		if ( defined $breakpoints2{$start2} ){
			my $end2 = $breakpoints2{$start2}[2];

			my $end_match = 0;
			if ( $end2 > $end1-$error_size && $end2 < $end1+$error_size ){
	    		$end_match = 1;
	    	}

	    	print OUT $line;
	    	print OUT " * " if $end_match;
	    	print OUT " - " unless $end_match;
	    	print OUT $breakpoints2{$start2}[0] . "\t" . $breakpoints2{$start2}[1] . "\t" . $start2 . "\t" . $end2;
	    	print OUT "\n";

	    	delete $breakpoints2{$start2};
	    	last;
		}
	}
}

close(OUT);
close(FH1);
close(FH2);

sub _help_text {
	return <<HELP;
Description:
    Given two files of breakpoints (generated using breakpoints.pl), output a file of positions where they intersect (allowing an error size).
    Output will take the form: [breakpoint info from file 1 (4 cols)] [seperator] [breakpoint info from file 2]
    The seperator will be '-' in cases where only the start positions match. '*' denotes a match of both start and end positions.

Usage: perl breakpoint_intersection.pl <options> file1.tsv file2.tsv
	-e|error_size    # bases to allow away from start/end while still counting a match (default: 100)
	-o|output_file   path to output file (default: breakpoint_intersection.out)
	-h|help          display this help text

HELP
}

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

use Bio::EnsEMBL::Registry;
use Getopt::Long qw(GetOptionsFromArray);
use Data::Dumper;

# OPTIONS
my ( $reg_conf, $input_file, $species1, $species2, $output_file, $help );
GetOptionsFromArray(
	    \@ARGV,
        'reg_conf=s'   => \$reg_conf,
        'i|input=s'    => \$input_file,
        's1=s'         => \$species1,
        's2=s'         => \$species2,
        'o|output=s'   => \$output_file,
        'h|help'       => \$help,
);
print _help_text() if ($help);

$reg_conf ||= '/lustre/scratch109/ensembl/cc21/mouse_data/mouse_reg_livemirror.conf';
$output_file ||= 'filtered.tsv';
die("Please provide species of interest (-s1 & -s2)") unless( defined($species1) && defined($species2) );

my $registry = 'Bio::EnsEMBL::Registry';
$registry->load_all($reg_conf, 0, 0, 0, "throw_if_missing");

my $dnafrag_adaptor = $registry->get_adaptor("mice_merged", "compara", "DnaFrag");

my $genome_db_adaptor = $registry->get_adaptor("mice_merged", "compara", "GenomeDB");
my $sp1_gdb = $genome_db_adaptor->fetch_by_registry_name($species1);
my $sp2_gdb = $genome_db_adaptor->fetch_by_registry_name($species2);

my $sp1_gdb_id = $sp1_gdb->dbID;
my $sp2_gdb_id = $sp2_gdb->dbID;

die( "Could not find genome_db_id for $species1\n" ) unless ( defined $sp1_gdb_id );
die( "Could not find genome_db_id for $species2\n" ) unless ( defined $sp2_gdb_id );

open( IN, '<', $input_file );
open( OUT, '>', $output_file );

while( my $line = <IN> ){
	chomp $line;
	my @species_data = split( /\s+[*-]\s+/, $line );
	my %reshuffled;
	foreach my $s ( @species_data ){
		my @data = split(/\s+/, $s);
		my $dnafrag_id = $data[1];
		my $dnafrag = $dnafrag_adaptor->fetch_by_dbID( $dnafrag_id );
		if ( $dnafrag->genome_db_id == $sp1_gdb_id ){
			$reshuffled{$species1} = [ $dnafrag->slice->seq_region_name, $data[2], $data[3], $dnafrag->coord_system_name, $data[0], $data[1] ];
		}
		if ( $dnafrag->genome_db_id == $sp2_gdb_id ){
			$reshuffled{$species2} = [ $dnafrag->slice->seq_region_name, $data[2], $data[3], $dnafrag->coord_system_name, $data[0], $data[1] ];
		}
	}
	if ( defined $reshuffled{$species1} && defined $reshuffled{$species2} ){
		my $sep = _find_seperator( $reshuffled{$species1}, $reshuffled{$species2} );
		print OUT join("\t", @{$reshuffled{$species1}}) . $sep . join("\t", @{$reshuffled{$species2}}) . "\n";
	}
}

close(IN);
close(OUT);

sub _find_seperator {
	my ($s1, $s2) = @_;
	my $end1 = @$s1[2];
	my $end2 = @$s2[2];

	return ' * ' if ( abs( $end1-$end2 ) <= 100 );
	return ' - ';
}

sub _help_text {
	return <<HELP;
Description: rearrange columns and limit output to two species of interest. (For use on breakpoint_intersection.pl output)

Usage: perl format_output.pl <options>
	-reg_conf  registry config file (default: /lustre/scratch109/ensembl/cc21/mouse_data/mouse_reg_livemirror.conf)
    -i|input   input file
    -s1        species 1
    -s2        species 2
    -o|output  output file
    -h|help    display this help text

HELP
}
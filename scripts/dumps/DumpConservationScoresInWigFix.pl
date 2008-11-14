#!/usr/bin/perl -w

use strict;
use Data::Dumper;
use Bio::EnsEMBL::Registry;
use Bio::EnsEMBL::Utils::Exception qw(throw);
use Getopt::Long;

my $reg = "Bio::EnsEMBL::Registry";
my $species = "Homo sapiens";
my $conservation_scores_mlssid = 50007;
my $chunk_size = 500000;
my $db_host = "ens-livemirror";
my $db_user = "ensro";
my $seq_region_data;
my $out_dir = $ENV{PWD};


eval{
	GetOptions(
        	"species=s" => \$species,
		"conservation_scores_mlssid=s" => \$conservation_scores_mlssid,
		"chunk_size=s" => \$chunk_size,
		"db_host=s" => \$db_host,
		"db_user=s" => \$db_user,
		"seq_region_data=s" => \$seq_region_data,
		"out_dir=s" => \$out_dir,
	) or die;
};

if($@) {
	&help, die $@;
}

sub help {
	print STDERR '--db_host <ens-livemirror> --db_user <ensro> --species <"Homo sapiens"> --conservation_scores_mlssid <50007> --chunk_size <500000> --out_dir <defaulf is $PWD>', "\n";
};

$reg->load_registry_from_db(
      -host => $db_host,
      -user => $db_user,
#-db_version => "51",
);

my $mlss_adaptor = $reg->get_adaptor("Multi", "compara", "MethodLinkSpeciesSet");
my $mlss = $mlss_adaptor->fetch_by_dbID($conservation_scores_mlssid);
my $slice_adaptor = $reg->get_adaptor($species, 'core', 'Slice');
throw("Registry configuration file has no data for connecting to <$species>") if (!$slice_adaptor);
my $seq_regions = $slice_adaptor->fetch_all('toplevel');

if(!$seq_region_data) {
	my $species_dir = $species;
	$species_dir=~s/ /_/g;
	mkdir("$out_dir/$species_dir") or die "could not make dir $out_dir/$species_dir\n";
	foreach my $seq_region(@$seq_regions) {
		my $job_name = $seq_region->seq_region_name;
		$seq_region_data = join("-", $seq_region->seq_region_name, $seq_region->start, $seq_region->end, $seq_region->end - $seq_region->start + 1);
		system("bsub -qlong -J$job_name -o$out_dir/$species_dir/$seq_region_data $0 --seq_region_data $seq_region_data --db_host $db_host --db_user $db_user --species \"$species\" --conservation_scores_mlssid $conservation_scores_mlssid --chunk_size $chunk_size");
	}
}

else {
	my($seq_region_name, $seq_region_start, $seq_region_end, $seq_region_length) = split("-", $seq_region_data);
	my @chunk_regions;
	my $chunck_number = int($seq_region_length / $chunk_size);
	$chunck_number += $seq_region_length % $chunk_size ? 1 : 0;
	my $chunk_start = $seq_region_start;
	for(my$j=1;$j<$chunck_number;$j++) {
		my $chunk_end = $chunk_start + $chunk_size;
		push(@chunk_regions, [ $chunk_start, $chunk_end ]);
		$chunk_start = $chunk_end; 
	}
	push(@chunk_regions, [ $chunk_start, $seq_region_end ]);
	my $score_gap_at_end_of_chunk = 0;
	my $chunk_number = 0;
	my $first_score_seen = 0;
	foreach my $chunk_region(@chunk_regions) {
		my $cs_adaptor = $reg->get_adaptor("Multi", 'compara', 'ConservationScore');
		my $display_size = $chunk_region->[1] - $chunk_region->[0] + 1;
		my $chunk_slice = $slice_adaptor->fetch_by_region('toplevel', $seq_region_name, $chunk_region->[0], $chunk_region->[1]);
		my $scores = $cs_adaptor->fetch_all_by_MethodLinkSpeciesSet_Slice($mlss, $chunk_slice, $display_size, "MAX");
		for(my$i=0;$i<@$scores;$i++) {
			if (defined $scores->[$i]->diff_score) {
				$first_score_seen = $first_score_seen == 0 ? 1 : 2; #in the unlikely case that the chunk size is set so samll that the first chunk does not contain any scores
				if($i == @$scores - 1) {
					if($chunk_number + 1 == @chunk_regions) { #if it's the last chunk and the last score, OK to print it, as there should be no isolated single scores
						printf ("%.4f\n", $scores->[$i]->diff_score);	
					}
					elsif($scores->[$i]->position > $scores->[$i-1]->position + 1) { #if the last score in the chunk is the begining of a new score-block
						$score_gap_at_end_of_chunk = 1;
					}
					last;
				}		
				elsif($i < 1) {
					if($score_gap_at_end_of_chunk || ($first_score_seen == 1)) {
						print_header($seq_region_name, $chunk_region->[0] + $scores->[$i]->position, 
							$scores->[$i]->window_size);
			  		}
					$score_gap_at_end_of_chunk = 0;
				}
				elsif($scores->[$i]->position > $scores->[$i-1]->position + 1) {
					print_header($seq_region_name, $chunk_region->[0] + $scores->[$i]->position, 
						$scores->[$i]->window_size);
				}
				printf ("%.4f\n", $scores->[$i]->diff_score);
			}	
		}
		$chunk_number++;
		$chunk_slice = undef;
		$cs_adaptor = undef;
	}
}

sub print_header {
	my($chrom_name, $position, $step) = @_;
	$position --;
	print "fixedStep chrom=$chrom_name start=$position step=$step\n";
}

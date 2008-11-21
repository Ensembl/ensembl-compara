#!/usr/bin/perl -w

use strict;
use Data::Dumper;
use Bio::EnsEMBL::Registry;
use Bio::EnsEMBL::Utils::Exception qw(throw);
use Getopt::Long;

my $reg = "Bio::EnsEMBL::Registry";
my $species = "Homo sapiens";
my $conservation_scores_mlssid = 50007;
my $chunk_size = 1000000;
my $db_host = "ens-livemirror";
my $db_user = "ensro";
my $seq_region_data;
my $out_dir = $ENV{PWD};
my $db_version;

eval{
        GetOptions(
                "species=s" => \$species,
                "conservation_scores_mlssid=s" => \$conservation_scores_mlssid,
                "chunk_size=s" => \$chunk_size,
                "db_host=s" => \$db_host,
                "db_user=s" => \$db_user,
                "seq_region_data=s" => \$seq_region_data,
                "out_dir=s" => \$out_dir,
		"db_version=s" => \$db_version,
        ) or die;
};

if($@) {
        &help, die $@;
}

sub help {
        print STDERR '--db_host <ens-livemirror> --db_user <ensro> --species <"Homo sapiens"> --conservation_scores_mlssid <50007> --chunk_size <500000> --out_dir <defaulf is $PWD> --db_version <>', "\n";
};

if ($db_version) {
	$reg->load_registry_from_db(
    	-host => $db_host,
	-user => $db_user,
	-db_version => $db_version,
	);
}
else {
	$reg->load_registry_from_db(
	-host => $db_host,
	-user => $db_user,
	);
}

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
		my $bsub_string = "bsub -qlong -J$job_name -o$out_dir/$species_dir/$seq_region_data $0 --seq_region_data $seq_region_data --db_host $db_host --db_user $db_user --species \"$species\" --conservation_scores_mlssid $conservation_scores_mlssid --chunk_size $chunk_size";
		$bsub_string .= " --db_version $db_version" if ($db_version);
                system($bsub_string);
        }
}

else {
        my($seq_region_name, $seq_region_start, $seq_region_end, $seq_region_length) = split("-", $seq_region_data);
        my @chunk_regions;
	my $chunk_number = int($seq_region_length / $chunk_size);
        $chunk_number += $seq_region_length % $chunk_size ? 1 : 0;
        my $chunk_start = $seq_region_start;
        for(my$j=1;$j<$chunk_number;$j++) {
                my $chunk_end = $chunk_start + $chunk_size;
                push(@chunk_regions, [ $chunk_start, $chunk_end ]);
                $chunk_start = $chunk_end;
        }
        push(@chunk_regions, [ $chunk_start, $seq_region_end ]);
        my $first_score_seen = 1;
	my $previous_position = 0;
        foreach my $chunk_region(@chunk_regions) {
                my $cs_adaptor = $reg->get_adaptor("Multi", 'compara', 'ConservationScore');
                my $display_size = $chunk_region->[1] - $chunk_region->[0] + 1;
                my $chunk_slice = $slice_adaptor->fetch_by_region('toplevel', $seq_region_name, $chunk_region->[0], $chunk_region->[1]);
                my $scores = $cs_adaptor->fetch_all_by_MethodLinkSpeciesSet_Slice($mlss, $chunk_slice, $display_size, "MAX");
                for(my$i=0;$i<@$scores;$i++) {
                        if (defined $scores->[$i]->diff_score) {
#				print join(":", $display_size, $i, $scores->[$i]->position, $previous_position), "  *  ";
				#the following if-elsif-else should prevent the printing of scores from overlapping genomic_align_blocks
				if ($chunk_region->[0] + $scores->[$i]->position > $previous_position && $i > 0) { 
					$previous_position = $chunk_region->[0] + $scores->[$i]->position;
				}
				elsif ($chunk_region->[0] + $scores->[$i]->position >= $previous_position && $i == 0) {}
				else { 
					next;
				}
				if ($first_score_seen) {
					print_header($seq_region_name, $chunk_region->[0] + $scores->[$i]->position,
						$scores->[$i]->window_size);
					$first_score_seen = 0;
					last if ($scores->[$i]->position == $display_size);
				}
				elsif (@$scores == 1) {
					if ($scores->[$i]->position != 1) {
						print_header($seq_region_name, $chunk_region->[0] + $scores->[$i]->position,
							$scores->[$i]->window_size);
						last if ($scores->[$i]->position == $display_size);
					}
				}
				else {
					if ($i == 0 ) {
						if ($scores->[$i]->position > 1) {
							print_header($seq_region_name, $chunk_region->[0] + $scores->[$i]->position,
								$scores->[$i]->window_size);
						}
					}
					else {
						if ($scores->[$i]->position > $scores->[$i-1]->position + 1) {
							print_header($seq_region_name, $chunk_region->[0] + $scores->[$i]->position,
								$scores->[$i]->window_size);
						}
						last if ($scores->[$i]->position == $display_size);
					}
				}
                                printf ("%.4f\n", $scores->[$i]->diff_score);
                        }
                }
                $chunk_slice = undef;
                $cs_adaptor = undef;
	}
}

sub print_header {
        my($chrom_name, $position, $step) = @_;
        $position --;
        print "fixedStep chrom=$chrom_name start=$position step=$step\n";
}


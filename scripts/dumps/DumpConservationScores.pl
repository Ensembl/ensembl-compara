#!/usr/bin/perl -w
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

=head1 CONTACT

  Please email comments or questions to the public Ensembl
  developers list at <http://lists.ensembl.org/mailman/listinfo/dev>.

  Questions may also be sent to the Ensembl help desk at
  <http://www.ensembl.org/Help/Contact>.

=head1 NAME

DumpConservationScores.pl

=head1 DESCRIPTION

   This script dumps conservation scores from an EnsEMBL Compara
   database. It writes the GERP score for each alignment position in a
   chromosome for a given species. If automatic_bsub is set, each toplevel 
   region can be submitted as a separate job to LSF.
   It currently only writes in wigFix (http://genome.ucsc.edu/goldenPath/help/wiggle.html)
   or BED (http://genome.ucsc.edu/FAQ/FAQformat.html) formats

=head1 EXAMPLES

=over

=item Dump all the conservation scores in wigFix format for all the human chromosomes for the mammalian alignment in release 66 in the current directory using one LSF job per chromosome

DumpConservationScores.pl --url mysql://anonymous@ensembldb.ensembl.org --db_version 66 
--species "Homo sapiens" --species_set_name mammals --file_prefix EPO35way --automatic_bsub 1

=item Dump conservation scores in wigFix format for human chr Y over range 2649521 to 59034049 for the mammalian alignments in release 66 in the current directory

DumpConservationScores.pl --seq_region Y --seq_region_start 2649521 --seq_region_end 59034049 
--output_file EPO35way.chrY_2649521_59034049.wigfix  --url mysql://anonymous@ensembldb.ensembl.org/66
--species "Homo sapiens" --species_set_name mammals

=back

=head1 HELP

perl DumpConservationScores.pl -h

=cut

use strict;
use warnings;
use Data::Dumper;
use Bio::EnsEMBL::Registry;
use Bio::EnsEMBL::Utils::Exception qw(throw);
use Getopt::Long;
use Pod::Usage;

my $reg = "Bio::EnsEMBL::Registry";
my $species = "Homo sapiens";
my $coord_system = "toplevel";
my $conservation_scores_mlssid;
my $conservation_scores_mlss_method_link = "GERP_CONSERVATION_SCORE";
my $conservation_scores_mlss_species_set;
my $chunk_size = 1000000;
my $db_host;
my $db_user;
my $output_dir = $ENV{PWD};
my $db_version;
my $dbname = "Multi";
my $url; #= 'mysql://anonymous@ensembldb.ensembl.org';
my $reg_conf;
my $file_prefix = "CS"; #used for creating the filename
my $help;
my $format = "wigfix";
my $seq_region_name;
my $seq_region_start;
my $seq_region_end;
my $automatic_bsub = 0;
my $bsub_options = '-qlong -R"select[mem>2500] rusage[mem=2500]" -M2500000';
my $out_filename;
my $add_seq_name_prefix = 0;
my $seq_name_prefix = "";
my $min_expected_score = 0.0;

my $num_args = @ARGV;

eval{
    GetOptions(
	       "help" => \$help,
	       "reg_conf=s" => \$reg_conf,
	       "url|db=s" => \$url,
	       "db_host=s" => \$db_host,
	       "db_user=s" => \$db_user,
	       "db_name|dbname=s" => \$dbname,
	       "db_version=s" => \$db_version,

	       "species=s" => \$species,
	       "coord_system=s" => \$coord_system,
	       "seq_region=s" => \$seq_region_name,
	       "seq_region_start=i" => \$seq_region_start,
	       "seq_region_end=i" => \$seq_region_end,

	       "mlss_id|conservation_scores_mlssid=i" => \$conservation_scores_mlssid,
	       "method_link_type=s" => \$conservation_scores_mlss_method_link,
	       "species_set_name=s" => \$conservation_scores_mlss_species_set,
	       "min_expected_score=f" => \$min_expected_score,

	       "output_dir=s" => \$output_dir,
               "output_format=s" => \$format,
	       "output_file=s" => \$out_filename,
	       "file_prefix|method_name=s" => \$file_prefix,
	       "add_seq_name_prefix" => \$add_seq_name_prefix,

	       "chunk_size=s" => \$chunk_size,
               "automatic_bsub" => \$automatic_bsub,

	      ) or die;
};


my $usage = qq{
perl dump_conservationScores_in_wigfix.pl
  Getting help"
    [--help]

  Database configuration:
    Use either:
    [--reg_conf registry_configuration_file]
      the Bio::EnsEMBL::Registry configuration file. If none given,
        the one set in ENSEMBL_REGISTRY will be used if defined, if not
        ~/.ensembl_init will be used.
    [--dbname compara_db_name]
        the name of compara DB in the registry_configuration_file or any
        of its aliases. (default = $dbname)

    or:
    [--url ensembl_db as a url]
         For example: mysql://anonymous\@ensembldb.ensembl.org

    or:
    [--db_host database_server]
         For example: ensembldb.ensembl.org
    [--db_user database user]
         For example: anonymous

    Other database options:
    --db_version version number
         EnsEMBL version number. For example: 57


  For the query slice:
    [--species query_species]
         Query species. (default is "$species")
    --seq_region region_name
        Sequence region name of the query slice, i.e. the chromosome name
    --seq_region_start start
        Query slice start (default = 1)
    --seq_region_end end
        Query slice end (default = end)
    --coord_system coordinates_name
        This option allows to dump all the alignments on all the top-level
        sequence region of a given coordinate system. It can also be used
        in conjunction with the --seq_region option to specify the right
        coordinate system. (default = $coord_system)

  For the scores:
    [--conservation_scores_mlssid method_link_species_set_id]
        Method link species set id for the conservation scores. Alternatively, you
        can specify the method_link and the species_set (see below).
    [--method_link method_link_type]
        Method link type for the conservation scores. (default "$conservation_scores_mlss_method_link")
    [--species_set species_set_name]
        Species set name for the conservation scores.
    [--min_expected_score min_score]
        Ignore GERP scores if exptected score is lower that this threshold (default = $min_expected_score)

  Output:
    --output_dir output directory
         Location of directory to write output files. Default: current directory
    --output_format output format
          Currently only wigFix and bed format are supported. (default = $format)
    --output_file filename
          File to contain conservation scores. Automatically generated in automatic_bsub mode
    --file_prefix prefix
         Text to identify which method was used to produce the scores, used only for the filename.
         (default = $file_prefix)
    --add_seq_name_prefix
         Add 'chr' to the chromosome (not supercontigs) names. (default = FALSE)

  Other options
    --chunk_size chunk_size
         Chunk size for conservation scores to be retrieved. (default $chunk_size);
    --automatic_bsub
         Automatically create jobs for all the toplevel regions for a species
    --bsub_options
         bsub options. (default = '$bsub_options')

};

#Print description and usage statements if request help
if ($help || $num_args == 0) {
    pod2usage({-exitvalue => 0, -verbose => 2});
}

#Check the format is valid
unless (lc($format) eq "wigfix" || lc($format) eq "bed") {
    print STDERR "Currently $format is not supported. Only wigFix and bed formats are supported\n";
    exit;
}

#Read in registry information and start building up a bsub_cmd for later use
#when submitting the jobs
my $bsub_cmd;
if ($reg_conf and $dbname) {
    $reg->load_all($reg_conf, 0, 0, 0, "throw_if_missing");
    $bsub_cmd .= " --reg_conf $reg_conf --dbname $dbname";
} elsif ($url) {
    if ($db_version) {
	$url .= "/$db_version";
    }
    Bio::EnsEMBL::Registry->load_registry_from_url($url);
    $bsub_cmd .= " --url $url";
} elsif ($db_host && $db_user && $db_version) {
	$reg->load_registry_from_db(
    	-host => $db_host,
	-user => $db_user,
	-db_version => $db_version,
	);
    $bsub_cmd .= " --db_host $db_host --db_user $db_user --db_version $db_version";
} elsif ($db_host && $db_user) {
	$reg->load_registry_from_db(
	-host => $db_host,
	-user => $db_user,
	);
    $bsub_cmd .= " --db_host $db_host --db_user $db_user";
}

#Check have enough arguments to read database
if (!defined $bsub_cmd) {
    throw("Incorrect arguments\n" . $usage . "\n");
}

#Read the conservation score mlss
my $mlss_adaptor = $reg->get_adaptor($dbname, "compara", "MethodLinkSpeciesSet");
my $mlss;
if ($conservation_scores_mlssid) {
    $mlss = $mlss_adaptor->fetch_by_dbID($conservation_scores_mlssid);
} elsif ($conservation_scores_mlss_method_link and $conservation_scores_mlss_species_set) {
    $mlss = $mlss_adaptor->fetch_by_method_link_type_species_set_name(
            $conservation_scores_mlss_method_link, $conservation_scores_mlss_species_set);
}

#Add on rest of arguments
if ($automatic_bsub) {
    $bsub_cmd .= " --species \"$species\" --conservation_scores_mlssid ".$mlss->dbID." --chunk_size $chunk_size --output_dir $output_dir --file_prefix $file_prefix --output_format $format --min_expected_score $min_expected_score";
}

my $slice_adaptor = $reg->get_adaptor($species, 'core', 'Slice');
throw("Registry configuration file has no data for connecting to <$species>") if (!$slice_adaptor);

#Fill in seq_regions array. Could be one item if --seq_region is defined
my $seq_regions;
if (defined $seq_region_name) {
    $seq_regions->[0] = $slice_adaptor->fetch_by_region($coord_system, $seq_region_name, $seq_region_start, $seq_region_end);
    if (!defined $seq_region_start) {
	$seq_region_start = $seq_regions->[0]->start;
    }
    if (!defined $seq_region_end) {
	$seq_region_end = $seq_regions->[0]->end;
    }
} else {
    $seq_regions = $slice_adaptor->fetch_all($coord_system);
} 

#HACK to catch toplevel regions with the same name but different ranges
#ie human chr Y
my %chr_name;
foreach my $seq_region(@$seq_regions) {
    if (!defined $chr_name{$seq_region->seq_region_name}) {
	$chr_name{$seq_region->seq_region_name} = 0;
    } else {
	$chr_name{$seq_region->seq_region_name}++;
    }
}

#Create jobs to be submitted using LSF.
if($automatic_bsub) {
    #Create a job for each toplevel region
    foreach my $seq_region(@$seq_regions) {

	my $job_name = "Dump" . $file_prefix . "_" . $seq_region->seq_region_name;
	my $seq_region_name = $seq_region->seq_region_name;
	my $seq_region_start = $seq_region->start;
	my $seq_region_end = $seq_region->end;

	#create unique name if found more than one instance of seq_region_name
	my $unique_name;
	if ($chr_name{$seq_region_name} == 0) {
	    $unique_name = $seq_region_name;
	} else {
	    $unique_name = $seq_region_name . "_" . $seq_region_start . "_" . $seq_region_end;
	}

	#Set up LSF out and err files
	my $bsub_out = "$output_dir/$file_prefix" ."." . "$unique_name" . ".out";
	my $bsub_err = "$output_dir/$file_prefix" ."." . "$unique_name" . ".err";

	#In automatic mode, must generate own filenames
	my $out_filename = $output_dir . "/" . $file_prefix . ".chr" . $unique_name . "." . $format;

	#Create final string ready for submission
	my $bsub_string = "bsub $bsub_options -J$job_name -o $bsub_out -e $bsub_err $0 --seq_region $seq_region_name --seq_region_start $seq_region_start --seq_region_end $seq_region_end --output_file $out_filename ";

	
	#add on "chr" to the beginning of chromosomes if needed
	if (($seq_region->coord_system->name eq "chromosome") &&
	    $add_seq_name_prefix) {
	    $bsub_string .= " --seq_name_prefix chr ";
	}
	$bsub_string .= $bsub_cmd;

	#print "$bsub_string\n";
	#Submit the job which calls this script with seq_region defined
	system($bsub_string);
    }
} else {
    # Write file
    foreach my $seq_region(@$seq_regions) {
	my $seq_region_name = $seq_region->seq_region_name;
	my $seq_region_start = $seq_region->start;
	my $seq_region_end = $seq_region->end;

	# Open filehandle. If no filename is defined, use STDOUT
	my $fh;
	if (!defined $out_filename) {
	    $fh =  *STDOUT;
	} else {
	    open $fh, '>'. $out_filename or throw("Error opening $out_filename for write");
	}

	# Print scores in defined format to filehandle
	if (lc($format) eq "wigfix") {
	    write_wigFix($fh, $seq_region_name, $seq_region_start, $seq_region_end);
	} elsif (lc($format) eq "bed") {
	    write_bed($fh, $seq_region_name, $seq_region_start, $seq_region_end);
	}

	# Close filehandle. If file is empty, delete.
	if (!defined $out_filename) {
	    $fh =  *STDOUT;
	} else {
	    close($fh) or die "Couldn't close file properly";
	    if (-s $out_filename == 0) {
		print STDERR "$out_filename is empty. Deleting \n";
		unlink($out_filename);
	    } 
	}
    }
}

#Write scores in wigFix format
sub write_wigFix {
    my ($fh, $seq_region_name, $seq_region_start, $seq_region_end) = @_;

    #Chunk seq_region to speed up score retrieval
    my $chunk_regions = chunk_region($seq_region_start, $seq_region_end, $chunk_size);

    my $first_score_seen = 1;
    my $previous_position = 0;
    
    my $cs_adaptor = $reg->get_adaptor($dbname, 'compara', 'ConservationScore');
    foreach my $chunk_region(@$chunk_regions) {
	my $display_size = $chunk_region->[1] - $chunk_region->[0] + 1;

	my $chunk_slice = $slice_adaptor->fetch_by_region('toplevel', $seq_region_name, $chunk_region->[0], $chunk_region->[1]);

	#Get scores
	my $scores = $cs_adaptor->fetch_all_by_MethodLinkSpeciesSet_Slice($mlss, $chunk_slice, $display_size, "AVERAGE");
	my $found_min_score = 0;
	for(my$i=0;$i<@$scores;$i++) {
#	    if (defined $scores->[$i]->diff_score and $scores->[$i]->expected_score >= $min_expected_score) {
	    if (defined $scores->[$i]->diff_score) {

		#Do not print scores when the expected_score is below min_expected_score. Must print
		#a new header when find a score above the $min_expected_score since all scores below a 
		#header must be consecutive.
		if ($found_min_score && $scores->[$i]->expected_score >= $min_expected_score) {
		    print_wigFix_header($fh, $seq_region_name, 
					$chunk_region->[0] + $scores->[$i]->position, 
					$scores->[$i]->window_size);
		    $found_min_score = 0;
		} elsif ($scores->[$i]->expected_score < $min_expected_score) {
		    $found_min_score = 1;
		    #Skip printing the score
		    next;
		}

		#the following if-elsif-else should prevent the printing of scores from overlapping genomic_align_blocks
		if ($chunk_region->[0] + $scores->[$i]->position > $previous_position && $i > 0) { 
		    $previous_position = $chunk_region->[0] + $scores->[$i]->position;
		} elsif ($chunk_region->[0] + $scores->[$i]->position >= $previous_position && $i == 0) {
		} else { 
		    next;
		}
		if ($first_score_seen) {
		    print_wigFix_header($fh, $seq_region_name, 
					$chunk_region->[0] + $scores->[$i]->position,
					$scores->[$i]->window_size);
		    $first_score_seen = 0;
		    last if ($scores->[$i]->position == $display_size);
		} elsif (@$scores == 1) {
		    if ($scores->[$i]->position != 1) {
			print_wigFix_header($fh, $seq_region_name, 
					    $chunk_region->[0] + $scores->[$i]->position,
					    $scores->[$i]->window_size);
			last if ($scores->[$i]->position == $display_size);
		    }
		} else {
		    if ($i == 0 ) {
			if ($scores->[$i]->position > 1) {
			    print_wigFix_header($fh, $seq_region_name, 
						$chunk_region->[0] + $scores->[$i]->position, 
						$scores->[$i]->window_size);
			}
		    } else {
			if ($scores->[$i]->position > $scores->[$i-1]->position + 1) {
			    print_wigFix_header($fh, $seq_region_name, 
						$chunk_region->[0] + $scores->[$i]->position,
						$scores->[$i]->window_size);
			}
			last if ($scores->[$i]->position == $display_size);
		    }
		}
		printf $fh ("%.4f\n", $scores->[$i]->diff_score);
#		printf $fh ("%.4f %.4f\n", $scores->[$i]->expected_score, $scores->[$i]->diff_score);
		#printf $fh "%d %.4f\n", ($scores->[$i]->position+$chunk_region->[0]), $scores->[$i]->diff_score;
	    }
	}
    }
}

#Print header
sub print_wigFix_header {
        my($fh, $chrom_name, $position, $step) = @_;
        $position--;
        print $fh "fixedStep chrom=$chrom_name start=$position step=$step\n";
}


#Write scores in bed format
sub write_bed {
    my ($fh, $seq_region_name, $seq_region_start, $seq_region_end) = @_;

    #Chunk seq_region to speed up score retrieval
    my $chunk_regions = chunk_region($seq_region_start, $seq_region_end, $chunk_size);

    # my $first_score_seen = 1;
    my $previous_position = 0;
    
    my $cs_adaptor = $reg->get_adaptor($dbname, 'compara', 'ConservationScore');
    foreach my $chunk_region(@$chunk_regions) {
	my $display_size = $chunk_region->[1] - $chunk_region->[0] + 1;
	my $chunk_slice = $slice_adaptor->fetch_by_region('toplevel', $seq_region_name, $chunk_region->[0], $chunk_region->[1]);

	#Add prefix to name if required
	my $name = $seq_region_name;
	if ($seq_name_prefix ne "") {
	    $name = $seq_name_prefix . $seq_region_name;
	}
	
	#Get scores
	my $scores = $cs_adaptor->fetch_all_by_MethodLinkSpeciesSet_Slice($mlss, $chunk_slice, $display_size, "AVERAGE");
	for(my$i=0;$i<@$scores;$i++) {
	    if (defined $scores->[$i]->diff_score) {
		#the following if-elsif-else should prevent the printing of scores from overlapping genomic_align_blocks
		if ($chunk_region->[0] + $scores->[$i]->position > $previous_position && $i > 0) { 
		    $previous_position = $chunk_region->[0] + $scores->[$i]->position;
		} elsif ($chunk_region->[0] + $scores->[$i]->position >= $previous_position && $i == 0) {
		} else { 
		    next;
		}

		my $pos = $chunk_region->[0] + $scores->[$i]->position - 1;
		#bed coords are 0 based
		printf $fh ("%s\t%d\t%d\t%.4f\n", $name, $pos-1, $pos, $scores->[$i]->diff_score);
	    }
	}
    }
}

sub chunk_region {
    my ($seq_region_start, $seq_region_end, $chunk_size) = @_;
    my $chunk_regions = [];

    my $seq_region_length = ($seq_region_end-$seq_region_start+1);

    my $chunk_number = int($seq_region_length / $chunk_size);
    $chunk_number += $seq_region_length % $chunk_size ? 1 : 0;
    my $chunk_start = $seq_region_start;
    for(my$j=1;$j<$chunk_number;$j++) {
	my $chunk_end = $chunk_start + $chunk_size;
	push(@$chunk_regions, [ $chunk_start, $chunk_end ]);
	$chunk_start = $chunk_end;
    }

    push(@$chunk_regions, [ $chunk_start, $seq_region_end ]);

    return $chunk_regions;
}


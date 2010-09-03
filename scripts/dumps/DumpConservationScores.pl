#!/usr/bin/perl -w
my $description = q{

###########################################################################
##
## PROGRAM DumpConservationScores.pl
##
## AUTHORS
##    Stephen Fitzgerald (stephenf@ebi.ac.uk)
##    Kathryn Beal (kbeal@ebi.ac.uk)
##
## COPYRIGHT
##    This modules is part of the Ensembl project http://www.ensembl.org
##
## DESCRIPTION
##    This script dumps conservation scores from an EnsEMBL Compara
##    database. It writes the GERP score for each alignment position in a
##    chromosome for a given species. If automatic_bsub is set, each toplevel 
##    region can be submitted as a separate job to LSF.
##    It currently only writes in wigFix and bed format
##    http://genome.ucsc.edu/goldenPath/help/wiggle.html
##
###########################################################################
};

=head1 NAME

DumpConservationScores.pl

=head1 AUTHORS

  Stephen Fitzgerald (stephenf@ebi.ac.uk)
  Kathryn Beal (kbeal@ebi.ac.uk)

=head1 COPYRIGHT

This modules is part of the Ensembl project http://www.ensembl.org

=head1 DESCRIPTION

   This script dumps conservation scores from an EnsEMBL Compara
   database. It writes the GERP score for each alignment position in a
   chromosome for a given species. If automatic_bsub is set, each toplevel 
   region can be submitted as a separate job to LSF.
   It currently only writes in wigFix format
   http://genome.ucsc.edu/goldenPath/help/wiggle.html

=head1 SYNOPSIS

DumpConservationScores.pl --db mysql://anonymous@ensembldb.ensembl.org --db_version 56 --species "Homo sapiens" --conservation_scores_mlssid 50010 --chunk_size 500000 --method_name EPO31way --automatic_bsub 1

perl DumpConservationScores.pl 
    --db compara_db url
    --db_host compara_db host
    --db_user compara_db user
    --reg_conf registry_configuration_file
    --dbname compara_db_name
    --db_version ensembl version
    [--species species]
    --coord_system coordinates_name
    --seq_region region_name
    --seq_region_start start
    --seq_region_end end
    [--conservation_scores_mlssid method_link_species_set_id]
    --chunk_size 1000000
    --output_dir directory
    --output_format wigfix
    --output_file filename
    --method_name name
    --automatic_bsub

=head1 OPTIONS

=head2 GETTING HELP

=over

=item B<[--help]>

  Prints help message and exits.

=back

=head2 GENERAL CONFIGURATION

=over

To define which database and server to use, you must use either [--db] OR [--reg_conf] with [--dbname] OR [db_host] with [db_user]

=item B<--db mysql://user[:passwd]@host[:port]>

The script will auto-configure the Registry using the
databases in this MySQL instance. For example:
mysql://anonymous@ensembldb.ensembl.org

=item B<--db_host compara_db host>

Alternative way to [--db] of specifying the host. For example: ensembldb.ensembl.org

=item B<--db_user compara_db user>

Alternative way to [--db] of specifying the user. For example: anonymous

=item B<--reg_conf registry_configuration_file>

If you are using a non-standard setting, you can specify a
Bio::EnsEMBL::Registry configuration file to create the
appropriate connections to the databases.

=item B<--dbname compara_db_name>

The name of compara DB in the registry_configuration_file or any
of its aliases. Uses "Multi" by default.

=item B<--db_version ensembl_version>

Specify the ensembl version. Default to current version of API

=item B<--automatic_bsub>

First create a list of jobs to be submitted to LSF which will run this script with seq_region set. Useful when wanting to dump all conservation scores for all chromosomes for a species. Default off.

=back

=head2 SPECIFYING THE QUERY SLICE

=over

=item B<[--species species]>

Query species.

=item B<--coord_system coordinates_name>

This option allows to dump all the alignments on this coordinate system. Recommended to be used with automatic_bsub. Default toplevel.

=item B<--seq_region region_name>

Query region name, i.e. the chromosome name

=item B<--seq_region_start start>

Query region start

=item B<--seq_region_end end>

Query region end

=back

=head2 SPECIFYING THE ALIGNMENT 

=over

=item B<[--conservation_scores_mlssid method_link_species_set_id]>

The method_link_species_set_id for the GERP_CONSERVATION_SCORE

=item B<--chunk_size chunk_size>

Size of chunks of scores to fetch in one go

=back

=head2 OUTPUT

=over

=item B<--output_format wigfix>

The type of output you want. Currently only wigFix format is supported. See
http://genome.ucsc.edu/goldenPath/help/wiggle.html

=item B<--output_file filename>

The name of the output file. Not used in automatic_bsub mode, where a filename will be created based on the output_dir, method_name and seq_region_name. Default STDOUT.

=item B<--output_dir directory>

The name of the directory to write the files to. It must exist.

=item B<--method_name name>

Method name used to create automatic output filenames in automatic_bsub mode.

=back

=head1 EXAMPLES

=over

=item Dump all the conservation scores in wigFix format for all the human chromosomes for the EPO 31 species alignment in release 56 in the current directory 

DumpConservationScores.pl --db mysql://anonymous@ensembldb.ensembl.org --db_version 56 
--species "Homo sapiens" --conservation_scores_mlssid 50010 --chunk_size 500000 
--method_name EPO31way --automatic_bsub 1

=item Dump conservation scores in wigFix format for human chr Y over range 2649521 to 59034049 for the EPO 31 species alignments in release 56 in the current directory

DumpConservationScores.pl --seq_region Y --seq_region_start 2649521 --seq_region_end 59034049 
--output_file EPO31way.chrY_2649521_59034049.wigfix  --db mysql://anonymous@ensembldb.ensembl.org/56 
--species "Homo sapiens" --conservation_scores_mlssid 50010 --chunk_size 500000 

=cut

use strict;
use Data::Dumper;
use Bio::EnsEMBL::Registry;
use Bio::EnsEMBL::Utils::Exception qw(throw);
use Getopt::Long;

my $reg = "Bio::EnsEMBL::Registry";
my $species = "Homo sapiens";
my $coord_system = "toplevel";
my $conservation_scores_mlssid;
my $chunk_size = 1000000;
my $db_host;
my $db_user;
my $output_dir = $ENV{PWD};
my $db_version;
my $dbname = "Multi";
my $db; #= 'mysql://anonymous@ensembldb.ensembl.org';
my $reg_conf;
my $method_name = "CS"; #used for creating the filename
my $help;
my $format = "wigfix";
my $seq_region_name;
my $seq_region_start;
my $seq_region_end;
my $automatic_bsub = 0;
my $out_filename;
my $add_seq_name_prefix = 0;
my $seq_name_prefix = "";

my $num_args = @ARGV;

eval{
    GetOptions(
	       "help" => \$help,
	       "db=s" => \$db,
	       "db_host=s" => \$db_host,
	       "db_user=s" => \$db_user,
	       "reg_conf=s" => \$reg_conf,
	       "dbname=s" => \$dbname,
	       "db_version=s" => \$db_version,
               "automatic_bsub" => \$automatic_bsub,
	       "species=s" => \$species,
	       "coord_system=s" => \$coord_system,
	       "seq_region=s" => \$seq_region_name,
	       "seq_region_start=i" => \$seq_region_start,
	       "seq_region_end=i" => \$seq_region_end,
	       "conservation_scores_mlssid=i" => \$conservation_scores_mlssid,
	       "chunk_size=s" => \$chunk_size,
	       "output_dir=s" => \$output_dir,
               "output_format=s" => \$format,
	       "output_file=s" => \$out_filename,
	       "method_name=s" => \$method_name,
	       "add_seq_name_prefix" => \$add_seq_name_prefix,
	       "seq_name_prefix=s" => \$seq_name_prefix,
	      ) or die;
};


my $usage = qq{
perl dump_conservationScores_in_wigfix.pl
  Getting help"
    [--help]

  General configuration:
    Use either:
    [--reg_conf registry_configuration_file]
      the Bio::EnsEMBL::Registry configuration file. If none given,
        the one set in ENSEMBL_REGISTRY will be used if defined, if not
        ~/.ensembl_init will be used.
    [--dbname compara_db_name]
        the name of compara DB in the registry_configuration_file or any
        of its aliases.
    or:
    [--db compara_db as a url]
         For example: mysql://anonymous\@ensembldb.ensembl.org

    or:
    [--db_host database_server]
         For example: ensembldb.ensembl.org
    [--db_user database user]
         For example: anonymous

    --db_version version number
         EnsEMBL version number. For example: 57
    --automatic_bsub
         Automatically create jobs for all the toplevel regions for a species

    For the query slice:
    [--species query_species]
         Query species. Default is human
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
        coordinate system.

    For the scores:
    [--conservation_scores_mlssid method_link_species_set_id]
        Method link species set id for the conservation scores 
    --chunk_size chunk_size
         Chunk size for conservation scores to be retrieved. Default 1000000;

    Output:
    --output_dir output directory
         Location of directory to write output files. Default: current directory
    --output_format output format
          Currently only wigFix and bed format are supported
    --output_file filename
          File to contain conservation scores. Automatically generated in auotmatic_bsub mode
    --method_name method_name
         Text to identify which method was used to produce the scores, used only for the filename. For example EPO_33way
};

#Print description and usage statements if request help
if ($help || $num_args == 0) {
    print $description, $usage;
    exit(0);
}

#Check the format is valid
unless (lc($format) eq "wigfix" || lc($format) eq "bed") {
    print STDERR "Currently $format is not supported. Only wigFix format is supported\n";
    exit;
}

#Read in registry information and start building up a bsub_cmd for later use
#when submitting the jobs
my $bsub_cmd;
if ($reg_conf) {
    $reg->load_all($reg_conf);
    $bsub_cmd .= " --reg_conf $reg_conf --dbname $dbname";
} elsif ($db) {
    if ($db_version) {
	$db .= "/$db_version";
    }
    Bio::EnsEMBL::Registry->load_registry_from_url($db);
    $bsub_cmd .= " --db $db";
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

#Add on rest of arguments
if ($automatic_bsub) {
    $bsub_cmd .= " --species \"$species\" --conservation_scores_mlssid $conservation_scores_mlssid --chunk_size $chunk_size --output_dir $output_dir --method_name $method_name --output_format $format";

}

#Read the conservation score mlss
my $mlss_adaptor = $reg->get_adaptor($dbname, "compara", "MethodLinkSpeciesSet");
my $mlss = $mlss_adaptor->fetch_by_dbID($conservation_scores_mlssid);
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

	my $job_name = "Dump" . $method_name . "_" . $seq_region->seq_region_name;
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
	my $bsub_out = "$output_dir/$method_name" ."." . "$unique_name" . ".out";
	my $bsub_err = "$output_dir/$method_name" ."." . "$unique_name" . ".err";

	#In automatic mode, must generate own filenames
	my $out_filename = $output_dir . "/" . $method_name . ".chr" . $unique_name . "." . $format;

	#Create final string ready for submission
	my $bsub_string = "bsub -qlong -J$job_name -o $bsub_out -e $bsub_err $0 --seq_region $seq_region_name --seq_region_start $seq_region_start --seq_region_end $seq_region_end --output_file $out_filename ";

	
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
    #Write file
    foreach my $seq_region(@$seq_regions) {
	my $seq_region_name = $seq_region->seq_region_name;
	my $seq_region_start = $seq_region->start;
	my $seq_region_end = $seq_region->end;
	if (lc($format) eq "wigfix") {
	    write_wigFix($species, $seq_region_name, $seq_region_start, $seq_region_end, $output_dir, $method_name);
	} elsif (lc($format) eq "bed") {
	    write_bed($species, $seq_region_name, $seq_region_start, $seq_region_end, $output_dir, $method_name);
	}
    }
}

#Write scores in wigFix format
sub write_wigFix {
    my ($species, $seq_region_name, $seq_region_start, $seq_region_end, $output_dir, $method_name) = @_;

    my $seq_region_length = ($seq_region_end-$seq_region_start+1);

    #Open filehandle. If no filename is defined, use STDOUT
    my $fh;
    if (!defined $out_filename) {
	$fh =  *STDOUT;
    } else {
	open $fh, '>'. $out_filename or throw("Error opening $out_filename for write");
    }

    #Chunk seq_region to speed up score retrieval
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
    
    my $cs_adaptor = $reg->get_adaptor($dbname, 'compara', 'ConservationScore');
    foreach my $chunk_region(@chunk_regions) {
	my $display_size = $chunk_region->[1] - $chunk_region->[0] + 1;
	my $chunk_slice = $slice_adaptor->fetch_by_region('toplevel', $seq_region_name, $chunk_region->[0], $chunk_region->[1]);

	#Get scores
	my $scores = $cs_adaptor->fetch_all_by_MethodLinkSpeciesSet_Slice($mlss, $chunk_slice, $display_size, "AVERAGE");
	for(my$i=0;$i<@$scores;$i++) {
	    my $line = "";
	    if (defined $scores->[$i]->diff_score) {
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
		#printf $fh "%d %.4f\n", ($scores->[$i]->position+$chunk_region->[0]), $scores->[$i]->diff_score;
	    }
	}
    }
    close($fh) or die "Couldn't close file properly";

    #Remove empty files.
    if (defined $out_filename && -s $out_filename == 0) {
	print STDERR "$out_filename is empty. Deleting \n";
	unlink($out_filename);
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
    my ($species, $seq_region_name, $seq_region_start, $seq_region_end, $output_dir, $method_name) = @_;

    my $seq_region_length = ($seq_region_end-$seq_region_start+1);

    #Open filehandle. If no filename is defined, use STDOUT
    my $fh;
    if (!defined $out_filename) {
	$fh =  *STDOUT;
    } else {
	open $fh, '>'. $out_filename or throw("Error opening $out_filename for write");
    }

    #Chunk seq_region to speed up score retrieval
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
    
    my $cs_adaptor = $reg->get_adaptor($dbname, 'compara', 'ConservationScore');
    foreach my $chunk_region(@chunk_regions) {
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
	    my $line = "";
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
    close($fh) or die "Couldn't close file properly";

    #Remove empty files.
    if (defined $out_filename && -s $out_filename == 0) {
	print STDERR "$out_filename is empty. Deleting \n";
	unlink($out_filename);
    } 

}

#!/usr/local/ensembl/bin/perl -w

use strict;

my $description = q{
###########################################################################
##
## PROGRAM run_BLAT_pipeline.pl
##
## AUTHORS
##    Javier Herrero (jherrero@ebi.ac.uk)
##
## COPYRIGHT
##    This script is part of the Ensembl project http://www.ensembl.org
##
## DESCRIPTION
##    This script runs the BLAT pipeline
##
###########################################################################

};

=head1 NAME

run_BLAT_pipeline.pl

=head1 AUTHORS

 Javier Herrero (jherrero@ebi.ac.uk)

=head1 COPYRIGHT

This script is part of the Ensembl project http://www.ensembl.org

=head1 DESCRIPTION

This script runs the BLAT pipeline, based on documentation written
by Cara Woodwark.

=head1 SYNOPSIS

perl run_BLAT_pipeline.pl --help

perl run_BLAT_pipeline.pl --species1 fly --species2 honeybee

=head1 ARGUMENTS

=head2 GETTING HELP

=over

=item B<[--help]>

  Prints help message and exits.

=back

=head2 GENERAL CONFIGURATION

=over

=item B<[--reg_conf registry_configuration_file]>

the Bio::EnsEMBL::Registry configuration file. If none given,
the one set in ENSEMBL_REGISTRY will be used if defined, if not
~/.ensembl_init will be used.

=item B<[--compara_cvs installation_directory]>

This defines the path to the root of the ensembl-compara CVS
copy to be used.

Default is "/nfs/acari/jh7/src/ensembl_main/ensembl-compara"

=item B<[--base_dir main_dir_for_results]>

This defines the path to store all the results

Default is "/ecs4/work1/jh7/BLAT"
  
=item B<[--queue queue_name]>

You can specify the queue you want to use.

Default is "normal".
  
=back

=head2 SEQUENCES TO BE COMPARED

=over

=item B<--species1 species_registry_name>

This is the name of the consensus species or any of its aliases

=item B<--species2 species_registry_name>

This is the name of the quey species or any of its aliases
    
=item B<[--chr1 list_of_chromosomes]>

You can limit the comparisons to on or several chromosomes.
The chromosome names must be separed by colons (:). For
instance if you want to use chromosomes 1 and 3 only you can
specify "--chr1 1:3"

=item B<[--chr2 list_of_chromosomes]>

The same for the query species.

=item B<[--overlap overlap_size]>

Default is 1000

=item B<[--chunk_size chunk_size]>

Default is 100000

=item B<[--masked mask_option]>

Default is 2 (soft-masking)

=back


=head1 APPENDIX

The rest of the documentation details each of the methods.

=cut

use Bio::EnsEMBL::Registry;
use Bio::EnsEMBL::Utils::Exception qw(throw warning);
use Bio::EnsEMBL::Pipeline::Runnable::Blat;
use IPC::Open2;
use Getopt::Long;

my $usage = qq{
perl run_BLAT_pipeline.pl
  Getting help:
    [--help]
  
  General configuration:
    [--reg_conf registry_configuration_file]
        the Bio::EnsEMBL::Registry configuration file. If none given,
        the one set in ENSEMBL_REGISTRY will be used if defined, if not
        ~/.ensembl_init will be used.

    [--compara_cvs installation_directory]
        This defines the path to the root of the ensembl-compara CVS
        copy to be used.
        Default is "/nfs/acari/jh7/src/ensembl_main/ensembl-compara"

    [--base_dir main_dir_for_results]
        This defines the path to store all the results
        Default is "/ecs4/work1/jh7/BLAT"
  
    [--queue queue_name]
        You can specify the queue you want to use.
        Default is "normal".
  
  Sequences to be compared:
    --species1 species_registry_name
        This is the name of the consensus species or any of its aliases

    --species2 species_registry_name
        This is the name of the quey species or any of its aliases
    
    [--chr1 list_of_chromosomes]
        You can limit the comparisons to on or several chromosomes.
        The chromosome names must be separed by colons (:). For
        instance if you want to use chromosomes 1 and 3 only you can
        specify "--chr1 1:3"

    [--chr2 list_of_chromosomes]
        The same for the query species.

    [--overlap overlap_size]
        Default is 1000

    [--chunk_size chunk_size]
        Default is 100000

    [--masked mask_option]
        Default is 2 (soft-masking)
};

my $help;

my $reg_conf;
my $compara_cvs = "/nfs/acari/jh7/src/ensembl_main/ensembl-compara";

## This is intended for clumping sequences when they are in thousands of
## files but it has not been implemented yet...
my $coord_systems = {
        "chromosome" => "separate_files",
        "group" => "separate_files",
        "supercontig" => "clump_files",
        "scaffold" => "clump_files",
    };

my $base_dir = "/ecs4/work1/jh7/BLAT";
my $species1;
my $species2;
my $chr1;
my $chr2;

my $queue = "normal";

my $overlap = 1000;
my $chunk_size = 100000;
my $masked = 2;

GetOptions(
    "help" => \$help,
    "reg_conf=s" => \$reg_conf,
    "compara_cvs=s" => \$compara_cvs,

    "base_dir=s" => \$base_dir,
    "species1=s" => \$species1,
    "species2=s" => \$species2,
    "chr1=s"     => \$chr1,
    "chr2=s"     => \$chr2,
  
    "queue=s" => \$queue,
  
    "overlap=i" => \$overlap,
    "chunk_size=i" => \$chunk_size,
    "masked=i" => \$masked,
  );

# Print Help and exit if help is requested
if ($help) {
  print $description, $usage;
  exit(0);
}

##
## Configure the Bio::EnsEMBL::Registry
## Uses $reg_conf if supllied. Uses ENV{ENSMEBL_REGISTRY} instead if defined. Uses
## ~/.ensembl_init if all the previous fail.
##
Bio::EnsEMBL::Registry->load_all($reg_conf);

my $BIN_DIR = "$base_dir/bin";
my $DNA_DIR = "$base_dir/dna";
my $RUN_DIR = "$base_dir/run";
my $LOG_DIR = "$base_dir/log";

$| = 1; # Autoflush LOG
open(LOG, ">>$LOG_DIR/${species1}_$species2--".((localtime)[5]+1900)."-".((localtime)[4]+1));
select(LOG);
$| = 1; # Autoflush LOG
open(STDOUT, ">&LOG");
open(STDERR, ">&LOG");
print LOG "
######################################################################
######################################################################
  START: ", scalar(localtime()), "
######################################################################
";

foreach my $directory ($base_dir, $BIN_DIR, $DNA_DIR, $RUN_DIR) {
  if (!-e $directory) {
    mkdir("$directory")
        or throw("Directory $directory does not exist and cannot be created");
  }
}

foreach my $script (
        "$compara_cvs/scripts/dumps/DumpChromosomeFragments.pl",
        "$compara_cvs/scripts/BLAT/LaunchBLAT.pl",
        "$compara_cvs/scripts/BLAT/fastafetch.pl",
        "$compara_cvs/scripts/BLAT/parse_and_score.pl",
    ) {
  qx"cp -f $script $base_dir/bin";
}

# parse chr strings
my $seq_regions1;
$seq_regions1 = [split(":", $chr1)] if (defined($chr1));
my $seq_regions2;
$seq_regions2 = [split(":", $chr2)] if (defined($chr2));

my $species1_directory = make_species_directory($base_dir, $species1);
my $species2_directory = make_species_directory($base_dir, $species2);

dump_dna($base_dir, $species1, $species1_directory, $seq_regions1);
dump_dna($base_dir, $species2, $species2_directory, $seq_regions2);

my $results_dir = launch_BLAT($species1_directory, $species2_directory);

exit(0);


=head2 make_species_directory

  Arg[1]      : string $base_dir
  Arg[2]      : string $species_name
  Example     : make_species_directory("/usr/local/data", "human");
  Description : Creates a directory called as the species_name into the
                base directory
  Returntype  : string species_directory_name
  Exceptions  : warns if directory already exists

=cut

sub make_species_directory {
  my ($base_dir, $species) = @_;

  my $db_adaptor = Bio::EnsEMBL::Registry->get_DBAdaptor($species, "core");
  if (!$db_adaptor) {
    throw("Cannot connect to core database for $species!");
  }

  my $species_name = $db_adaptor->get_MetaContainer->get_Species->binomial." ".
      $db_adaptor->get_CoordSystemAdaptor->fetch_all->[0]->version;
  $species_name =~ s/ /\_/g;

  make_directory("$DNA_DIR/$species_name:c$chunk_size:o$overlap:m$masked", "<$species>");

  return "$species_name:c$chunk_size:o$overlap:m$masked";
}


=head2 dump_dna

  Arg[1]      : string $base_dir
  Arg[2]      : string $species_name
  Arg[3]      : string $species_directory
  Arg[4]      : [otpional] listref $seq_region_names
  Example     : dump_dna("/usr/local/data", "human", "Homo_sapiens_NCBI35");
  Example     : dump_dna("/usr/local/data", "human", "Homo_sapiens_NCBI35", ["14", "15"]);
  Description : Dump all the "top_level" dnafrags into FASTA files in the
                species_directory
  Returntype  : string species_directory_name
  Exceptions  : warns if directory already exists

=cut

sub dump_dna {
  my ($base_dir, $species, $species_directory, $seq_region_names) = @_;
  my $lsf_jobs = [];

  print LOG "Dumping DNA for <$species>:\n";

  my $db_adaptor = Bio::EnsEMBL::Registry->get_DBAdaptor($species, "core");
  if (!$db_adaptor) {
    throw("Cannot connect to core database for $species!");
  }

  my $phusion = $species_directory;
  $phusion =~ s/^(.)[^\_]+\_(.).+/$1$2/;

  my $sql =  qq{
          SELECT
            sr.name,
            cs.name,
            sr.length
          FROM
            coord_system cs,
            seq_region sr,
            seq_region_attrib sra,
            attrib_type at
          WHERE
            sra.attrib_type_id = at.attrib_type_id
            AND at.code = 'toplevel'
            AND sr.seq_region_id = sra.seq_region_id
            AND sr.coord_system_id = cs.coord_system_id
            AND sr.name not like "\%_NT_\%"
            AND sr.name not like "\%_DR_\%"
            AND sr.name not like "UNKN"
      };
  if (defined($seq_region_names) and @$seq_region_names) {
    $sql .= "\n            AND sr.name IN (\"".join("\", \"", @$seq_region_names) ."\")";
  }

  my $sth = $db_adaptor->dbc->prepare($sql);
  $sth->execute;
  open(SEQ_REGIONS, ">$DNA_DIR/$species_directory/seq_regions")
      or throw("Cannot open $DNA_DIR/$species_directory/seq_regions for writting!");
  open(INDEX, ">$DNA_DIR/$species_directory/seq_regions.index")
      or throw("Cannot open seq_regions.index for writting!");
#  my $size_by_coord_system;
  while (my $values = $sth->fetchrow_arrayref) {
    my $seq_region_name = $values->[0];
    my $coordinate_system_name = $values->[1];
    my $length = $values->[2];
    throw "Coordinate system [$coordinate_system_name] has not been configured"
        if (!defined($coord_systems->{$coordinate_system_name}));
#    if ($coord_systems->{$coordinate_system_name} eq "single_file") {
#      my $size = ($size_by_coord_system->{$coordinate_system_name} or 0);
#      my $seq_region_file = "$DNA_DIR/$species_directory/${coordinate_system_name}.fa";
#      my $num_of_chunks = 0;
#      my $base_id = $phusion.".".$coordinate_system_name.":".$seq_region_name;
#      for (my $i=1;$i<=$length;$i+=$chunk_size-$overlap) {
#        my $id = $base_id.".".$i;
#        print INDEX $id, " ", $seq_region_file, " ", ($size+1), "\n"; 
#        $size += 1 + length($id) + 1; ## ID line is: >$id\n
#        $num_of_chunks++;
#        if ($i+$chunk_size-1 > $length) {
#          my $this_chunk = $length - $i + 1;
#          $size += $this_chunk;
#          $size += int($this_chunk/60) + (($this_chunk%60)?1:0);
#        } else {
#          $size += $chunk_size;
#          $size += int($chunk_size/60) + (($chunk_size%60)?1:0);
#        }
#      }
#      $size_by_coord_system->{$coordinate_system_name} = $size;
#      next;
#    }
    my $lsf_output_file = "$DNA_DIR/$species_directory/bsub_${coordinate_system_name}_${seq_region_name}.out";
    my $seq_region_file = "$DNA_DIR/$species_directory/${coordinate_system_name}_$seq_region_name.fa";
    my $this_lsf_job;

    my $size = 0;
    my $num_of_chunks = 0;
    my $base_id = $phusion.".".$coordinate_system_name.":".$seq_region_name;
    for (my $i=1;$i<=$length;$i+=$chunk_size-$overlap) {
      my $id = $base_id.".".$i;
      print INDEX $id, " ", $seq_region_file, " ", ($size+1), "\n"; 
      $size += 1 + length($id) + 1; ## ID line is: >$id\n
      $num_of_chunks++;
      if ($i+$chunk_size-1 > $length) {
        my $this_chunk = $length - $i + 1;
        $size += $this_chunk;
        $size += int($this_chunk/60) + (($this_chunk%60)?1:0);
      } else {
        $size += $chunk_size;
        $size += int($chunk_size/60) + (($chunk_size%60)?1:0);
      }
    }

    my $job_name = "Dump.$phusion.${coordinate_system_name}_${seq_region_name}";
    my $run_str = "bsub -q $queue -o $lsf_output_file -J\"$job_name\"".
      " $base_dir/bin/DumpChromosomeFragments.pl".
      " -dbname $species".
      " -chr_names $seq_region_name".
      " -coord_system $coordinate_system_name".
      " -overlap $overlap".
      " -chunk_size $chunk_size".
      " -masked $masked".
      " -phusion $phusion".
      " -o $seq_region_file";
    $run_str .= " -reg_conf=$reg_conf" if (defined($reg_conf));
 
    $this_lsf_job = {
            name => $job_name,
            run_str => $run_str,
            lsf_output_file => $lsf_output_file,
            result_file => $seq_region_file,
            result_file_size => $size,
            check =>
                    "grep=`fgrep -c '>$base_id' $seq_region_file`;".
                    " if (test \$grep -eq $num_of_chunks) then (echo 1) fi",
        };

    push(@$lsf_jobs, $this_lsf_job);

    print SEQ_REGIONS "${coordinate_system_name}_${seq_region_name}\n";

    if (-e $seq_region_file) {
      my $current_size = -s $seq_region_file;
      if ($current_size == $size) {
        print LOG "  [ok] ${coordinate_system_name}_${seq_region_name}:",
            " $length bp -- $num_of_chunks chunks -- $size bytes\n";
        $this_lsf_job->{action} = "none";
        $this_lsf_job->{ok} = 1;
        next;
      } else {
        unlink($seq_region_file);
        print LOG "  [rerun] ${coordinate_system_name}_${seq_region_name}:",
            " $length bp -- $num_of_chunks chunks -- $size bytes\n";
        $this_lsf_job->{action} = "rerun";
      }
    } else {
      print LOG "  [run] ${coordinate_system_name}_${seq_region_name}:",
            " $length bp -- $num_of_chunks chunks -- $size bytes\n";
      $this_lsf_job->{action} = "run";
    }

    my $result = qx"$run_str";

    my $try = 1;
    while (($result !~ /^Job \<(\d+)\> is submitted to queue \<$queue\>.$/) and $try<=3) {
      warning("Error while submitting job for dumping $species $coordinate_system_name $seq_region_name ($try/3)\n -- $result");
      sleep(10);
      $try++;
      $result = qx"$run_str";
    }
    if ($result !~ /^Job \<(\d+)\> is submitted to queue \<$queue\>.$/) {
      throw("Error while submitting job for dumping $species $coordinate_system_name $seq_region_name\n -- $result");
    } else {
      $this_lsf_job->{job_ID} = $1;
    }
    doze_instead_of_flooding_LSF_queue($lsf_jobs);
  }
  close(SEQ_REGIONS);
  close(INDEX);

  print LOG scalar(grep {$_->{action} =~ /run/} @$lsf_jobs)." LSF jobs submitted.\n";

  check_LSF_jobs($lsf_jobs, "wait");

  return $lsf_jobs;
}


=head2 launch_BLAT

  Arg[1]      : string $species1_directory_name
  Arg[2]      : string $species2_directory_name
  Example     : 
  Description : 
  Returntype  : 
  Exceptions  : 

=cut

sub launch_BLAT {
  my ($species1_dir, $species2_dir) = @_;

  my $dir = "$RUN_DIR/${species1_dir}_vs_$species2_dir";
  print LOG "Making directory for BLAT results:\n  ";
  if (!-e "$dir") {
    mkdir("$dir")
        or throw("Directory $dir cannot be created");
  } else {
    print LOG "[already existing] ";
  }
  print LOG "$dir\n";

  my $prefix1 = $species1_dir;
  my $prefix2 = $species2_dir;
  $prefix1 =~ s/\_[^\_]+$//;
  $prefix2 =~ s/\_[^\_]+$//;
  $prefix1 =~ s/(\w)\w+\_(\w)\w+/$1$2/g;
  $prefix2 =~ s/(\w)\w+\_(\w)\w+/$1$2/g;
  print LOG "Launching BLAT ($species1_dir vs $species2_dir): \n";
  my @seq_regions1 = qx"cat $DNA_DIR/$species1_dir/seq_regions";
  map {s/[\r\n]+$//} @seq_regions1;

  ## Create chunk sets for running BLAT sub-jobs
  create_chunk_sets($species2_dir, $prefix2);

  my $BLAT_lsf_jobs;
  ## Launch sets of BLAT jobs for each seq_region of species1
  foreach my $seq_region1 (@seq_regions1) {

    make_directory("$dir/${prefix1}.$seq_region1", "BLAT results ($seq_region1)");

    my $ooc_file = create_ooc_file($species1_dir, $dir, $prefix1, $seq_region1);

    my $job_name = "BLAT.$prefix1.$seq_region1.vs.$prefix2";
    my $lsf_output_file = "$dir/${prefix1}.$seq_region1/bsub.$job_name-\%I.out";
    my $lsf_error_file = "$dir/${prefix1}.$seq_region1/bsub.$job_name-\${LSB_JOBINDEX}.err";
    my $bsub_in = 
          ". /usr/local/lsf/conf/profile.lsf\n".
          "$BIN_DIR/LaunchBLAT.pl".
              " -idqy $DNA_DIR/$species2_dir/seq_regions.sets/\${LSB_JOBINDEX}".
#               " -fastaqy $DNA_DIR/$species2_dir/$seq_region2.fa".
              " -indexqy $DNA_DIR/$species2_dir/seq_regions.index".
              " -fastadb $DNA_DIR/$species1_dir/$seq_region1.fa".
              " -query_type dnax".
              " -target_type dnax".
              " -makefile $ooc_file".
              " -fastafetch $BIN_DIR/fastafetch.pl".
              " 2> /tmp/$job_name-\${LSB_JOBINDEX}.err\n".
          "status=\$?\n".
          "lsrcp /tmp/$job_name-\${LSB_JOBINDEX}.err ecs4b:$lsf_error_file\n".
          "rm -f /tmp/$job_name-\${LSB_JOBINDEX}.err\n".
          "exit \$status\n";

    my $count = 1;
    my $chunk_set_file = "$DNA_DIR/$species2_dir/seq_regions.sets/$count";
    my @job_array_ids;
    my $these_jobs;
    while (-e $chunk_set_file) {
      my $this_job_name = $job_name."[$count]";
      my $this_lsf_output_file = $lsf_output_file;
      $this_lsf_output_file =~ s/\%I/$count/;
      my $this_lsf_error_file = $lsf_error_file;
      $this_lsf_error_file =~ s/\$\{LSB_JOBINDEX\}/$count/;
#      my ($coord_system_name, $seq_region_name) = $seq_region2 =~ /^([^\_]+)_(.+)$/;
      my $bsub_pipe = "bsub -q $queue -J\"$this_job_name\" -o $this_lsf_output_file";
      my $this_lsf_job = {
              name => $this_job_name,
              lsf_output_file => $this_lsf_output_file,
              result_file => $this_lsf_error_file,
              result_file_match => "running blat",
              check =>
                  "grep=`grep -cvE '^$prefix2.' $this_lsf_error_file`;".
                  " if (test \$grep -eq 1) then (echo 1) fi",
              bsub_pipe => $bsub_pipe,
              bsub_in => $bsub_in,
          };
      push(@$BLAT_lsf_jobs, $this_lsf_job);
      $these_jobs->[$count-1] = $this_lsf_job;

      if (-e $this_lsf_output_file) {
        if (qx{fgrep "Successfully completed." $this_lsf_output_file}) {
          print LOG "  [ok] $this_job_name\n";
          $this_lsf_job->{action} = "none";
          $this_lsf_job->{ok} = 1;
        } else {
          unlink($this_lsf_output_file, $this_lsf_error_file);
          print LOG "  [rerun] $this_job_name\n";
          $this_lsf_job->{action} = "rerun";
          push(@job_array_ids, $count);
        }
      } else {
        unlink($this_lsf_error_file);
        print LOG "  [run] $this_job_name\n";
        $this_lsf_job->{action} = "run";
        push(@job_array_ids, $count);
      }

      $count++;
      $chunk_set_file = "$DNA_DIR/$species2_dir/seq_regions.sets/$count";
    }
    next if (!@job_array_ids);

    my $job_array_string = "[".$job_array_ids[0];
    for (my $i=1; $i<@job_array_ids; $i++) {
      if ($job_array_ids[$i] - $job_array_ids[$i-1] == 1) {
        if ($job_array_string =~ /[\[\,]\d+$/) {
          $job_array_string .= "-".$job_array_ids[$i];
        } else {
          $job_array_string =~ s/\-\d+$/\-$job_array_ids[$i]/;
        }
      } else {
        $job_array_string .= ",".$job_array_ids[$i];
      }
    }
    $job_array_string .= "]";
    
    my $bsub_pipe = "bsub -q $queue -J\"$job_name".
        $job_array_string."\" -o $lsf_output_file";
    my $pid = open2(*BSUB_OUT, *BSUB_IN, $bsub_pipe) or throw("Cannot pipe though bsub");
    print BSUB_IN $bsub_in;
    close(BSUB_IN);
    my $result = <BSUB_OUT>;
    close(BSUB_OUT);
    waitpid($pid, 0);
    my $try = 1;
    while (($result !~ /^Job \<(\d+)\> is submitted to queue \<$queue\>.$/) and $try<=3) {
      warning("Error while submitting job $job_name ($try/3)\n -- $result");
      sleep(10);
      $try++;
      my $pid = open2(*BSUB_OUT, *BSUB_IN, $bsub_pipe) or throw("Cannot pipe though bsub");
      print BSUB_IN $bsub_in;
      close(BSUB_IN);
      $result = <BSUB_OUT>;
      close(BSUB_OUT);
      waitpid($pid, 0);
    }
    if ($result !~ /^Job \<(\d+)\> is submitted to queue \<$queue\>.$/) {
      throw("Error while submitting job $job_name\n -- $result");
    }
    my $job_id = $1;
    foreach my $job_array_id (@job_array_ids) {
      $these_jobs->[$job_array_id-1]->{job_ID} = $job_id."[$job_array_id]";
    }

    doze_instead_of_flooding_LSF_queue($BLAT_lsf_jobs);

#    foreach my $seq_region2 (@seq_regions2) {
#      print "$prefix1.$seq_region1 vs $prefix2.$seq_region2\n";
#      my $count = 1;
#      my $chunk_set_file = "$DNA_DIR/$species2_dir/seq_regions.sets/$count";
#      while (-e $chunk_set_file) {
#        my $job_name = "BLAT.$prefix1.$seq_region1.vs.$prefix2.$seq_region2-$count";
#        my $lsf_output_file = "$dir/${prefix1}.$seq_region1/bsub.$job_name.out";
#        my $lsf_error_file = "$dir/${prefix1}.$seq_region1/bsub.$job_name.err";
#        my $bsub_pipe = "bsub -q $queue -J\"$job_name\" -o $lsf_output_file";
#        my $bsub_in = 
#            ". /usr/local/lsf/conf/profile.lsf\n".
#            "$BIN_DIR/LaunchBLAT.pl".
#                " -idqy $chunk_set_file".
##                 " -fastaqy $DNA_DIR/$species2_dir/$seq_region2.fa".
#                " -indexqy $DNA_DIR/$species2_dir/seq_regions.index".
#                " -fastadb $DNA_DIR/$species1_dir/$seq_region1.fa".
#                " -query_type dnax".
#                " -target_type dnax".
#                " -makefile $ooc_file".
#                " -fastafetch $BIN_DIR/fastafetch.pl".
#                " 2> /tmp/$job_name.err\n".
#            "status=\$?\n".
#            "lsrcp /tmp/$job_name.err ecs4b:$lsf_error_file\n".
#            "rm -f /tmp/$job_name.err\n".
#            "exit \$status\n";
#        my ($coord_system_name, $seq_region_name) = $seq_region2 =~ /^([^\_]+)_(.+)$/;
#        my $this_lsf_job = {
#                name => $job_name,
#                lsf_output_file => $lsf_output_file,
#                result_file => $lsf_error_file,
#                result_file_match => "running blat",
#                check =>
#                    "grep=`grep -cv '^$prefix2.$coord_system_name:$seq_region_name' $lsf_error_file`;".
#                    " if (test \$grep -eq 1) then (echo 1) fi",
#                bsub_pipe => $bsub_pipe,
#                bsub_in => $bsub_in,
#            };
#        push(@$BLAT_lsf_jobs, $this_lsf_job);
#
#        $count++;
#        $chunk_set_file = "$DNA_DIR/$species2_dir/seq_regions.sets/$count";
#
#        if (-e $lsf_output_file) {
#          if (qx{fgrep "Successfully completed." $lsf_output_file}) {
#            print LOG "  [ok] $job_name\n";
#            $this_lsf_job->{action} = "none";
#            next;
#          } else {
#            unlink($lsf_output_file, $lsf_error_file);
#            print LOG "  [rerun] $job_name\n";
#            $this_lsf_job->{action} = "rerun";
#          }
#        } else {
#          unlink($lsf_error_file);
#          print LOG "  [run] $job_name\n";
#          $this_lsf_job->{action} = "run";
#        }
#
#        my $pid = open2(*BSUB_OUT, *BSUB_IN, $bsub_pipe) or throw("Cannot pipe though bsub");
#        print BSUB_IN $bsub_in;
#        close(BSUB_IN);
#        my $result = <BSUB_OUT>;
#        close(BSUB_OUT);
#        waitpid($pid, 0);
#        my $try = 1;
#        while (($result !~ /^Job \<(\d+)\> is submitted to queue \<$queue\>.$/) and $try<=3) {
#          warning("Error while submitting job $job_name ($try/3)\n -- $result");
#          sleep(10);
#          $try++;
#          my $pid = open2(*BSUB_OUT, *BSUB_IN, $bsub_pipe) or throw("Cannot pipe though bsub");
#          print BSUB_IN $bsub_in;
#          close(BSUB_IN);
#          $result = <BSUB_OUT>;
#          close(BSUB_OUT);
#          waitpid($pid, 0);
#        }
#        if ($result !~ /^Job \<(\d+)\> is submitted to queue \<$queue\>.$/) {
#          throw("Error while submitting job $job_name\n -- $result");
#        }
#        $this_lsf_job->{job_ID} = $1;
#
#        doze_instead_of_flooding_LSF_queue($BLAT_lsf_jobs);
#      }
#    }
  }
  print LOG scalar(grep {$_->{action} =~ /run/} @$BLAT_lsf_jobs)." LSF jobs submitted.\n";
  check_LSF_jobs($BLAT_lsf_jobs, "wait");

  my $parsing_lsf_jobs;
  foreach my $seq_region1 (@seq_regions1) {

    # Compile results for this seq_region
    compile_BLAT_results($species1_dir, $species2_dir, $seq_region1);

    my $this_parsing_lsf_job = parse_BLAT_results($dir, $prefix1, $seq_region1);
    push(@$parsing_lsf_jobs, $this_parsing_lsf_job);
    doze_instead_of_flooding_LSF_queue($parsing_lsf_jobs);
  }
  check_LSF_jobs($parsing_lsf_jobs, "wait");

  concat_BLAT_results($dir, $prefix1, @seq_regions1);

  return $dir;
}


=head2 create_chunk_sets

  Arg[1]      : string $species_directory_name
  Arg[2]      : string $prefix (2 letters code for this species)
  Arg[3]      : listref $seq_regions
  Example     : 
  Description : 
  Returntype  : 
  Exceptions  : 

=cut

sub create_chunk_sets {
  my ($species_dir, $prefix) = @_;

  my @chunks = qx"cat $DNA_DIR/$species_dir/seq_regions.index";
  map {s/ .+[\r\n]+$//} @chunks;
  my $count = 0;
  make_directory("$DNA_DIR/$species_dir/seq_regions.sets", "$prefix chunk sets");
  while (my @set = splice(@chunks, 0, 40)) {
    $count++;
    my $chunk_set_file = "$DNA_DIR/$species_dir/seq_regions.sets/$count";
    next if (-e $chunk_set_file);
    open(CHUNK_SET, ">$chunk_set_file")
        or throw("Cannot open $chunk_set_file for writting");
    foreach my $chunk (@set) {
      print CHUNK_SET "$chunk\n";
    }
    close(CHUNK_SET);
  }
  unlink("$DNA_DIR/$species_dir/seq_regions.sets/".($count+1)); # Just in case...
}


=head2 create_ooc_file

  Arg[1]      : string $species_directory_name
  Arg[2]      : string $results_dir
  Arg[3]      : string $prefix (2 letters code for this species)
  Arg[4]      : string $seq_region
  Example     : 
  Description : 
  Returntype  : 
  Exceptions  : 

=cut

sub create_ooc_file {
  my ($species_dir, $dir, $prefix, $seq_region) = @_;

  my $ooc_file = "$dir/$prefix.$seq_region/5ooc";
  if (!-e $ooc_file) {
    my $runnable = new Bio::EnsEMBL::Pipeline::Runnable::Blat (
        -database => "$DNA_DIR/$species_dir/$seq_region.fa",
        -query_type => "dnax",
        -target_type => "dnax",
        -options => "-ooc=$ooc_file -tileSize=5 -makeOoc=$ooc_file -mask=lower -qMask=lower");
    $runnable->run;
  }

  return $ooc_file;
}


=head2 compile_BLAT_results

  Arg[1]      : string $species1_directory_name
  Arg[2]      : string $results_directory_name
  Example     : 
  Description : 
  Returntype  : 
  Exceptions  : 

=cut

sub compile_BLAT_results {
  my ($species1_dir, $species2_dir, $seq_region1) = @_;

  my $dir = "$RUN_DIR/${species1_dir}_vs_$species2_dir";
  my $prefix1 = $species1_dir;
  my $prefix2 = $species2_dir;
  $prefix1 =~ s/\_[^\_]+$//;
  $prefix2 =~ s/\_[^\_]+$//;
  $prefix1 =~ s/(\w)\w+\_(\w)\w+/$1$2/g;
  $prefix2 =~ s/(\w)\w+\_(\w)\w+/$1$2/g;
  my @seq_regions2 = qx"cat $DNA_DIR/$species2_dir/seq_regions";
  map {s/[\r\n]+$//} @seq_regions2;

  print LOG "Compiling BLAT results ($prefix1.$seq_region1):\n  ";
  my $output_file_name = "$dir/${prefix1}.$seq_region1.raw";
  # Compile results for this seq_region
  my $last_mod = 0;
  if (-e $output_file_name) {
    foreach my $seq_region2 (@seq_regions2) {
      my $count = 1;
      my $chunk_set_file = "$DNA_DIR/$species2_dir/seq_regions.sets/count";
      while (-e $chunk_set_file) {
        my $job_name = "BLAT.$prefix1.$seq_region1.vs.$prefix2.$seq_region2-$count";
        my $lsf_error_file = "$dir/${prefix1}.$seq_region1/bsub.$job_name.err";
        my $this_last_mod = (stat($lsf_error_file))[9];
        $last_mod = $this_last_mod if ($this_last_mod > $last_mod);
        $count++;
        $chunk_set_file = "$DNA_DIR/$species2_dir/seq_regions.sets/$count";
      }
    }
  }

  my ($coord_system_name, $seq_region_name) = $seq_region1 =~ /^(.+)_(.+)$/;
  my $run_str = "find $dir/${prefix1}.$seq_region1/ | grep -e '.err\$' |".
      " xargs grep -h -e '^$prefix2' -e '$prefix1.$coord_system_name:$seq_region_name'".
      "  > $output_file_name";
  if (!-e $output_file_name) {
    print "[run] compile.BLAT.$prefix1.${seq_region1}_vs_$prefix2.all";
    qx"$run_str";
  } elsif (!-e $output_file_name or $last_mod >(stat($output_file_name))[9]) {
    print "[rerun] compile.BLAT.$prefix1.${seq_region1}_vs_$prefix2.all";
    qx"$run_str";
  } else {
    print "[ok] compile.BLAT.$prefix1.${seq_region1}_vs_$prefix2.all";
  }
  my $num_of_hits = qx"wc -l $output_file_name";
  $num_of_hits =~ s/[\r\n]+//g;
  $num_of_hits =~ s/ *(\d+).+$/$1/;
  print " -- $num_of_hits hits found.\n";
}


=head2 parse_BLAT_results

  Arg[1]      : string $species1_directory_name
  Arg[2]      : string $results_directory_name
  Example     : 
  Description : 
  Returntype  : 
  Exceptions  : 

=cut

sub parse_BLAT_results {
  my ($dir, $prefix, $seq_region) = @_;

  print LOG "Parsing BLAT results ($prefix.$seq_region):\n";
  my $input_file = "$dir/$prefix.$seq_region.raw";
  my $lsf_output_file = "$dir/$prefix.$seq_region.out";
  my $result_file = "$dir/$prefix.$seq_region";
  my $job_name = "Parse.BLAT.$prefix.${seq_region}_vs_$species2";
  my $run_str = "bsub -q $queue -o $lsf_output_file -J $job_name".
      " $BIN_DIR/parse_and_score.pl -F $input_file".
      " -O $result_file -D 15000 -S1 $species2 -S2 $species1";
  $run_str .= " -CF $reg_conf" if ($reg_conf);

  my $this_lsf_job = {
          name => $job_name,
          run_str => $run_str,
          lsf_output_file => $lsf_output_file,
          result_file => "$result_file.data",
#          check => "grep=`fgrep Lost $lsf_output_file`;".
#                  " if (test \"\$grep\" = \"Lost 0 bad seqs\") then (echo 1) fi",
      };

  if (-e "$result_file.data") {
    my $input_last_mod = (stat($input_file))[9];
    my $res_last_mod = (stat("$result_file.data"))[9];
    if ($input_last_mod < $res_last_mod) {
      print LOG "  [ok] $job_name\n";
      $this_lsf_job->{action} = "none";
      return $this_lsf_job;
    } else {
      unlink("$result_file.data", $lsf_output_file);
      print LOG "  [rerun] $job_name\n";
      $this_lsf_job->{action} = "rerun";
    }
  } else {
    unlink("$result_file.data", $lsf_output_file);
    print LOG "  [run] $job_name\n";
    $this_lsf_job->{action} = "run";
  }

  my $result = qx"$run_str";

  my $try = 1;
  while (($result !~ /^Job \<(\d+)\> is submitted to queue \<$queue\>.$/) and $try<=3) {
    warning("Error while submitting job $job_name ($try/3)\n -- $result");
    sleep(10);
    $try++;
    $result = qx"$run_str";
  }
  if ($result !~ /^Job \<(\d+)\> is submitted to queue \<$queue\>.$/) {
    throw("Error while submitting job $job_name\n -- $result");
  } else {
    $this_lsf_job->{job_ID} = $1;
  }

  return $this_lsf_job;
}


sub concat_BLAT_results {
  my ($dir, $prefix, @seq_regions) = @_;

  print LOG "Concatenating BLAT results ($prefix):\n";
  if (!@seq_regions) {
    throw("Nothing to concat!");
  }
  my $last_mod = 0;
  my $concat_rstr = "cat";
  foreach my $seq_region (@seq_regions) {
    my $data_file = "$dir/${prefix}.$seq_region.data";
    my $this_last_mod = (stat($data_file))[9];
    $last_mod = $this_last_mod if ($this_last_mod > $last_mod);
    $concat_rstr .= " $data_file";
  }
  my $final_file = "$dir/all.data";
  $concat_rstr .= " > $final_file";
  if (!-e $final_file) {
    print LOG "  [run] $final_file\n";
    qx"$concat_rstr";
  } elsif ((stat($final_file))[9] < $last_mod) {
    print LOG "  [rerun] $final_file\n";
    qx"$concat_rstr";
  } else {
    print LOG "  [ok] $final_file\n";
  }

  return $final_file;
}


sub check_LSF_jobs {
  my ($lsf_jobs, $wait) = @_;
  if (defined($wait) and $wait =~ /^wait$/i) {
    $wait = 1;
  } else {
    $wait = 0;
  }

  my $done;
  my $persistent_error = 0;
  print LOG "Waiting for completion" if ($wait);
  do {
    print LOG "." if ($wait);
    $done = 1;
    foreach my $this_lsf_job (@$lsf_jobs) {
      $this_lsf_job->{retry} = 0;
    }
    foreach my $this_lsf_job (@$lsf_jobs) {
      next if ($this_lsf_job->{ok} or $this_lsf_job->{retry} >= 10);
      my $status;
      if (defined($this_lsf_job->{job_ID})) {
        my $bjobs = qx"bjobs \"$this_lsf_job->{job_ID}\" 2>&1";
        $status = $bjobs;
        $status =~ s/[^\n]+\n(.)/$1/;
        ($status) = $status =~ /\d+ +\w+ +(\w+)/;
        $status = $bjobs if (!defined($status));
      } else {
        $status = "DONE";
      }

      my $fail = 0;
      if ($status =~ /PEND/ or $status =~ /RUN/) {
        $done = 0;
        $this_lsf_job->{funny_status} = undef;
      } elsif ($status =~ /EXIT/) {
        $fail = 1;
        $this_lsf_job->{funny_status} = undef;
      } elsif ($status =~ /DONE/) {
        $this_lsf_job->{funny_status} = undef;
        if (-e $this_lsf_job->{lsf_output_file} and -e $this_lsf_job->{result_file} ) {
          # Check LSF output file
          if (!qx[fgrep "Successfully completed." $this_lsf_job->{lsf_output_file}]) {

            $fail = 2;
          }

          if (defined($this_lsf_job->{result_file_size})) {
            # Check size of result_file
            my $size = -s $this_lsf_job->{result_file};
            if ($size != $this_lsf_job->{result_file_size}) {
              $fail = 3;
            }
          }

          if (defined($this_lsf_job->{result_file_match})) {
            if (!qx[fgrep \"$this_lsf_job->{result_file_match}\" $this_lsf_job->{result_file}]) {
              $fail = 4;
            }
          }

          if (defined($this_lsf_job->{check})) {
#print STDERR "\n", $this_lsf_job->{check}, "\n\n";
            if (!qx"$this_lsf_job->{check}") {

#print STDERR "\n<<<", qx"$this_lsf_job->{check}", ">>>\n";
              $fail = 5;
            }
          }
          $this_lsf_job->{ok} = 1 if (!$fail);
        } else {
          $done = 0;
          $fail = 6;
        }
      } else {
        $done = 0;
        if (defined($this_lsf_job->{funny_status})) {
          warning("Job $this_lsf_job->{name}($this_lsf_job->{job_ID}) is in a funny status ($status)\n".
              "  -- I will try to restart it");
          qx"bkill $this_lsf_job->{job_ID}";
          sleep(10); #Give some time to actually kill the job.
          $fail = 7;
          $this_lsf_job->{funny_status} = undef;
        } else {
          $this_lsf_job->{funny_status} = 1;
        }
      }

      if ($fail) {
        $done = 0;
        # Retry...
        $this_lsf_job->{retry}++;
        if ($this_lsf_job->{retry}<10) {
#          unlink($this_lsf_job->{lsf_output_file}, $this_lsf_job->{result_file});
          qx"mv $this_lsf_job->{lsf_output_file} $this_lsf_job->{lsf_output_file}.$$.$this_lsf_job->{retry}"
              if (-e $this_lsf_job->{lsf_output_file});
          qx"mv $this_lsf_job->{result_file} $this_lsf_job->{result_file}.$$.$this_lsf_job->{retry}"
              if (-e $this_lsf_job->{result_file});
          print LOG "\n -- Trying $this_lsf_job->{name} again (err=$fail)\n";
          print LOG "Checking for completion" if ($wait);
          my $run_str = $this_lsf_job->{run_str};
          my $result;
          if (defined($this_lsf_job->{run_str})) {
            $result = qx"$run_str";
          } elsif (defined($this_lsf_job->{bsub_pipe}) and defined($this_lsf_job->{bsub_in})) {
            my $pid = open2(*BSUB_OUT, *BSUB_IN, $this_lsf_job->{bsub_pipe}) or throw("Cannot pipe though bsub");
            print BSUB_IN $this_lsf_job->{bsub_in};
            close(BSUB_IN);
            $result = <BSUB_OUT>;
            close(BSUB_OUT);
            waitpid($pid, 0);
          }
          if ($result !~ /^Job \<(\d+)\> is submitted to queue \<$queue\>.$/) {
            throw("Error while re-submitting job  $this_lsf_job->{name}\n -- $result");
          }
          $this_lsf_job->{job_ID} = $1;
        } else {
          qx"mv $this_lsf_job->{lsf_output_file} $this_lsf_job->{lsf_output_file}.$$.$this_lsf_job->{retry}";
          qx"mv $this_lsf_job->{result_file} $this_lsf_job->{result_file}.$$.$this_lsf_job->{retry}";
          warning("Error after re-submitting job  $this_lsf_job->{name}\n -- ERRCODE: $fail. STATUS: $status");
          $persistent_error = 1;
        }
      }
    }
    sleep(10) if (!$done and $wait);
  } while (!$done and $wait);
  throw("Unrecoverable error. Check log!") if ($persistent_error);
  print LOG " ok.\n" if ($wait);

  return $done;
}


sub doze_instead_of_flooding_LSF_queue {
  my ($lsf_jobs) = @_;

  ## Wait if more than 200 jobs are running or pending
  if ((grep {!defined($_->{ok})} @$lsf_jobs) > 200) {
    print LOG "Dozing";
    do {
      sleep(60); # wait for 1 minute
      print LOG ".";
      check_LSF_jobs($lsf_jobs); #check LSF jobs. OK status will be updated
    } while ((grep {!defined($_->{ok})} @$lsf_jobs) > 150);
    print LOG "\n";
  }
}


sub make_directory {
  my ($dir, $label) = @_;

  if ($label) {
    print LOG "Making directory for $label:\n  ";
  } else {
    print LOG "Making directory $dir:\n  ";
  }
  if (!-e "$dir") {
    mkdir("$dir")
        or throw("Directory $dir cannot be created");
  } else {
    print LOG "[already existing] ";
  }
  print LOG "$dir\n";
}


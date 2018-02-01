=head1 LICENSE

Copyright [1999-2015] Wellcome Trust Sanger Institute and the EMBL-European Bioinformatics Institute
Copyright [2016-2018] EMBL-European Bioinformatics Institute

Licensed under the Apache License, Version 2.0 (the "License");
you may not use this file except in compliance with the License.
You may obtain a copy of the License at

     http://www.apache.org/licenses/LICENSE-2.0

Unless required by applicable law or agreed to in writing, software
distributed under the License is distributed on an "AS IS" BASIS,
WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
See the License for the specific language governing permissions and
limitations under the License.

=cut


=head1 CONTACT

  Please email comments or questions to the public Ensembl
  developers list at <http://lists.ensembl.org/mailman/listinfo/dev>.

  Questions may also be sent to the Ensembl help desk at
  <http://www.ensembl.org/Help/Contact>.

=head1 NAME

Bio::EnsEMBL::Compara::RunnableDB::GenomicAlignBlock::MultipleAlignerStats

=cut

=head1 SYNOPSIS

$module->fetch_input

$module->run

$module->write_output

=cut

=head1 DESCRIPTION

This module updates the method_link_species_set_tag table with multiple alignment statistics by firstly adding any new bed files to the correct directory and running compare_beds to generate the statistics

=head1 APPENDIX

The rest of the documentation details each of the object methods.
Internal methods are usually preceded with a _

=cut

package Bio::EnsEMBL::Compara::RunnableDB::GenomicAlignBlock::MultipleAlignerStats;

use strict;
use warnings;

use Bio::EnsEMBL::Hive::DBSQL::DBConnection;
use Bio::EnsEMBL::Hive::Utils 'stringify';  # import 'stringify()'
use Bio::EnsEMBL::Compara::Utils::CoreDBAdaptor;
use File::stat;

use base ('Bio::EnsEMBL::Compara::RunnableDB::BaseRunnable');

=head2 fetch_input

  Implementation of the Bio::EnsEMBL::Hive::Process interface

=cut

sub fetch_input {
  my ($self) = @_;

  #Default directory containing bed files.
  if (!defined $self->param('bed_dir')) {
      die ("Must define a location to dump the bed files using the parameter 'bed_dir'");
  }
  #Find the mlss_id from the method_link_type and genome_db_ids
  my $mlss;
  my $mlss_adaptor = $self->compara_dba->get_MethodLinkSpeciesSetAdaptor;
  if (defined $self->param('mlss_id')) {
      $mlss = $mlss_adaptor->fetch_by_dbID($self->param('mlss_id'));
  } else{
      if (defined $self->param('method_link_type') && $self->param('genome_db_ids')) {
	  die ("No method_link_species_set") if (!$mlss_adaptor);
	  $mlss = $mlss_adaptor->fetch_by_method_link_type_genome_db_ids($self->param('method_link_type'), $self->param('genome_db_ids'));
	  $self->param('mlss_id', $mlss->dbID);
      } else {
	  die("must define either mlss_id or method_link_type and genome_db_ids");
      }
  }

  $self->param('mlss_id', $mlss->dbID);

  my $genome_db_adaptor = $self->compara_dba->get_GenomeDBAdaptor;
  my $genome_db = $genome_db_adaptor->fetch_by_dbID($self->param('genome_db_id'));
  $self->param('genome_db', $genome_db);

  $self->param('species', $genome_db->name);

   #Create url from db_adaptor
  my $url = $genome_db->db_adaptor->url;

  #Need to protect with quotes
  $self->param('dbc_url', "\"$url\"");

  $self->require_executable('dump_features');
  $self->require_executable('compare_beds');
  
  return 1;
}


sub write_output {
  my ($self) = @_;

  #Dump bed files if necessary
  my ($genome_bed, $coding_exon_bed) = $self->dump_bed_file($self->param('species'), $self->param('dbc_url'));

  #Create statistics
  $self->write_statistics($genome_bed, $coding_exon_bed);

  return 1;
}


#
#Write bed file to general repository for a new species or assembly. The naming scheme assumes the format
#production_name.assembly.genome.bed for toplevel regions and production_name.assembly.coding_exons.bed for exonic
#regions. If a file of that convention already exists, it will not be overwritten.
#
sub dump_bed_file {
    my ($self, $species, $dbc_url) = @_;

    #Need assembly
    my $genome_db = $self->compara_dba->get_GenomeDBAdaptor->fetch_by_registry_name($species);
    my $assembly = $genome_db->assembly;
    my $name = $genome_db->name; #get production_name
    
    my $redump_age = 30; #redump if the bed files are older than this (days)

    ##############################
    #Dump toplevel bed file

    #Check if file already exists
    my $genome_bed_file = $self->param('bed_dir') ."/" . $name . "." . $assembly . "." . "genome.bed";

    if (-e $genome_bed_file && !(-z $genome_bed_file) && (-M $genome_bed_file < $redump_age)) {
	print "$genome_bed_file already exists and not empty and is less than $redump_age days old. Not overwriting.\n";
    } else {
        #Need to dump toplevel features
        my $cmd = $self->param('dump_features') . " --url $dbc_url --species $name --feature toplevel > $genome_bed_file";
        $self->run_command($cmd, { die_on_failure => 1 });
    }

    ##############################
    #Dump coding_exon bed file
    #Check if file already exists
    my $coding_exon_bed_file = $self->param('bed_dir') ."/" . $name . "." . $assembly . "." . "coding_exon.bed";

    if (-e $coding_exon_bed_file && !(-z $coding_exon_bed_file) && (-M $coding_exon_bed_file < $redump_age)) {
	print "$coding_exon_bed_file already exists and not empty and is less than $redump_age days old. Not overwriting.\n";
    } else {
        #Need to dump toplevel features
        my $cmd = $self->param('dump_features') . " --url $dbc_url --species $name --feature coding-exons > $coding_exon_bed_file";
        $self->run_command($cmd, { die_on_failure => 1 });
    }
    return ($genome_bed_file, $coding_exon_bed_file);
}


#
#Store statistics in the method_link_species_set_tag table
#
sub write_statistics {
    my ($self, $genome_bed, $coding_exon_bed) = @_;
    my $verbose = 0;
    my $method_link_species_set = $self->compara_dba->get_MethodLinkSpeciesSetAdaptor->fetch_by_dbID($self->param('mlss_id'));
    
    if (!$method_link_species_set) {
	$self->throw(" ** ERROR **  Cannot find any MethodLinkSpeciesSet with this ID (" . $self->param('mlss_id') . ")\n");
    }

    #Fetch the number of genomic_align_blocks
    my $sql = "SELECT count(*) FROM genomic_align_block WHERE method_link_species_set_id = " . $method_link_species_set->dbID;
    my $sth = $self->compara_dba->dbc->prepare($sql);
    $sth->execute();
    my ($num_blocks) = $sth->fetchrow_array();
    $sth->finish;

    $method_link_species_set->store_tag("num_blocks", $num_blocks);

    #Calculate the genome and coding_exon statistics
    my $genome_db = $self->param('genome_db');
    my ($coverage, $coding_exon_coverage) = $self->calc_stats($self->param('dbc_url'), $genome_db, $genome_bed, $coding_exon_bed);

    #write information to method_link_species_set_tag table
    $method_link_species_set->store_tag("genome_coverage_" . $genome_db->dbID, $coverage->{both});
    $method_link_species_set->store_tag("genome_length_" . $genome_db->dbID, $coverage->{total});

    $method_link_species_set->store_tag("coding_exon_coverage_" . $genome_db->dbID, $coding_exon_coverage->{both});
    $method_link_species_set->store_tag("coding_exon_length_" . $genome_db->dbID, $coding_exon_coverage->{total});

}

#
#Calculate the statistics.
#The genome_bed file if not defined, is located in the directory given by bed_file_location 
#The alignment_bed file if not defined, is automatically created in the current directory
#compare_beds.pl $genome_bed $alignment_bed --stats
#compare_beds.pl $genome_bed $coding_exons_bed --stats
#compare_beds.pl $coding_exons_bed $alignment_bed --stats
#
sub calc_stats {
    my ($self, $dbc_url, $genome_db, $genome_bed, $coding_exon_bed) = @_;
    my $species = $genome_db->name;
    my $assembly_name = $genome_db->assembly;

    # Always construct a eHive DBConnection object because
    # $self->compara_dba may be a Core DBConnection (which lacks ->url())
    unless ($self->compara_dba->dbc->isa('Bio::EnsEMBL::Hive::DBSQL::DBConnection')) {
        bless $self->compara_dba->dbc, 'Bio::EnsEMBL::Hive::DBSQL::DBConnection';
    }
    my $compara_url = $self->compara_dba->dbc->url;

    #dump alignment_bed
    my $feature = "mlss_" . $self->param('mlss_id');
    my $alignment_bed = $self->param('output_dir') . "/" . $feature . "." . $species . ".bed";
    my $dump_features = $self->param('dump_features');
    my $cmd = "$dump_features --url $dbc_url --compara_url '$compara_url' --species $species --feature $feature > $alignment_bed";
    $self->run_command($cmd, { die_on_failure => 1 });

    #Run compare_beds.pl
    my $compare_beds = $self->param('compare_beds');
    my $coverage_data = `$compare_beds $genome_bed $alignment_bed --stats`;
    my $coverage = parse_compare_bed_output($coverage_data);
    
    my $str = "*** $species ***\n";
    $str .= sprintf "Align Coverage: %.2f%% (%d bp out of %d)\n", ($coverage->{both} / $coverage->{total} * 100), $coverage->{both}, $coverage->{total};

    #Print to job_message table
    $self->warning($str);

    print "$str\n";

    ##################
    #coding exon stats

    my $coding_exon_coverage_data = `$compare_beds $coding_exon_bed $alignment_bed --stats`;
    my $coding_exon_coverage = parse_compare_bed_output($coding_exon_coverage_data);
    
    my $coding_exon_str = "*** $species ***\n";
    $coding_exon_str .= sprintf "Align Coverage: %.2f%% (%d bp out of %d)\n", ($coding_exon_coverage->{both} / $coding_exon_coverage->{total} * 100), $coding_exon_coverage->{both}, $coding_exon_coverage->{total};

    #Print to job_message table
    $self->warning($coding_exon_str);

    print "$coding_exon_str\n";

    return ($coverage, $coding_exon_coverage);
}

#
#Parse output of compare_beds
#
sub parse_compare_bed_output {
    my ($output) = @_;
    
    my ($first_bp, $both_bp, $second_bp) = $output =~ /# FIRST: (\d*.) ; BOTH: (\d*.) ; SECOND: (\d*.)/;
    my ($first_perc, $both_perc, $second_perc) = $output =~ /# FIRST: (\d*.\d*)%; BOTH: (\d*.\d*)%; SECOND: (\d*.\d*)%/;
    my ($first_overlap, $second_overlap) = $output =~ /# FIRST OVERLAP: (\d*.\d*)%; SECOND OVERLAP: (\d*.\d*)%/;
    my $ref_total_bp = ($first_bp + $both_bp);

    my $results;
    $results->{first} = $first_bp;
    $results->{both} = $both_bp;
    $results->{second} = $second_bp;
    $results->{total} = ($first_bp+$both_bp);

    return $results;
}


1;

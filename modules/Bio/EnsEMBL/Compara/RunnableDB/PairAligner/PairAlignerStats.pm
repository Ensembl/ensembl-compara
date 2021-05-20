=head1 LICENSE

See the NOTICE file distributed with this work for additional information
regarding copyright ownership.

Licensed under the Apache License, Version 2.0 (the "License");
you may not use this file except in compliance with the License.
You may obtain a copy of the License at

     http://www.apache.org/licenses/LICENSE-2.0

Unless required by applicable law or agreed to in writing, software
distributed under the License is distributed on an "AS IS" BASIS,
WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
See the License for the specific language governing permissions and
limitations under the License.

=head1 NAME

Bio::EnsEMBL::Compara::RunnableDB::PairAligner::PairAlignerStats

=head1 DESCRIPTION

This module updates the method_link_species_set_tag table with pair aligner
statistics by firstly adding any new bed files to the correct directory and
running compare_beds to generate the statistics.

=over

=item mlss_id

Mandatory. Method link species set ID.

=item method_link_type

Mandatory (if mlss_id missing). Method link type used to retrieve the MLSS of
the given genome_db_ids.

=item genome_db_ids

Mandatory (if mlss_id missing). List of genome_db_ids used to retrieve their
MLSS.

=item bed_dir

Mandatory. Location to dump the BED files.

=item compare_beds

Mandatory. Script to compare the overlap between two BED files to generate
the stats.

=item create_pair_aligner_page

Mandatory. Script to generate the configuration parameters and coverage for a
pairwise alignment.

=item dump_features

Mandatory. Script to dump the selected features in to a BED file.

=item output_dir

Optional. Location to dump the feature BED files.

=item skip

Optional. Don't run this runnable.

=back

=head1 EXAMPLES

    standaloneJob.pl Bio::EnsEMBL::Compara::RunnableDB::PairAligner::PairAlignerStats \
        -compara_db $(mysql-ens-compara-prod-8-ensadmin details url jalvarez_plants_lastz_polyploid_99) \
        -mlss_id 9880 -bed_dir /hps/nobackup2/production/ensembl/jalvarez/plants_lastz_polyploid_99/bed_dir \
        -compare_beds $ENSEMBL_ROOT_DIR/ensembl-compara/scripts/pipeline/compare_beds.pl \
        -create_pair_aligner_page $ENSEMBL_ROOT_DIR/ensembl-compara/scripts/report/create_pair_aligner_page.pl \
        -dump_features $ENSEMBL_ROOT_DIR/ensembl-compara/scripts/dumps/dump_features.pl \
        -output_dir /hps/nobackup2/production/ensembl/jalvarez/plants_lastz_polyploid_99/feature_dumps

=cut

package Bio::EnsEMBL::Compara::RunnableDB::PairAligner::PairAlignerStats;

use strict;
use warnings;

use Bio::EnsEMBL::Hive::DBSQL::DBConnection;
use Bio::EnsEMBL::Hive::Utils qw( stringify );
use Bio::EnsEMBL::Utils::URI;

use Bio::EnsEMBL::Compara::Utils::CoreDBAdaptor;

use base ('Bio::EnsEMBL::Compara::RunnableDB::BaseRunnable');


sub fetch_input {
  my ($self) = @_;

  return if ($self->param('skip'));

  $self->param_required('bed_dir');

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
  $self->param('mlss', $mlss);

  my ($ref_genome_db, $non_ref_genome_db) = $mlss->find_pairwise_reference;
  $non_ref_genome_db //= $ref_genome_db;
  $self->param('ref_genome_db', $ref_genome_db);
  $self->param('non_ref_genome_db', $non_ref_genome_db);

  #Create url from db_adaptor
  my $ref_url = $ref_genome_db->db_adaptor->url;
  my $non_ref_url = $non_ref_genome_db->db_adaptor->url;

  $self->param('ref_dbc_url', $ref_url);
  $self->param('non_ref_dbc_url', $non_ref_url);

  $self->require_executable('dump_features');
  $self->require_executable('create_pair_aligner_page');

  return 1;
}


sub run {
  my $self = shift;

  return if ($self->param('skip'));

  return 1;
}


sub write_output {
  my ($self) = @_;

  return if ($self->param('skip'));

  # Dump bed files if necessary
  my $ref_genome_bed     = $self->dump_bed_file($self->param('ref_genome_db'), $self->param('ref_dbc_url'));
  my $non_ref_genome_bed = $self->dump_bed_file($self->param('non_ref_genome_db'), $self->param('non_ref_dbc_url'));

  
  #Create statistics
  $self->write_pairaligner_statistics($ref_genome_bed, $non_ref_genome_bed);

  #
  #Create jobs for 'coding_exon_stats' on branch 2
  #

  my $dnafrag_adaptor = $self->compara_dba->get_DnaFragAdaptor;

  my $ref_genome_db = $self->param('ref_genome_db');
  my $non_ref_genome_db = $self->param('non_ref_genome_db');
  my $mlss_id = $self->param('mlss_id');
  my $ref_dnafrags = $dnafrag_adaptor->fetch_all_by_GenomeDB($ref_genome_db, -IS_REFERENCE => 1);
  my $non_ref_dnafrags = $dnafrag_adaptor->fetch_all_by_GenomeDB($non_ref_genome_db, -IS_REFERENCE => 1);

  my $output_hash = {};
  foreach my $dnafrag (@$ref_dnafrags) {
      %$output_hash = ('mlss_id' => $mlss_id,
                       'dnafrag_id' => $dnafrag->dbID);
      $self->dataflow_output_id($output_hash,2);
  }

  foreach my $dnafrag (@$non_ref_dnafrags) {
      %$output_hash = ('mlss_id' => $mlss_id,
                       'dnafrag_id' => $dnafrag->dbID);
      $self->dataflow_output_id($output_hash,2);
  }

  return 1;
}


#
#Write bed file to general repository for a new species or assembly. The naming scheme assumes the format
#production_name(.component_name).dbID.genome.bed for toplevel regions and #production_name(.component_name).dbID.coding_exons.bed for exonic
#regions. If a file of that convention already exists, it will not be overwritten.
#
sub dump_bed_file {
    my ($self, $genome_db, $dbc_url) = @_;

    my $name = $genome_db->_get_unique_name; #get production_name
    my $species_arg   = "--species ".$genome_db->name;
       $species_arg  .= " --component ".$genome_db->genome_component if $genome_db->genome_component;
    
    #Check if file already exists
    my $genome_bed_file = $self->param('bed_dir') ."/" . $name . "." . $genome_db->dbID . "." . "genome.bed";

    if (-e $genome_bed_file && !(-z $genome_bed_file)) {
	print "$genome_bed_file already exists and not empty. Not overwriting.\n";
    } else {
        #Need to dump toplevel features
        my $cmd = $self->param('dump_features') . " --url \"$dbc_url\" $species_arg --feature toplevel > $genome_bed_file";
        $self->run_command($cmd, { die_on_failure => 1 });
    }

    return $genome_bed_file;
}


#
#Store pair-aligner statistics in pair_aligner_statistics table
#
sub write_pairaligner_statistics {
    my ($self, $ref_genome_bed, $non_ref_genome_bed) = @_;
    my $verbose = 0;
    my $method_link_species_set = $self->param_required('mlss');

    #Fetch the number of genomic_align_blocks
    my $sql = "SELECT count(*) FROM genomic_align_block WHERE method_link_species_set_id = " . $method_link_species_set->dbID;
    my $num_blocks = $self->compara_dba->dbc->sql_helper->execute_single_result( -SQL => $sql );

    $method_link_species_set->store_tag("num_blocks", $num_blocks);

    #Find the reference and non-reference genome_db
    my $species_set = $method_link_species_set->species_set->genome_dbs();

    my $ref_dbc_url = $self->param('ref_dbc_url');
    my $non_ref_dbc_url = $self->param('non_ref_dbc_url');

    #Calculate the statistics
    my $ref_coverage = $self->calc_stats($ref_dbc_url, $self->param('ref_genome_db'), $ref_genome_bed);

    my $non_ref_coverage = (@$species_set == 1) ? $ref_coverage : $self->calc_stats($non_ref_dbc_url, $self->param('non_ref_genome_db'), $non_ref_genome_bed);
   
    #write information to method_link_species_set_tag table

    $method_link_species_set->store_tag("ref_genome_coverage", $ref_coverage->{both});
    $method_link_species_set->store_tag("ref_genome_length", $ref_coverage->{total});
    $method_link_species_set->store_tag("non_ref_genome_coverage", $non_ref_coverage->{both});
    $method_link_species_set->store_tag("non_ref_genome_length", $non_ref_coverage->{total});

    # Distribution of the block sizes
    my $sql_nets = 'SELECT POW(10,FLOOR(LOG10(tot_length))) AS rounded_length, COUNT(*), SUM(tot_length) FROM ( SELECT SUM(length) AS tot_length FROM genomic_align_block WHERE method_link_species_set_id = ? GROUP BY group_id) t GROUP BY rounded_length;';
    my $sql_chains = 'SELECT POW(10,FLOOR(LOG10(length))) AS rounded_length, COUNT(*), SUM(length) FROM genomic_align_block WHERE method_link_species_set_id = ? GROUP BY rounded_length;';

    $self->store_mlss_tag_block_size($method_link_species_set, 'chains', $sql_chains);
    $self->store_mlss_tag_block_size($method_link_species_set, 'nets', $sql_nets);

}

sub store_mlss_tag_block_size {
    my ($self, $mlss, $block_type, $query) = @_;
    my ($array_ref) = $self->compara_dba->dbc->db_handle->selectall_arrayref($query, undef, $self->param('mlss_id'));
    foreach my $r (@$array_ref) {
        $mlss->store_tag("num_${block_type}_blocks_$r->[0]", $r->[1]);
        $mlss->store_tag("totlength_${block_type}_blocks_$r->[0]", $r->[2]);
    }
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
    my ($self, $dbc_url, $genome_db, $genome_bed) = @_;

    my $species = $genome_db->_get_unique_name . "_" . $genome_db->dbID;

    my $compara_url = Bio::EnsEMBL::Hive::DBSQL::DBConnection->new(-dbconn => $self->compara_dba->dbc)->url;

    #dump alignment_bed
    my $feature = "mlss_" . $self->param('mlss_id');
    my $alignment_bed = $self->param('output_dir') . "/" . $feature . "." . $species . ".bed";
    my $dump_features = $self->param('dump_features');
    my $species_arg   = "--species ".$genome_db->name;
       $species_arg  .= " --component ".$genome_db->genome_component if $genome_db->genome_component;
    my $cmd = "$dump_features --url \"$dbc_url\" --compara_url '$compara_url' $species_arg --feature $feature > $alignment_bed";
    $self->run_command($cmd, { die_on_failure => 1 });

    #Run compare_beds.pl
    $cmd = [$self->param_required('compare_beds'), $genome_bed, $alignment_bed, '--stats'];
    my $coverage_data = $self->get_command_output($cmd);
    my $coverage = parse_compare_bed_output($coverage_data);
    
    my $str = "*** $species ***\n";
    $str .= sprintf "Align Coverage: %.2f%% (%d bp out of %d)\n", ($coverage->{both} / $coverage->{total} * 100), $coverage->{both}, $coverage->{total};

    #Print to job_message table
    $self->warning($str);

    print "$str\n";
    return $coverage;
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

#
#Run script to create the html and png files for the web. These are written to the current directory 
#and will need to be copied to the correct location.
#
sub run_create_pair_aligner_page {
    my ($self) = @_;

    if (!$self->param('config_url')) {
	print "Must before config_url to print out the page information. Stats info is written to the job_message table\n";
	return;
    }

    my $cmd = "perl " . $self->param('create_pair_aligner_page') . 
      " --config_url " . $self->param('config_url') . 
      " --mlss_id " . $self->param('mlss_id');

    $cmd .= " --ucsc_url " . $self->param('ucsc_url') if ($self->param('ucsc_url'));
    $cmd .= " > ./mlss_" . $self->param('mlss_id') . ".html";

    $self->run_command($cmd, { die_on_failure => 1 });
}


1;

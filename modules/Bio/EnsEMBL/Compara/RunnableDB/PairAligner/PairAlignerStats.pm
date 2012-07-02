=head1 LICENSE

  Copyright (c) 1999-2012 The European Bioinformatics Institute and
  Genome Research Limited.  All rights reserved.

  This software is distributed under a modified Apache license.
  For license details, please see

    http://www.ensembl.org/info/about/code_licence.html

=head1 CONTACT

  Please email comments or questions to the public Ensembl
  developers list at <dev@ensembl.org>.

  Questions may also be sent to the Ensembl help desk at
  <helpdesk@ensembl.org>.

=head1 NAME

Bio::EnsEMBL::Compara::RunnableDB::PairAlignerConfig

=cut

=head1 SYNOPSIS

$module->fetch_input

$module->run

$module->write_output

=cut

=head1 DESCRIPTION

This module updates the method_link_species_set_tag table with pair aligner statistics by firstly adding any new bed files to the correct directory and running compare_beds to generate the statistics

=head1 APPENDIX

The rest of the documentation details each of the object methods.
Internal methods are usually preceded with a _

=cut

package Bio::EnsEMBL::Compara::RunnableDB::PairAligner::PairAlignerStats;

use strict;
use Bio::EnsEMBL::Hive::Utils 'stringify';  # import 'stringify()'

use base ('Bio::EnsEMBL::Compara::RunnableDB::BaseRunnable');

=head2 fetch_input

  Implementation of the Bio::EnsEMBL::Hive::Process interface

=cut

sub fetch_input {
  my ($self) = @_;

  return if ($self->param('skip'));
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
	  $mlss = $mlss_adaptor->fetch_by_method_link_type_genome_db_ids($self->param('method_link_type'), eval($self->param('genome_db_ids')));
	  $self->param('mlss_id', $mlss->dbID);
      } else {
	  die("must define either mlss_id or method_link_type and genome_db_ids");
      }
  }

  $self->param('ref_species', $mlss->get_value_for_tag("reference_species"));
  $self->param('non_ref_species', $mlss->get_value_for_tag("non_reference_species"));

  my $genome_db_adaptor = $self->compara_dba->get_GenomeDBAdaptor;

  my $ref_genome_db = $genome_db_adaptor->fetch_by_registry_name($self->param('ref_species'));
  my $non_ref_genome_db = $genome_db_adaptor->fetch_by_registry_name($self->param('non_ref_species'));


  my $ref_db = $ref_genome_db->db_adaptor;
  my $non_ref_db = $non_ref_genome_db->db_adaptor;

  #Modify url to make it a valid core url
  $self->param('ref_dbc_url', $ref_db->dbc->url . "?group=core\\&species=" . $self->param('ref_species'));
  $self->param('non_ref_dbc_url', $non_ref_db->dbc->url . "?group=core\\&species=" . $self->param('non_ref_species'));

  my $perl_path = $ENV{'ENSEMBL_CVS_ROOT_DIR'};

  #Set up paths to various perl scripts
  unless ($self->param('dump_features')) {
      $self->param('dump_features', $perl_path . "/ensembl-compara/scripts/dumps/dump_features.pl");
  }
  
  unless (-e $self->param('dump_features')) {
      die(self->param('dump_features') . " does not exist");
  }
  
  unless ($self->param('create_pair_aligner_page')) {
      $self->param('create_pair_aligner_page', $perl_path . "/ensembl-compara/scripts/pipeline/create_pair_aligner_page.pl");
  }
  unless (-e $self->param('create_pair_aligner_page')) {
      die($self->param('create_pair_aligner_page') . " does not exist");
  }

  #Get ensembl schema version from meta table if not defined
  if (!defined $self->param('ensembl_release')) {
      $self->param('ensembl_release', $self->compara_dba->get_MetaContainer->list_value_by_key("schema_version")->[0]);
  }

  return 1;
}

=head2 run

=cut

sub run {
  my $self = shift;

  return if ($self->param('skip'));

  return 1;
}


=head2 write_output

=cut

sub write_output {
  my ($self) = @_;

  return if ($self->param('skip'));

  #Dump bed files if necessary
  my ($ref_genome_bed, $ref_coding_exons_bed) = $self->dump_bed_file($self->param('ref_species'), $self->param('ref_dbc_url'), $self->param('reg_conf'));
  my ($non_ref_genome_bed, $non_ref_coding_exons_bed) = $self->dump_bed_file($self->param('non_ref_species'), $self->param('non_ref_dbc_url'), $self->param('reg_conf'));

  
  #Create statistics
  $self->write_pairaligner_statistics($ref_genome_bed, $ref_coding_exons_bed, $non_ref_genome_bed, $non_ref_coding_exons_bed);

  #Create the pair aligner html and png files for display on the web
  #$self->run_create_pair_aligner_page();

  return 1;
}


#
#Write bed file to general repository for a new species or assembly. The naming scheme assumes the format
#production_name.assembly.genome.bed for toplevel regions and production_name.assembly.coding_exons.bed for exonic
#regions. If a file of that convention already exists, it will not be overwritten.
#
sub dump_bed_file {
    my ($self, $species, $dbc_url, $reg_conf) = @_;

    #Need assembly
    my $genome_db = $self->compara_dba->get_GenomeDBAdaptor->fetch_by_registry_name($species);
    my $assembly = $genome_db->assembly;
    my $name = $genome_db->name; #get production_name
    
    #Check if file already exists
    my $genome_bed_file = $self->param('bed_dir') ."/" . $name . "." . $assembly . "." . "genome.bed";
    my $exon_bed_file = $self->param('bed_dir') . "/" . $name . "." . $assembly . "." . "coding_exons.bed";

    if (-e $genome_bed_file && !(-z $genome_bed_file)) {
	print "$genome_bed_file already exists and not empty. Not overwriting.\n";
    } else {
	#Need to dump toplevel features
	my $compara_url = $self->compara_dba->dbc->url;
	my $cmd = $self->param('dump_features') . " --url $dbc_url --species $name --feature toplevel > $genome_bed_file";

	unless (system($cmd) == 0) {
	    die("$cmd execution failed\n");
	}
    }
    
    #Always overwrite the coding exon file since this will usually be updated each release for human
    if (-e $exon_bed_file) {
#	print "$exon_bed_file already exists. Overwriting.\n";
	print "$exon_bed_file already exists and not empty. Not overwriting.\n";
#    }
    } else {
	my $cmd = $self->param('dump_features') . " --url $dbc_url --species $name --feature coding-exons > $exon_bed_file";
	unless (system($cmd) == 0) {
	    die("$cmd execution failed\n");
	}
    }
    return ($genome_bed_file, $exon_bed_file);
}


#
#Store pair-aligner statistics in pair_aligner_statistics table
#
sub write_pairaligner_statistics {
    my ($self, $ref_genome_bed, $ref_coding_exons_bed, $non_ref_genome_bed, $non_ref_coding_exons_bed) = @_;
    my $verbose = 0;
    my $method_link_species_set = $self->compara_dba->get_MethodLinkSpeciesSetAdaptor->fetch_by_dbID($self->param('mlss_id'));
    
    if (!$method_link_species_set) {
	print " ** ERROR **  Cannot find any MethodLinkSpeciesSet with this ID (" . $self->param('mlss_id') . ")\n";
	exit(1);
    }

    #Fetch the number of genomic_align_blocks
    my $sql = "SELECT count(*) FROM genomic_align_block WHERE method_link_species_set_id = " . $method_link_species_set->dbID;
    my $sth = $self->compara_dba->dbc->prepare($sql);
    $sth->execute();
    my ($num_blocks) = $sth->fetchrow_array();

    $method_link_species_set->store_tag("ensembl_release", $self->param('ensembl_release'));
    
    $method_link_species_set->store_tag("num_blocks", $num_blocks);

    #Find the reference and non-reference genome_db
    my $species_set = $method_link_species_set->species_set_obj->genome_dbs();

    my $genome_db_adaptor = $self->compara_dba->get_GenomeDBAdaptor;
    my $ref_genome_db = $genome_db_adaptor->fetch_by_registry_name($self->param('ref_species'));
    my $non_ref_genome_db = $genome_db_adaptor->fetch_by_registry_name($self->param('non_ref_species'));

    my $ref_dbc_url = $self->param('ref_dbc_url');
    my $non_ref_dbc_url = $self->param('non_ref_dbc_url');

    #self alignments
    if (@$species_set == 1) {
	$non_ref_genome_db = $ref_genome_db;
	$non_ref_dbc_url = $ref_dbc_url;
    }


    #Calculate the statistics
    my ($ref_coverage, $ref_coding_coverage, $ref_alignment_coding) = $self->calc_stats($ref_dbc_url, $ref_genome_db, $ref_genome_bed, $ref_coding_exons_bed);

    my ($non_ref_coverage, $non_ref_coding_coverage, $non_ref_alignment_coding) = $self->calc_stats($non_ref_dbc_url, $non_ref_genome_db, $non_ref_genome_bed, $non_ref_coding_exons_bed);
   
    #write information to method_link_species_set_tag table

#    my $pairwise_lengths;
#    %$pairwise_lengths = ('ref_genome_length'     => $ref_coverage->{total},
#			  'non_ref_genome_length' => $non_ref_coverage->{total},
#			  'ref_coding_length'     => $ref_coding_coverage->{both},
#			  'non_ref_coding_length' => $non_ref_coding_coverage->{both});
#    my $pairwise_coverage;
#    %$pairwise_coverage = ('ref_genome_coverage'     => $ref_coverage->{both},
#			   'non_ref_genome_coverage' => $non_ref_coverage->{both},
#			   'ref_coding_coverage'     => $ref_alignment_coding->{both},
#			   'non_ref_coding_coverage' => $non_ref_alignment_coding->{both});
#
#    $method_link_species_set->store_tag("pairwise_lengths", stringify($pairwise_lengths));
#    $method_link_species_set->store_tag("pairwise_coverage", stringify($pairwise_coverage));


    $method_link_species_set->store_tag("ref_genome_coverage", $ref_coverage->{both});
    $method_link_species_set->store_tag("ref_genome_length", $ref_coverage->{total});
    $method_link_species_set->store_tag("non_ref_genome_coverage", $non_ref_coverage->{both});
    $method_link_species_set->store_tag("non_ref_genome_length", $non_ref_coverage->{total});

    $method_link_species_set->store_tag("ref_coding_coverage", $ref_alignment_coding->{both});
    $method_link_species_set->store_tag("ref_coding_length", $ref_coding_coverage->{both});
    $method_link_species_set->store_tag("non_ref_coding_coverage", $non_ref_alignment_coding->{both});
    $method_link_species_set->store_tag("non_ref_coding_length", $non_ref_coding_coverage->{both});

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
    my ($self, $dbc_url, $genome_db, $genome_bed, $coding_exons_bed) = @_;
    my $species = $genome_db->name;
    my $assembly_name = $genome_db->assembly;

    my $compara_url = $self->compara_dba->dbc->url;

    #dump alignment_bed
    my $feature = "mlss_" . $self->param('mlss_id');
    my $alignment_bed = $self->param('output_dir') . "/" . $feature . "." . $species . ".bed";
    my $dump_features = $self->param('dump_features');

    unless (system("$dump_features --url $dbc_url --compara_url $compara_url --species $species --feature $feature > $alignment_bed") == 0) {
	throw("$dump_features --url $dbc_url --compara_url $compara_url --species $species --feature $feature execution failed\n");
    }

    #Run compare_beds.pl
    my $compare_beds = $self->param('compare_beds');
    my $coverage_data = `$compare_beds $genome_bed $alignment_bed --stats`;
    my $coding_coverage_data = `$compare_beds $genome_bed $coding_exons_bed --stats`;
    my $alignment_coding_data = `$compare_beds $coding_exons_bed $alignment_bed --stats`;

    my $coverage = parse_compare_bed_output($coverage_data);
    my $coding_coverage = parse_compare_bed_output($coding_coverage_data);
    my $alignment_coding = parse_compare_bed_output($alignment_coding_data);
    
    my $str = "*** $species ***\n";
    $str .= sprintf "Align Coverage: %.2f%% (%d bp out of %d)\n", ($coverage->{both} / $coverage->{total} * 100), $coverage->{both}, $coverage->{total};

    $str .= sprintf "CodExon Coverage: %.2f%% (%d bp out of %d)\n", ($coding_coverage->{both} / $coverage->{total}* 100), $coding_coverage->{both}, $coverage->{total};
    
    $str .= sprintf "Align Overlap: %.2f%% of aligned bp correspond to coding exons (%d bp out of %d)\n", ($alignment_coding->{both} / $coverage->{both} * 100), $alignment_coding->{both}, $coverage->{both};

    $str .= sprintf "CodExon Overlap: %.2f%% of coding bp are covered by alignments (%d bp out of %d)\n", ($alignment_coding->{both} / $coding_coverage->{both} * 100), $alignment_coding->{both}, $coding_coverage->{both};

    #Print to job_message table
    $self->warning($str);

    print "$str\n";
    return ($coverage, $coding_coverage, $alignment_coding);
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

    unless (system($cmd) == 0) {
	die("$cmd execution failed\n");
    }
}

1;

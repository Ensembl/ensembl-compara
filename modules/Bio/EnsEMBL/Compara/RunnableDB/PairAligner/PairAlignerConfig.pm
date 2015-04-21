=head1 LICENSE

Copyright [1999-2015] Wellcome Trust Sanger Institute and the EMBL-European Bioinformatics Institute

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

Bio::EnsEMBL::Compara::RunnableDB::PairAlignerConfig

=cut

=head1 SYNOPSIS

$module->fetch_input

$module->run

$module->write_output

=cut

=head1 DESCRIPTION

This module is intended to update the pair_aligner_conf database by firstly adding any new bed files to the correct directory and running compare_beds to generate the statistics

=head1 OPTIONS

=over

=item ref_species

Reference species

=item reg_conf

Registry configuration file if not able to provide ref_dbc_url or non_ref_dbc_url (eg local genebuild database)

=item [method_link_type]

method_link_type for the multiple alignments.

=item [genome_db_ids]

List of genome_dbs, should be 2 for a pairwise alignment

=item [mlss_id]

Method link species set id for the pairwise alignment

=item bed_dir

Location of directory to write any new bed files

=item config_url

Location of the pair aligner configuration database

=item config_file

Location of the pair aligner configuration file containing the RAW analysis parameters (if not the input conf_file)

=item perl_path

Location of ensembl-compara directory

=item ensembl_release

Ensembl release if not the same as contained in the pair aligner compara database in the meta table

=back

=head1 EXAMPLES

=over

=item {'ref_species' => 'danio_rerio', 'method_link_type'=>'TRANSLATED_BLAT_NET', 'genome_db_ids'=>'[65,110]', 'bed_dir' => '/lustre/scratch103/ensembl/kb3/scratch/tests/test_config/pipeline', 'config_url' => 'mysql://USER:PASS@compara1:3306/kb3_pair_aligner_config_test', 'config_file' => '/nfs/users/nfs_k/kb3/work/projects/tests/test_config/tblat.conf',}

=back

=head1 APPENDIX

The rest of the documentation details each of the object methods.
Internal methods are usually preceded with a _

=cut

package Bio::EnsEMBL::Compara::RunnableDB::PairAligner::PairAlignerConfig;

use strict;
use Bio::EnsEMBL::Hive::Utils 'stringify';  # import 'stringify()'

use base ('Bio::EnsEMBL::Compara::RunnableDB::BaseRunnable');

=head2 fetch_input

  Implementation of the Bio::EnsEMBL::Hive::Process interface

=cut

sub fetch_input {
  my ($self) = @_;

  return if ($self->param('skip_pairaligner_config'));

  #Default directory containing bed files.
  if (!defined $self->param('bed_dir')) {
      $self->param('bed_dir', "/nfs/ensembl/compara/dumps/bed/");
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

  #Find the non_ref_species name
  if (!defined $self->param('non_ref_species')) {
      my $species_set = $mlss->species_set_obj->genome_dbs;

      if (@$species_set == 1) {
	  $self->param('non_ref_species', $self->param('ref_species'));
      }
      foreach my $genome_db (@$species_set) {
	  if ($self->param('ref_species') ne $genome_db->name) {
	      $self->param('non_ref_species', $genome_db->name);
	  }
      }
  }
  my $genome_db_adaptor = $self->compara_dba->get_GenomeDBAdaptor;

  my $ref_genome_db = $genome_db_adaptor->fetch_by_registry_name($self->param('ref_species'));
  my $non_ref_genome_db = $genome_db_adaptor->fetch_by_registry_name($self->param('non_ref_species'));

  #Get ref_dbc_url and non_ref_dbc_url from genome_db table
  #unless ($self->param('ref_dbc_url')) {
      my $ref_db = $ref_genome_db->db_adaptor;
      #$self->param('ref_db', $ref_db);

      #This doesn't not produce a valid "core" url ie it appends the database name instead of just the db_version so
      #load_registry_from_url doesn't work but it is useful to store the database info
      $self->param('ref_dbc_url', $ref_db->dbc->url);
  #}
  #unless ($self->param('non_ref_dbc_url')) {

      my $non_ref_db = $non_ref_genome_db->db_adaptor;
      #$self->param('non_ref_db', $non_ref_db);

      #This doesn't not produce a valid "core" url ie it appends the database name instead of just the db_version so
      #load_registry_from_url doesn't work but it is useful to store the database info
      $self->param('non_ref_dbc_url', $non_ref_db->dbc->url);
  #}

  #Set up paths to various perl scripts
  unless ($self->param('dump_features')) {
      $self->param('dump_features', $self->param('perl_path') . "/scripts/dumps/dump_features.pl");
  }
  
  unless (-e $self->param('dump_features')) {
      die(self->param('dump_features') . " does not exist");
  }
  
  unless ($self->param('update_config_database')) {
      $self->param('update_config_database', $self->param('perl_path') . "/scripts/pipeline/update_config_database.pl");
  }
  
  unless (-e $self->param('update_config_database')) {
      die(self->param('update_config_database') . " does not exist");
  }
  
  unless ($self->param('create_pair_aligner_page')) {
      $self->param('create_pair_aligner_page', $self->param('perl_path') . "/scripts/pipeline/create_pair_aligner_page.pl");
  }
  unless (-e $self->param('create_pair_aligner_page')) {
      die(self->param('create_pair_aligner_page') . " does not exist");
  }

  #Get ensembl schema version from meta table if not defined
  if (!defined $self->param('ensembl_release')) {
      $self->param('ensembl_release', $self->compara_dba->get_MetaContainer->get_schema_version());
  }

  return 1;
}

=head2 run

  Implementation of the Bio::EnsEMBL::Hive::Process interface

=cut

sub run {
  my $self = shift;

  return if ($self->param('skip_pairaligner_config'));

  #Dump bed files if necessary
  $self->dump_bed_file($self->param('ref_species'), $self->param('ref_dbc_url'), $self->param('reg_conf'));
  $self->dump_bed_file($self->param('non_ref_species'), $self->param('non_ref_dbc_url'), $self->param('reg_conf'));

  
  #Update the pair aligner configuaration database
  $self->run_update_config_database();
  
  #Create the pair aligner html and png files for display on the web
  $self->run_create_pair_aligner_page();

  return 1;
}


=head2 write_output

  Implementation of the Bio::EnsEMBL::Hive::Process interface

=cut

sub write_output {
  my ($self) = @_;

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
        my $cmd;
        my $compara_url = $self->compara_dba->dbc->url;
        if ($reg_conf) {
            #Need to define compara_url even though it isn't used to stop dump_features complaining
            $cmd = $self->param('dump_features') . " --reg_conf $reg_conf --species $name --feature toplevel --compara_url '$compara_url' > $genome_bed_file";
        } else {
            #Non-standard core name. Use DBAdaptor info
            my ($user, $host, $port, $dbname) = $dbc_url =~ /mysql:\/\/(\w*)@(.*):(\d*)\/(\w+)/;
            $cmd = $self->param('dump_features') . " --host $host --user $user --port $port --dbname $dbname --species $name --feature toplevel > $genome_bed_file";
        }
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
	my $cmd;
	if ($reg_conf) {
	    $cmd = $self->param('dump_features') . " --reg_conf " . $reg_conf ." --species $name --feature coding-exons > $exon_bed_file";
	} else {
	    #Non-standard core name. Use DBAdaptor info
	    my ($user, $host, $port, $dbname) = $dbc_url =~ /mysql:\/\/(\w*)@(.*):(\d*)\/(\w+)/;
	    $cmd = $self->param('dump_features') . " --host $host --user $user --port $port --dbname $dbname --species $name --feature coding-exons > $exon_bed_file";
	}
	unless (system($cmd) == 0) {
	    die("$cmd execution failed\n");
	}
    }
}

#
#Run script to update the pair aligner configuration database
#
sub run_update_config_database {
    my ($self) = @_;

    my $cmd = "perl " . $self->param('update_config_database') . 
      " --ref_species " . $self->param('ref_species') . 
      " --compara_url '" . $self->compara_dba->dbc->url . "'" .
      " --mlss_id " . $self->param('mlss_id') . 
      " --ensembl_release " . $self->param('ensembl_release');

    $cmd .= " --config_url " . $self->param('config_url') if ($self->param('config_url'));
    $cmd .= " --config_file " . $self->param('config_file') if ($self->param('config_file')); 
    $cmd .= " --ref_dbc_url '" . $self->param('ref_dbc_url') ."'" if ($self->param('ref_dbc_url'));
    $cmd .= " --non_ref_dbc_url '" . $self->param('non_ref_dbc_url') ."'" if ($self->param('non_ref_dbc_url'));
    $cmd .= " --reg_conf " . $self->param('reg_conf') if ($self->param('reg_conf'));
    $cmd .= " --output_dir " . $self->param('output_dir') if ($self->param('output_dir'));
    $cmd .= " --pair_aligner_options \'" . $self->param('pair_aligner_options') ."\'" if ($self->param('pair_aligner_options')) ;
    $cmd .= " --ref_dna_collection \'" . stringify($self->param('ref_dna_collection')) ."\'" if ($self->param('ref_dna_collection'));
    $cmd .= " --non_ref_dna_collection \'" . stringify($self->param('non_ref_dna_collection')) ."\'" if ($self->param('non_ref_dna_collection'));
    $cmd .= " --bed_file_location " . $self->param('bed_dir') if ($self->param('bed_dir'));

    print "$cmd\n";
    my $output;
    $output = `$cmd 2>&1`;
    $self->warning($output);
    unless ($?== 0) {
	die("$cmd execution failed\n");
    }
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

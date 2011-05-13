#
# You may distribute this module under the same terms as perl itself
#
# POD documentation - main docs before the code

=pod

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


=item ref_species

Reference species

=item ref_url

Location of the core database for the reference species

=item non_ref_url

Location of the core database for the non-reference species (if different from the ref_url)

=item reg_conf

Registry configuration file if not able to provide ref_url or non_ref_url (eg local genebuild database)

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

=item {'ref_species' => 'danio_rerio', 'ref_url' =>'mysql://USER@ens-livemirror:3306/60', 'non_ref_url' => 'mysql://USER@ens-livemirror:3306/59', 'method_link_type'=>'TRANSLATED_BLAT_NET', 'genome_db_ids'=>'[65,110]', 'bed_dir' => '/lustre/scratch103/ensembl/kb3/scratch/tests/test_config/pipeline', 'config_url' => 'mysql://USER:PASS@compara1:3306/kb3_pair_aligner_config_test', 'config_file' => '/nfs/users/nfs_k/kb3/work/projects/tests/test_config/tblat.conf',}

=back

=head1 CONTACT

Kathryn Beal <kbeal@ebi.ac.uk>

=cut

=head1 APPENDIX

The rest of the documentation details each of the object methods.
Internal methods are usually preceded with a _

=cut

package Bio::EnsEMBL::Compara::RunnableDB::PairAlignerConfig;

use strict;
use Bio::EnsEMBL::Compara::Production::DBSQL::DBAdaptor;
use Bio::EnsEMBL::Utils::Exception;

use Bio::EnsEMBL::Hive::Process;

our @ISA = qw(Bio::EnsEMBL::Hive::Process);


=head2 fetch_input

  Implementation of the Bio::EnsEMBL::Hive::Process interface

=cut

sub fetch_input {
  my ($self) = @_;

  $self->{'comparaDBA'} = Bio::EnsEMBL::Compara::Production::DBSQL::DBAdaptor->new(-DBCONN=>$self->db->dbc);
  $self->{'hiveDBA'} = Bio::EnsEMBL::Hive::DBSQL::DBAdaptor->new(-DBCONN => $self->{'comparaDBA'}->dbc);
  $self->get_params($self->parameters);
  $self->get_params($self->input_id);

  #Default directory containing bed files.
  if (!defined $self->bed_dir) {
      $self->bed_dir("/nfs/ensembl/compara/dumps/bed/");
  }

  #Find the mlss_id from the method_link_type and genome_db_ids
  my $mlss;
  if (!defined $self->mlss_id) {
      if (defined $self->method_link_type && $self->genome_db_ids) {
	  my $mlss_adaptor = $self->{'comparaDBA'}->get_MethodLinkSpeciesSetAdaptor;
	  throw ("No method_link_species_set") if (!$mlss_adaptor);
	  $mlss = $mlss_adaptor->fetch_by_method_link_type_genome_db_ids($self->method_link_type, eval($self->genome_db_ids));
	  $self->mlss_id($mlss->dbID);
      } else {
	  throw("must define either mlss_id or method_link_type and genome_db_ids");
      }
  }

  #Find the non_ref_species name
  if (!defined $self->non_ref_species) {
      my $species_set = $mlss->species_set;
      foreach my $genome_db (@$species_set) {
	  if ($self->ref_species ne $genome_db->name) {
	      $self->non_ref_species($genome_db->name);
	  }
      }
  }

  #Set up paths to various perl scripts
  $self->dump_features($self->perl_path . "/scripts/dumps/dump_features.pl");
  unless (-e $self->dump_features) {
      throw(self->dump_features . " does not exist");
  }

  $self->update_config_database($self->perl_path . "/scripts/pipeline/update_config_database.pl");
  unless (-e $self->update_config_database) {
      throw(self->update_config_database . " does not exist");
  }

  $self->create_pair_aligner_page($self->perl_path . "/scripts/pipeline/create_pair_aligner_page.pl");
  unless (-e $self->create_pair_aligner_page) {
      throw(self->create_pair_aligner_page . " does not exist");
  }

  #Get ensembl schema version from meta table if not defined
  if (!defined $self->ensembl_release) {
      $self->ensembl_release($self->{'comparaDBA'}->get_MetaContainer->list_value_by_key("schema_version")->[0]);
  }

  return 1;
}

=head2 run

  Implementation of the Bio::EnsEMBL::Hive::Process interface

=cut

sub run {
  my $self = shift;

  #Dump bed files if necessary
  $self->dump_bed_file($self->ref_species, $self->ref_url, $self->reg_conf);
  $self->dump_bed_file($self->non_ref_species, $self->non_ref_url, $self->reg_conf);

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


=head2 get_params

  Arg [1]     : (optional) string $parameters
  Example     : $self->get_params("{blah=>'foo'}");
  Description : Reads and parses a string representing a hash
                with parameters for this job.
  Returntype  :
  Exceptions  : none
  Caller      : fetch_input
  Status      : Stable

=cut

sub get_params {
  my $self         = shift;
  my $param_string = shift;

  return unless($param_string);

  my $params = eval($param_string);
  return unless($params);

  if (defined($params->{'bed_dir'})) {
    $self->bed_dir($params->{'bed_dir'});
  }

  if (defined($params->{'ref_species'})) {
    $self->ref_species($params->{'ref_species'});
  }

  if (defined($params->{'ref_url'})) {
    $self->ref_url($params->{'ref_url'});
  }

  if (defined($params->{'non_ref_url'})) {
    $self->non_ref_url($params->{'non_ref_url'});
  }

  if (defined($params->{'reg_conf'})) {
    $self->reg_conf($params->{'reg_conf'});
  }

  if (defined($params->{'config_url'})) {
    $self->config_url($params->{'config_url'});
  }

  if (defined($params->{'config_file'})) {
    $self->config_file($params->{'config_file'});
  }

  if (defined($params->{'mlss_id'})) {
      $self->mlss_id($params->{'mlss_id'});
  }

  if (defined($params->{'method_link_type'})) {
      $self->method_link_type($params->{'method_link_type'});
  }

  if (defined($params->{'genome_db_ids'})) {
      $self->genome_db_ids($params->{'genome_db_ids'});
  }

  if (defined($params->{'perl_path'})) {
      $self->perl_path($params->{'perl_path'});
  }

  if (defined($params->{'ensembl_release'})) {
      $self->ensembl_release($params->{'ensembl_release'});
  }

  return 1;
}

sub ref_species {
  my $self = shift;
  if (@_) {
    $self->{_ref_species} = shift;
  }
  return $self->{_ref_species};
}

sub ref_url {
  my $self = shift;
  if (@_) {
    $self->{_ref_url} = shift;
  }
  return $self->{_ref_url};
}

sub reg_conf {
  my $self = shift;
  if (@_) {
    $self->{_reg_conf} = shift;
  }
  return $self->{_reg_conf};
}

sub non_ref_species {
  my $self = shift;
  if (@_) {
    $self->{_non_ref_species} = shift;
  }
  return $self->{_non_ref_species};
}

sub non_ref_url {
  my $self = shift;
  if (@_) {
    $self->{_non_ref_url} = shift;
  }
  return $self->{_non_ref_url};
}

sub config_url {
  my $self = shift;
  if (@_) {
    $self->{_config_url} = shift;
  }
  return $self->{_config_url};
}

sub mlss_id {
  my $self = shift;
  if (@_) {
    $self->{_mlss_id} = shift;
  }
  return $self->{_mlss_id};
}
sub method_link_type {
  my $self = shift;
  if (@_) {
    $self->{_method_link_type} = shift;
  }
  return $self->{_method_link_type};
}
sub genome_db_ids {
  my $self = shift;
  if (@_) {
    $self->{_genome_db_ids} = shift;
  }
  return $self->{_genome_db_ids};
}

sub dump_features {
  my $self = shift;
  if (@_) {
    $self->{_dump_features} = shift;
  }
  return $self->{_dump_features};
}

sub update_config_database {
  my $self = shift;
  if (@_) {
    $self->{_update_config_database} = shift;
  }
  return $self->{_update_config_database};
}

sub bed_dir {
  my $self = shift;
  if (@_) {
    $self->{_bed_dir} = shift;
  }
  return $self->{_bed_dir};
}

sub config_file {
  my $self = shift;
  if (@_) {
    $self->{_config_file} = shift;
  }
  return $self->{_config_file};
}

sub ensembl_release {
  my $self = shift;
  if (@_) {
    $self->{_ensembl_release} = shift;
  }
  return $self->{_ensembl_release};
}

sub perl_path {
  my $self = shift;
  if (@_) {
    $self->{_perl_path} = shift;
  }
  return $self->{_perl_path};
}

sub create_pair_aligner_page {
  my $self = shift;
  if (@_) {
    $self->{_create_pair_aligner_page} = shift;
  }
  return $self->{_create_pair_aligner_page};
}


#
#Write bed file to general repository for a new species or assembly. The naming scheme assumes the format
#production_name.assembly.genome.bed for toplevel regions and production_name.assembly.coding_exons.bed for exonic
#regions. If a file of that convention already exists, it will not be overwritten.
#
sub dump_bed_file {
    my ($self, $species, $url, $reg_conf) = @_;

    #Need assembly
    my $genome_db = $self->{'comparaDBA'}->get_GenomeDBAdaptor->fetch_by_registry_name($species);
    my $assembly = $genome_db->assembly;
    my $name = $genome_db->name; #get production_name
    
    #Check if file already exists
    my $genome_bed_file = $self->bed_dir ."/" . $name . "." . $assembly . "." . "genome.bed";
    my $exon_bed_file = $self->bed_dir . "/" . $name . "." . $assembly . "." . "coding_exons.bed";

    if (-e $genome_bed_file) {
	print "$genome_bed_file already exists. Not overwriting.\n";
    } else {
	#Need to dump toplevel features
	my $cmd;
	if (defined $reg_conf) {
	    $cmd = $self->dump_features . " --reg_conf " . $reg_conf ." --species $name --feature toplevel > $genome_bed_file";
	} else {
	    $cmd = $self->dump_features . " --url " . $url ." --species $name --feature toplevel > $genome_bed_file";
	}
	unless (system($cmd) == 0) {
	    throw("$cmd execution failed\n");
	}
    }
    
    if (-e $exon_bed_file) {
	print "$exon_bed_file already exists. Not overwriting.\n";
    } else {
	my $cmd;
	if (defined $reg_conf) {
	    $cmd = $self->dump_features . " --reg_conf " . $reg_conf ." --species $name --feature coding-exons > $exon_bed_file";
	} else {
	    $cmd = $self->dump_features . " --url " . $url ." --species $name --feature coding-exons > $exon_bed_file";
	}
	unless (system($cmd) == 0) {
	    throw("$cmd execution failed\n");
	}
    }
}

#
#Run script to update the pair aligner configuration database
#
sub run_update_config_database {
    my ($self) = @_;

    my $cmd = "perl " . $self->update_config_database . 
      " --config_file " . $self->config_file . 
      " --config_url " . $self->config_url . 
      " --ref_species " . $self->ref_species . 
      " --compara_url " . $self->{'comparaDBA'}->dbc->url . 
      " --mlss_id " . $self->mlss_id . 
      " --ensembl_release " . $self->ensembl_release;

    $cmd .= " --ref_url " . $self->ref_url if (defined $self->ref_url);
    $cmd .= " --non_ref_url " . $self->non_ref_url if (defined $self->non_ref_url);
    $cmd .= " --reg_conf " . $self->reg_conf if (defined $self->reg_conf);
    unless (system($cmd) == 0) {
	throw("$cmd execution failed\n");
    }
}

#
#Run script to create the html and png files for the web. These are written to the current directory 
#and will need to be copied to the correct location.
#
sub run_create_pair_aligner_page {
    my ($self) = @_;

    my $cmd = "perl " . $self->create_pair_aligner_page . 
      " --config_url " . $self->config_url . 
      " --mlss_id " . $self->mlss_id . " > ./mlss_" . $self->mlss_id . ".html";

    unless (system($cmd) == 0) {
	throw("$cmd execution failed\n");
    }
}

1;

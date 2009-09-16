#
# You may distribute this module under the same terms as perl itself
#
# POD documentation - main docs before the code

=pod

=head1 NAME

Bio::EnsEMBL::Compara::RunnableDB::HealthCheck

=cut

=head1 SYNOPSIS

$module->fetch_input

$module->run

$module->write_output

=cut

=head1 DESCRIPTION

This module is inteded to run automatic checks at the end of a pipeline (or at any other time)

=head1 OPTIONS

This module has been designed to run one test per analysis_job. All the options are specific to
the test iself and therefore you shouldn't set any parameters in the analysis table. Use the input_id
column of the analysis_job to set these values.

=head2 test

The name of the test to be run. See below for a list of tests

=head2 params

Parameters used by the test

=head1 TESTS

=head2 conservation_jobs

This test checks that there are one conservation analysis per alignment.

Parameters:

=over

=item logic_name

Logic name for the Conservation analysis. Default: Gerp

=item method_link_type (or from_method_link_type)

method_link_type for the multiple alignments. Default: PECAN

=back

=head2 conservation_scores

This test checks whether there are conservation scores in the table, whether
these correspond to existing genomic_align_blocks, whether the
right gerp_XXX entry exists in the meta table and whether there
are no alignments wiht more than 3 seqs and no scores.

Parameters:

=over

=item method_link_species_set_id (or mlss_id)

Specify the method_link_species_set_id for the conservation scores. Note that this can
be guessed from the database altough specifying the right mlss_id is probably safer.

For instance, it may happen that you expect 2 or 3 sets of scores. In that case it is
recommended to create one test for each of these set. If one of the sets is missing,
the test will succeed as it will successfully guess the mlss_id for the other sets and
check those values only.

=back

=head1 EXAMPLES

Here are some input_id examples:

=over

=item {test=>'conservation_jobs'}

Run the conservation_jobs test. Default parameters

=item {test=>'conservation_jobs', params=>{logic_name=>'Gerp', method_link_type=>'PECAN'}}

Run the conservation_jobs test. Specify logic_name for the Conservation analysis and method_link_type
for the underlying multiple alignments

=item {test=>'conservation_scores'}

Run the conservation_scores test. Default parameters

=item {test=>'conservation_scores', params=>{mlss_id=>50002}}

Run the conservation_scores test. Specify the method_link_species_set_id for the conservation scores

=back

=head1 CONTACT

Javier Herrero <jherrero@ebi.ac.uk>

=cut

=head1 APPENDIX

The rest of the documentation details each of the object methods.
Internal methods are usually preceded with a _

=cut

package Bio::EnsEMBL::Compara::RunnableDB::HealthCheck;

use strict;
use Bio::EnsEMBL::Compara::Production::DBSQL::DBAdaptor;;
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

  return 1;
}


=head2 run

  Implementation of the Bio::EnsEMBL::Hive::Process interface

=cut

sub run
{
  my $self = shift;
  if ($self->{'hc_output_dir'}) {
      open OLDOUT, ">&STDOUT";
      open OLDERR, ">&STDERR";
      open WORKER_STDOUT, ">>".$self->{'hc_output_dir'} ."/healthcheck.$$.out";
      open WORKER_STDERR, ">>".$self->{'hc_output_dir'} ."/healthcheck.$$.err";
      close STDOUT;
      close STDERR;
      open STDOUT, ">&WORKER_STDOUT";
      open STDERR, ">&WORKER_STDERR";
  }

  if ($self->test()) {
    ## Run the method called <_run_[TEST_NAME]_test>
    my $method = "_run_".$self->test()."_test";
    if ($self->can($method)) {
      print "Running test ", $self->test(), "\n";
      $self->$method($self->parameters);
      print "OK.\n";
    } else {
      die "There is no test called ".$self->test()."\n";
    }
  }
  if ($self->{'hc_output_dir'}) {
      close STDOUT;
      close STDERR;
      close WORKER_STDOUT;
      close WORKER_STDERR;
      open STDOUT, ">&", \*OLDOUT;
      open STDERR, ">&", \*OLDERR;

  }
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
  print("parsing parameter string : ",$param_string,"\n");

  my $params = eval($param_string);
  return unless($params);

  if (defined($params->{'test'})) {
    $self->test($params->{'test'});
  }

  if (defined($params->{'params'})) {
    $self->parameters($params->{'params'});
  }

  if (defined($params->{'hc_output_dir'})) {
      $self->{'hc_output_dir'} = $params->{'hc_output_dir'};
  }

  return 1;
}


=head2 test

  Arg [1]     : (optional) string $test
  Example     : $object->test($test);
  Example     : $test = $object->test();
  Description : Getter/setter for the test attribute, i.e. the
                name of the test to be run
  Returntype  : string
  Exceptions  : none
  Caller      : general
  Status      : Stable

=cut

sub test {
  my $self = shift;
  if (@_) {
    $self->{_test} = shift;
  }
  return $self->{_test};
}

=head2 parameters

  Arg [1]     : (optional) string $parameters
  Example     : $object->parameters($parameters);
  Example     : $parameters = $object->parameters();
  Description : Getter/setter for the parameters attribute
  Returntype  : string representing a hashref
  Exceptions  : none
  Caller      : general
  Status      : Stable

=cut

sub parameters {
  my $self = shift;
  if (@_) {
    $self->{_parameters} = shift;
  }
  return $self->{_parameters};
}


=head2 test_table

=cut

sub test_table {
  my ($self, $table_name) = @_;

  die "Cannot test table with no name\n" if (!$table_name);

  ## check the table is not empty
  my $count = $self->{'comparaDBA'}->dbc->db_handle->selectrow_array(
      "SELECT COUNT(*) FROM $table_name");

  if ($count == 0) {
    die("There are no entries in the $table_name table!\n");
  } else {
    print "Table $table_name contains data: OK.\n";
  }

}

=head2 _run_conservation_jobs_test

  Arg[1]      : string representing a hashref of options.
                Possible options are:
                  logic_name => Logic name for the Conservation Score
                      analysis. Default: Gerp
                  method_link_type => corresponds to the multiple
                      alignments. Default: PECAN
  Example     : $self->_run_conservation_jobs_test();
  Example     : $self->_run_conservation_jobs_test("{logic_name=>'GERP',
                    method_link_type=>'PECAN'}");
  Description : Tests whether there is one conservation job per multiple
                alignment or not. This test only look at the number of jobs.
  Returntype  :
  Exceptions  : die on failure
  Caller      : general

=cut

sub _run_conservation_jobs_test {
  my ($self, $parameters) = @_;

  my $logic_name = "Gerp";
  my $method_link_type = "PECAN";

  if ($parameters) {
    if (defined($parameters->{'logic_name'})) {
      $logic_name = $parameters->{'logic_name'};
    }
    if (defined($parameters->{'from_method_link_type'})) {
      $method_link_type = $parameters->{'from_method_link_type'};
    }
    if (defined($parameters->{'method_link_type'})) {
      $method_link_type = $parameters->{'method_link_type'};
    }
  }

  ## Get the number of analysis_jobs for Gerp (or any other specified analysis)
  my $count1 = $self->{'comparaDBA'}->dbc->db_handle->selectrow_array(
      "SELECT COUNT(*) FROM analysis LEFT JOIN analysis_job ".
      " USING (analysis_id) WHERE logic_name = \"$logic_name\"");

  ## Get the number of Pecan (or any other specified method_link_type) alignments
  my $count2 = $self->{'comparaDBA'}->dbc->db_handle->selectrow_array(
      "SELECT COUNT(*) FROM method_link".
      " LEFT JOIN method_link_species_set USING (method_link_id)".
      " LEFT JOIN genomic_align_block USING (method_link_species_set_id)".
      " WHERE method_link.type = \"$method_link_type\"");

  if ($count1 != $count2) {
    die("There are $count1 analysis_jobs for $logic_name while there are $count2 $method_link_type alignments!\n");
  } elsif ($count1 == 0) {
    die("There are no analysis_jobs for $logic_name and no $method_link_type alignments!\n");
  }
}


=head2 _run_conservation_scores_test

  Arg[1]      : string representing a hashref of options.
                Possible options are:
                  method_link_species_set_id => method_link_species_set_id
                      for the conservation scores
  Example     : $self->_run_conservation_scores_test();
  Example     : $self->_run_conservation_scores_test(
                    "{method_link_species_set_id=>123}");
  Description : Tests whether there are conservation scores in the table, whether
                these correspond to existing genomic_align_blocks, whether the
                right gerp_XXX entry exists in the meta table and whether there
                are no alignments with more than 3 seqs and no scores.
  Returntype  :
  Exceptions  : die on failure
  Caller      : general

=cut

sub _run_conservation_scores_test {
  my ($self, $parameters) = @_;

  my $method_link_species_set_id = 0;
  if ($parameters) {
    if (defined($parameters->{'method_link_species_set_id'})) {
      $method_link_species_set_id = $parameters->{'method_link_species_set_id'};
    }
    if (defined($parameters->{'mlss_id'})) {
      $method_link_species_set_id = $parameters->{'mlss_id'};
    }
  }

  $self->test_table("conservation_score");
  $self->test_table("genomic_align_block");
  $self->test_table("meta");

  my $count1 = $self->{'comparaDBA'}->dbc->db_handle->selectrow_array(
      "SELECT COUNT(*) FROM conservation_score LEFT JOIN genomic_align_block ".
      " USING (genomic_align_block_id) WHERE genomic_align_block.genomic_align_block_id IS NULL");

  if ($count1 > 0) {
    die("There are $count1 orphan conservation scores!\n");
  } else {
    print "conservation score external references are OK.\n";
  }

  my $meta_container = $self->{'comparaDBA'}->get_MetaContainer();

  my $method_link_species_set_ids;

  if ($method_link_species_set_id) {
    my ($aln_mlss_id) = @{$meta_container->list_value_by_key("gerp_".$method_link_species_set_id)};
    if (!$aln_mlss_id) {
      die "The meta table does not contain the gerp_$method_link_species_set_id entry!\n";
    }
    $method_link_species_set_ids = [$aln_mlss_id];
  } else {
    $method_link_species_set_ids = $self->{'comparaDBA'}->dbc->db_handle->selectcol_arrayref(
        "SELECT DISTINCT method_link_species_set_id FROM conservation_score LEFT JOIN genomic_align_block ".
        " USING (genomic_align_block_id)");
  }

  foreach my $this_method_link_species_set_id (@$method_link_species_set_ids) {
    my $gerp_key = $self->{'comparaDBA'}->dbc->db_handle->selectrow_array(
        "SELECT meta_key FROM meta WHERE meta_key LIKE \"gerp_%\" AND meta_value".
        " = \"$this_method_link_species_set_id\"");
    if (!$gerp_key) {
      die "There is no gerp_% entry in the meta table for mlss=".$this_method_link_species_set_id.
          "alignments!\n";
    } else {
      print "meta entry for $gerp_key: OK.\n";
    }

    my ($values) = $self->{'comparaDBA'}->dbc->db_handle->selectcol_arrayref(
        "SELECT genomic_align_block.genomic_align_block_id FROM genomic_align_block LEFT JOIN genomic_align".
        " ON (genomic_align_block.genomic_align_block_id = genomic_align.genomic_align_block_id)".
        " LEFT JOIN conservation_score".
        " ON (genomic_align_block.genomic_align_block_id = conservation_score.genomic_align_block_id)".
        " WHERE genomic_align_block.method_link_species_set_id = $this_method_link_species_set_id".
        " AND conservation_score.genomic_align_block_id IS NULL".
        " GROUP BY genomic_align_block.genomic_align_block_id HAVING count(*) > 3");
    if (@$values) {
      die "There are ".scalar(@$values)." blocks (mlss=".$this_method_link_species_set_id.
          ") with more than 3 seqs and no conservation score!\n";
    } else {
      print "All alignments for mlss=$this_method_link_species_set_id and more than 3 seqs have cons.scores: OK.\n";
    }
  }
}


=head2 _run_pairwise_gabs_test

  Arg[1]      : string representing a hashref of options.
                Possible options are:
                  method_link_species_set_id => method_link_species_set id for
                  the pairwise alignment.
                  method_link_type => method_link_type for pairwise segment
                  genome_db_ids => array of genome_db_ids
  Example     : $self->_run_pairwise_gabs_test();
  Example     : $self->_run_pairwise_gabs_test("{method_link_species_set_id=>123}");
  Example     : self->_run_pairwise_gabs_test("{method_link_type=>'BLASTZ_NET', genome_db_ids=>'[1,2]'}");
  Description : Tests whether the genomic_align_block and genomic_align tables
                are not empty, whether there are twice as many genomic_aligns
                as genomic_align_blocks and whether each genomic_align_block
                has two genomic_aligns.
  Returntype  :
  Exceptions  : die on failure
  Caller      : general

=cut

sub _run_pairwise_gabs_test {
  my ($self, $parameters) = @_;

  my $method_link_species_set_id;
  my $method_link_id;
  my $method_link_type;
  my $genome_db_ids;

  print "_run_pairwise_gabs_test\n";

  if ($parameters) {
    if (defined($parameters->{'method_link_species_set_id'})) {
      $method_link_species_set_id = $parameters->{'method_link_species_set_id'};
    }
    if (defined($parameters->{'mlss_id'})) {
      $method_link_species_set_id = $parameters->{'mlss_id'};
    }
    if (defined($parameters->{'method_link_type'})) {
      $method_link_type = $parameters->{'method_link_type'};
    }
    if (defined($parameters->{'genome_db_ids'})) {
	$genome_db_ids = eval($parameters->{'genome_db_ids'});
    }
  }

  $self->test_table("genomic_align_block");
  $self->test_table("genomic_align");

  my $method_link_species_set_ids;
  if ($method_link_species_set_id) {
      $method_link_species_set_ids = [$method_link_species_set_id];
  } elsif ($method_link_type && $genome_db_ids) {
      my $mlss_adaptor = $self->{'comparaDBA'}->get_MethodLinkSpeciesSetAdaptor;
      throw ("No method_link_species_set") if (!$mlss_adaptor);
      my $mlss = $mlss_adaptor->fetch_by_method_link_type_genome_db_ids($method_link_type, ${genome_db_ids});

      if (defined $mlss) {
	  $method_link_species_set_ids = [$mlss->dbID];
      }
  } else {
      $method_link_species_set_ids = $self->{'comparaDBA'}->dbc->db_handle->selectcol_arrayref(
	 "SELECT DISTINCT method_link_species_set_id FROM genomic_align_block");
  }

  foreach my $this_method_link_species_set_id (@$method_link_species_set_ids) {

      ## Get the number of genomic_align_blocks
      my $count1 = $self->{'comparaDBA'}->dbc->db_handle->selectrow_array(
		    "SELECT COUNT(*) FROM genomic_align_block WHERE method_link_species_set_id = \"$this_method_link_species_set_id\"");

      ## Get the number of genomic_aligns
      my $count2 = $self->{'comparaDBA'}->dbc->db_handle->selectrow_array(
                     "SELECT COUNT(*) FROM genomic_align_block gab LEFT JOIN genomic_align USING (genomic_align_block_id) WHERE gab.method_link_species_set_id = \"$this_method_link_species_set_id\"");

      ## Get the number of genomic_align_blocks which don't have 2 genomic_aligns
      my $count3 =  $self->{'comparaDBA'}->dbc->db_handle->selectrow_array(
	"SELECT COUNT(*) FROM (SELECT * FROM genomic_align WHERE method_link_species_set_id = \"$this_method_link_species_set_id\" GROUP BY genomic_align_block_id HAVING COUNT(*)!=2) cnt");

      #get the name for the method_link_species_set_id
      my $name = $self->{'comparaDBA'}->dbc->db_handle->selectrow_array(
		   "SELECT name FROM method_link_species_set WHERE method_link_species_set_id = \"$this_method_link_species_set_id\"");

      #should be twice as many genomic_aligns as genomic_align_blocks for
      #pairwise alignments
      if (2*$count1 != $count2) {
	  die("There are $count1 genomic_align_blocks for $name while there are $count2 genomic_aligns!\n");
      }

      if ($count3 != 0) {
	  die("There are $count3 genomic_align_blocks which don't have 2 genomic_aligns for $name!\n");
      }

      print "Number of genomic_align_blocks for $name = $count1\n";
      print "Number of genomic_aligns for $name = $count2 2*$count1=" . ($count1*2) . "\n";
      print "Number of genomic_align_blocks which don't have 2 genomic_aligns for $name = $count3\n";
  }
}

=head2 _run_compare_to_previous_db_test

  Arg[1]      : string representing a hashref of options.
                Possible options are:
                  previous_db_url => url of the previous database. Must be
                  defined.
                  previous_method_link_species_set_id => method_link_species_set
                  id for the pairwise alignments in the previous database.
                  current_method_link_species_set_id => method_link_species_set
                  id for the pairwise alignments in the current (this) database.
                  method_link_type => method_link_type for pairwise segment
                  current_genome_db_ids => array of genome_db_ids for current
                  (this) database
                  max_percentage_diff => the percentage difference between the
                  number of genomic_align_blocks in the query and the target
                  databases before being flaged as an error. Default 20.
  Example     : $self->_run_compare_to_previous_db_test("{previous_db_url=>'mysql://anonymous@ensembldb.ensembl.org:3306/ensembl_compara_47', previous_method_link_species_set_id=>123, current_method_link_species_set_id=>123, max_percentage_diff=>20}");
 Example      : $self->_run_compare_to_previous_db_test("{previous_db_url=>\'mysql://anonymous\@ensembldb.ensembl.org\',method_link_type=>\'BLASTZ_NET\',current_genome_db_ids=>\'[25,22,]\'}")
  Description : Tests whether there are genomic_align_blocks, genomic_aligns
                and method_link_species_sets in the tables and whether the
                total number of genomic_align_blocks between 2 databases are
                within a certain percentage of each other.

  Returntype  :
  Exceptions  : die on failure
  Caller      : general

=cut


sub _run_compare_to_previous_db_test {
  my ($self, $parameters) = @_;

  print "_run_compare_to_previous_db_test\n";

  my $previous_mlss_id;
  my $current_mlss_id;
  my $max_percent_diff = 20;
  my $previous_db_url;
  my $method_link_type;
  my $previous_genome_db_ids;
  my $current_genome_db_ids;
  my $species_set;
  my $previous_gdbs;

  if ($parameters) {
    if (defined($parameters->{'previous_method_link_species_set_id'})) {
      $previous_mlss_id = $parameters->{'previous_method_link_species_set_id'};
    }
    if (defined($parameters->{'current_method_link_species_set_id'})) {
      $current_mlss_id = $parameters->{'current_method_link_species_set_id'};
    }
    if (defined($parameters->{'previous_mlss_id'})) {
      $previous_mlss_id = $parameters->{'previous_mlss_id'};
    }
    if (defined($parameters->{'current_mlss_id'})) {
      $current_mlss_id = $parameters->{'current_mlss_id'};
    }
    if (defined($parameters->{'previous_db_url'})) {
      $previous_db_url = $parameters->{'previous_db_url'};
    }
    if (defined($parameters->{'method_link_type'})) {
      $method_link_type = $parameters->{'method_link_type'};
    }
    if (defined($parameters->{'current_genome_db_ids'})) {
	$current_genome_db_ids = eval($parameters->{'current_genome_db_ids'});
    }
    if (defined($parameters->{'max_percentage_diff'})) {
      $max_percent_diff = $parameters->{'max_percentage_diff'};
    }
  }

  throw("Must define previous database url") if (!defined($previous_db_url));

  $self->test_table("genomic_align_block");
  $self->test_table("genomic_align");
  $self->test_table("method_link_species_set");

  #Load previous url
  Bio::EnsEMBL::Registry->load_registry_from_url($previous_db_url);
  my $previous_compara_dba;

  #if the database name is defined in the url, then open that
  if ($previous_db_url =~ /mysql:\/\/.*@.*\/.+/) {
      $previous_compara_dba = new Bio::EnsEMBL::Compara::DBSQL::DBAdaptor(-url=>$previous_db_url);
  } else {
      #open the most recent compara database
      $previous_compara_dba = Bio::EnsEMBL::Registry->get_DBAdaptor("Multi", "compara");
  }

  #get the previous method_link_species_set adaptor
  my $previous_mlss_adaptor = $previous_compara_dba->get_MethodLinkSpeciesSetAdaptor;
  throw ("No method_link_species_set") if (!$previous_mlss_adaptor);

  my $previous_genome_db_adaptor = $previous_compara_dba->get_GenomeDBAdaptor;
  throw ("No genome_db") if (!$previous_genome_db_adaptor);


  #get the current method_link_species_set adaptor
  my $current_mlss_adaptor = $self->{'comparaDBA'}->get_MethodLinkSpeciesSetAdaptor;
  throw ("No method_link_species_set") if (!$current_mlss_adaptor);

  #get the current genome_db adaptor
  my $current_genome_db_adaptor = $self->{'comparaDBA'}->get_GenomeDBAdaptor;
  throw ("No genome_db_adaptor") if (!$current_genome_db_adaptor);

  #get the current method_link_species_set object from method_link_type and
  #current genome_db_ids
  if (defined $method_link_type && defined $current_genome_db_ids) {
      my $current_mlss = $current_mlss_adaptor->fetch_by_method_link_type_genome_db_ids($method_link_type, @{$current_genome_db_ids});
      if (defined $current_mlss) {
	  $current_mlss_id = $current_mlss->dbID;
      }
  } elsif (!defined $current_mlss_id) {
      throw("No current_mlss_id or method_link_type and current_genome_db_ids set\n");
  }

  #get the previous method_link_species_set object from the method_link_type and
  #species corresponding to the current genome_db_ids
  if (defined $method_link_type && defined $current_genome_db_ids) {
      #covert genome_db_ids into species names
      foreach my $g_db_id (@$current_genome_db_ids) {
	  my $g_db = $current_genome_db_adaptor->fetch_by_dbID($g_db_id);

	  my $previous_gdb = $previous_genome_db_adaptor->fetch_by_name_assembly($g_db->name);
	  push @$previous_gdbs, $previous_gdb->dbID;
      }

      #find corresponding method_link_species_set in previous database
      my $previous_mlss;
      eval {
	  $previous_mlss = $previous_mlss_adaptor->fetch_by_method_link_type_genome_db_ids($method_link_type, ${previous_gdbs});
      };

      #Catch throw if these species do not exist in the previous database
      #and return success.
      if ($@ || !defined $previous_mlss) {
	  print "This pair of species (" .(join ",", @$species_set) . ") with this method_link $method_link_type not do exist in this database $previous_db_url \n";
	  return;
      }
      $previous_mlss_id = $previous_mlss->dbID;
  } elsif (!defined $previous_mlss_id) {
      throw("No previous_mlss_id or method_link_type and current_genome_db_ids set\n");
  }

  #get the name for the method_link_species_set_id
  my $previous_name = $previous_compara_dba->dbc->db_handle->selectrow_array(
	"SELECT name FROM method_link_species_set WHERE method_link_species_set_id = \"$previous_mlss_id\"");

  my $current_name = $self->{'comparaDBA'}->dbc->db_handle->selectrow_array(
	"SELECT name FROM method_link_species_set WHERE method_link_species_set_id = \"$current_mlss_id\"");

  ## Get the number of genomic_align_blocks of previous db
  my $previous_count = $previous_compara_dba->dbc->db_handle->selectrow_array(
      "SELECT COUNT(*) FROM genomic_align_block WHERE method_link_species_set_id = \"$previous_mlss_id\"");

  ## Get number of genomic_align_blocks of current db
  my $current_count = $self->{'comparaDBA'}->dbc->db_handle->selectrow_array(
      "SELECT COUNT(*) FROM genomic_align_block WHERE method_link_species_set_id = \"$current_mlss_id\"");


  ## Find percentage difference between the two
  my $current_percent_diff = abs($current_count-$previous_count)/$previous_count*100;

  my $c_perc = sprintf "%.2f", $current_percent_diff;
  ## Report an error if this is higher than max_percent_diff
  if ($current_percent_diff > $max_percent_diff) {
      die("The percentage difference between the number of genomic_align_blocks of the current database of $current_name results ($current_count) and the previous database of $previous_name results ($previous_count) is $c_perc% and is greater than $max_percent_diff%!\n");
  }

  print "The percentage difference between the number of genomic_align_blocks of the current database of $current_name results ($current_count) and the previous database of $previous_name results ($previous_count) is $c_perc% and is less than $max_percent_diff%!\n";

}


=head2 _run_left_and_right_links_in_gat_test

  Arg[1]      : -none-
  Example     : $self->_run_left_and_right_links_in_gat_test();
  Description : Tests whether all the trees in the genomic_align_tree table
                are linked to other trees via their left and right node ids.
  Returntype  :
  Exceptions  : die on failure
  Caller      : general

=cut

sub _run_left_and_right_links_in_gat_test {
  my ($self) = @_;
  my $table_name = "genomic_align_tree";

  ## check the table is not empty
  my $count = $self->{'comparaDBA'}->dbc->db_handle->selectrow_array(
      "SELECT count(*) FROM $table_name gat1 LEFT JOIN $table_name gat2 ON (gat1.node_id = gat2.root_id)".
      " WHERE gat1.parent_id = 0 GROUP BY gat1.node_id".
      " HAVING GROUP_CONCAT(gat2.left_node_id ORDER BY gat2.left_node_id) LIKE \"0%,0\"".
      "  AND GROUP_CONCAT(gat2.right_node_id ORDER BY gat2.right_node_id) LIKE \"0%,0\"");

  if ($count == 0) {
    print "All trees in $table_name are linked to their neighbours: OK.\n";
  } else {
    die("Some entries ($count) in the $table_name table are not linked!\n");
  }
}

1;

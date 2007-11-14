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
  Example     : $self->_run_pairwise_gabs_test();
  Example     : $self->_run_pairwise_gabs_test("{method_link_species_set_id=>123}");
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

  if ($parameters) {
    if (defined($parameters->{'method_link_species_set_id'})) {
      $method_link_species_set_id = $parameters->{'method_link_species_set_id'};
    }
    if (defined($parameters->{'mlss_id'})) {
      $method_link_species_set_id = $parameters->{'mlss_id'};
    }
  }

  $self->test_table("genomic_align_block");
  $self->test_table("genomic_align");

  my $method_link_species_set_ids;
  if ($method_link_species_set_id) {
      $method_link_species_set_ids = [$method_link_species_set_id];
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
  }
}

=head2 _run_compare_to_previous_db_test

  Arg[1]      : string representing a hashref of options.
                Possible options are:
                  target_url => url of the target (previous) database. Must be 
                  defined.
                  target_method_link_species_set_id => method_link_species_set 
                  id for the pairwise alignments in the target (previous) 
                  database. Must be defined
                  query_method_link_species_set_id => method_link_species_set 
                  id for the pairwise alignments in the query (this) database. 
                  Must be defined
                  max_percentage_diff => the percentage difference between the 
                  number of genomic_align_blocks in the query and the target 
                  databases before being flaged as an error. Default 20.
  Example     : $self->_run_compare_to_previous_db_test("{target_url=>'mysql://anonymous@ensembldb.ensembl.org:3306/ensembl_compara_47', target_method_link_species_set_id=>123, query_method_link_species_set_id=>123, max_percentage_diff=>20}");
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

  my $target_mlss_id;
  my $query_mlss_id;
  my $max_percent_diff = 20;
  my $target_url;

  if ($parameters) {
    if (defined($parameters->{'target_method_link_species_set_id'})) {
      $target_mlss_id = $parameters->{'target_method_link_species_set_id'};
    }
    if (defined($parameters->{'query_method_link_species_set_id'})) {
      $query_mlss_id = $parameters->{'query_method_link_species_set_id'};
    }
    if (defined($parameters->{'target_mlss_id'})) {
      $target_mlss_id = $parameters->{'target_mlss_id'};
    }
    if (defined($parameters->{'query_mlss_id'})) {
      $query_mlss_id = $parameters->{'query_mlss_id'};
    }
    if (defined($parameters->{'target_url'})) {
      $target_url = $parameters->{'target_url'};
    }
    if (defined($parameters->{'max_percentage_diff'})) {
      $max_percent_diff = $parameters->{'max_percentage_diff'};
    }
  }

  throw("Must define target method_link_species_set_id") if (!defined($target_mlss_id));
  throw("Must define query method_link_species_set_id") if (!defined($query_mlss_id));
  throw("Must define target url") if (!defined($target_url));

  $self->test_table("genomic_align_block");
  $self->test_table("genomic_align");
  $self->test_table("method_link_species_set");


  my $compara_dba = new Bio::EnsEMBL::Compara::DBSQL::DBAdaptor(-url=>$target_url);

  my $genomic_align_block_adaptor = $compara_dba->get_GenomicAlignBlockAdaptor;
  throw ("No genomic_align_blocks") if (!$genomic_align_block_adaptor);

  my $target_mlss_adaptor = $compara_dba->get_MethodLinkSpeciesSetAdaptor;
  throw ("No method_link_species_set") if (!$target_mlss_adaptor);

  #get the name for the method_link_species_set_id
  my $target_name = $self->{'comparaDBA'}->dbc->db_handle->selectrow_array(
	"SELECT name FROM method_link_species_set WHERE method_link_species_set_id = \"$target_mlss_id\""); 
  my $query_name = $self->{'comparaDBA'}->dbc->db_handle->selectrow_array(
	"SELECT name FROM method_link_species_set WHERE method_link_species_set_id = \"$query_mlss_id\""); 

  ## Get the number of genomic_align_blocks of previous (target) db
  my $target_mlss = $target_mlss_adaptor->fetch_by_dbID($target_mlss_id);
  my $target_count = @{$genomic_align_block_adaptor->fetch_all_by_MethodLinkSpeciesSet($target_mlss)};

  ## Get number of genomic_align_blocks of current (query) db
  my $query_count = $self->{'comparaDBA'}->dbc->db_handle->selectrow_array(
      "SELECT COUNT(*) FROM genomic_align_block WHERE method_link_species_set_id = \"$query_mlss_id\"");

  ## Find percentage difference between the two
  my $current_percent_diff = abs($query_count-$target_count)/$target_count*100;

  ## Report an error if this is higher than max_percent_diff
  if ($current_percent_diff > $max_percent_diff) {
      my $c_perc = sprintf "%.2f", $current_percent_diff;
      die("The percentage difference between the number of genomic_align_blocks of the current database of $query_name results ($query_count) and the target database of $target_name results ($target_count) is $c_perc% and is greater than $max_percent_diff%!\n");
  }

}

1;

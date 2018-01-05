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

This module has been designed to run one test per job. All the options are specific to
the test iself and therefore you shouldn't set any parameters in the analysis table. Use the input_id
column of the job to set these values.

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
these correspond to existing genomic_align_blocks, and whether there
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

Please email comments or questions to the public Ensembl
developers list at <http://lists.ensembl.org/mailman/listinfo/dev>.

Questions may also be sent to the Ensembl help desk at
<http://www.ensembl.org/Help/Contact>.

=cut

=head1 APPENDIX

The rest of the documentation details each of the object methods.
Internal methods are usually preceded with a _

=cut

package Bio::EnsEMBL::Compara::RunnableDB::HealthCheck;

use strict;
use warnings;
use Bio::EnsEMBL::Utils::Exception qw(throw);

use Data::Dumper;

use base ('Bio::EnsEMBL::Compara::RunnableDB::BaseRunnable');

sub fetch_input {
  my ($self) = @_;

  return 1;
}


sub run
{
  my $self = shift;

  if ($self->param('test')) {
      ## Run the method called <_run_[TEST_NAME]_test>
      my $method = "_run_".$self->param('test')."_test";
      if ($self->can($method)) {
	  $self->warning("Running test ".$self->param('test'));
	  $self->$method;
	  $self->warning("OK.");
      } else {
	  die "There is no test called ".$self->param('test')."\n";
      }
  }
  return 1;
}

sub write_output {
  my ($self) = @_;

  return 1;
}


sub test_table {
  my ($self, $table_name) = @_;

  die "Cannot test table with no name\n" if (!$table_name);

  ## check the table is not empty
  my $count = $self->compara_dba->dbc->db_handle->selectrow_array(
      "SELECT COUNT(*) FROM $table_name");

  if ($count == 0) {
    die("There are no entries in the $table_name table!\n");
  } else {
    $self->warning("Table $table_name contains data: OK.");
  }

}

=head2 _run_conservation_jobs_test

  Description : Tests whether there is one conservation job per multiple
                alignment or not. This test only look at the number of jobs.
                Required parameters (in $self->param())
                  logic_name => Logic name for the Conservation Score
                      analysis. Default: Gerp
                  method_link_type => corresponds to the multiple
                      alignments. Default: PECAN
  Returntype  :
  Exceptions  : die on failure
  Caller      : general

=cut

sub _run_conservation_jobs_test {
  my ($self) = @_;

  my $logic_name = "Gerp";
  my $method_link_type = "PECAN";

  $logic_name = $self->param('logic_name') if (defined($self->param('logic_name')));
  $method_link_type = $self->param('from_method_link_type') if (defined($self->param('from_method_link_type')));
  $method_link_type = $self->param('method_link_type') if (defined($self->param('method_link_type')));

  ## Get the number of jobs for Gerp (or any other specified analysis)
  my $count1 = $self->compara_dba->dbc->db_handle->selectrow_array(
      "SELECT COUNT(*) FROM analysis_base LEFT JOIN job ".
      " USING (analysis_id) WHERE logic_name = \"$logic_name\"");

  ## Get the number of Pecan (or any other specified method_link_type) alignments
  my $count2 = $self->compara_dba->dbc->db_handle->selectrow_array(
      "SELECT COUNT(*) FROM method_link".
      " LEFT JOIN method_link_species_set USING (method_link_id)".
      " LEFT JOIN genomic_align_block USING (method_link_species_set_id)".
      " WHERE method_link.type = \"$method_link_type\"");

  if ($count1 != $count2) {
    die("There are $count1 jobs for $logic_name while there are $count2 $method_link_type alignments!\n");
  } elsif ($count1 == 0) {
    die("There are no jobs for $logic_name and no $method_link_type alignments!\n");
  }
}


=head2 _run_conservation_scores_test

  Description : Tests whether there are conservation scores in the table, whether
                these correspond to existing genomic_align_blocks, and hether there
                are no alignments with more than 3 seqs and no scores.
                Required parameters (in $self->param())
                  method_link_species_set_id => method_link_species_set_id
                      for the conservation scores
  Returntype  :
  Exceptions  : die on failure
  Caller      : general

=cut

sub _run_conservation_scores_test {
  my ($self) = @_;

  my $method_link_species_set_id = $self->param('method_link_species_set_id');

  $self->test_table("conservation_score");
  $self->test_table("genomic_align_block");
  $self->test_table("meta");

  my $count1 = $self->compara_dba->dbc->db_handle->selectrow_array(
      "SELECT COUNT(*) FROM conservation_score LEFT JOIN genomic_align_block ".
      " USING (genomic_align_block_id) WHERE genomic_align_block.genomic_align_block_id IS NULL");

  if ($count1 > 0) {
    die("There are $count1 orphan conservation scores!\n");
  } else {
    $self->warning("conservation score external references are OK.");
  }

  my $meta_container = $self->compara_dba->get_MetaContainer();

  my $method_link_species_set_ids;

  if ($method_link_species_set_id) {
    my $aln_mlss_id = $self->compara_dba->get_MethodLinkSpeciesSetAdaptor->fetch_by_dbID($method_link_species_set_id)->get_value_for_tag('msa_mlss_id');
    if (!$aln_mlss_id) {
      die "The mlss_tag table does not contain the msa_mlss_id entry for $method_link_species_set_id !\n";
    }
    $method_link_species_set_ids = [$aln_mlss_id];
  } else {
    $method_link_species_set_ids = $self->compara_dba->dbc->db_handle->selectcol_arrayref(
        "SELECT DISTINCT method_link_species_set_id FROM conservation_score LEFT JOIN genomic_align_block ".
        " USING (genomic_align_block_id)");
  }

  foreach my $this_method_link_species_set_id (@$method_link_species_set_ids) {
    my $ma_mlss_id = $self->compara_dba->dbc->db_handle->selectrow_array(
        'SELECT method_link_species_set_id FROM method_link_species_set_tag JOIN method_link_species_set USING (method_link_species_set_id) JOIN method_link USING (method_link_id) WHERE type LIKE "%CONSERVATION\_SCORE" AND tag = "msa_mlss_id" AND value = ?',
        undef,
        $this_method_link_species_set_id
    );
    if (!$ma_mlss_id) {
      die "There is no msa_mlss_id entry in the method_link_species_set_tag table for mlss=".$this_method_link_species_set_id.
          "alignments!\n";
    } else {
      $self->warning("mlss_tag entry for $ma_mlss_id: OK.");
    }

    my ($values) = $self->compara_dba->dbc->db_handle->selectcol_arrayref(
        "SELECT genomic_align_block.genomic_align_block_id FROM genomic_align_block LEFT JOIN genomic_align".
        " ON (genomic_align_block.genomic_align_block_id = genomic_align.genomic_align_block_id)".
        " LEFT JOIN conservation_score".
        " ON (genomic_align_block.genomic_align_block_id = conservation_score.genomic_align_block_id)".
        " WHERE genomic_align_block.method_link_species_set_id = $this_method_link_species_set_id".
        " AND conservation_score.genomic_align_block_id IS NULL".
        " GROUP BY genomic_align_block.genomic_align_block_id HAVING count(*) > 3");

    if (@$values) {
	foreach my $value (@$values) {
	    $self->warning("gab_id $value");
	}
      die "There are ".scalar(@$values)." blocks (mlss=".$this_method_link_species_set_id.
          ") with more than 3 seqs and no conservation score!\n";
    } else {
      $self->warning("All alignments for mlss=$this_method_link_species_set_id and more than 3 seqs have cons.scores: OK.");
    }
  }
}


=head2 _run_pairwise_gabs_test

  Description : Tests whether the genomic_align_block and genomic_align tables
                are not empty, whether there are twice as many genomic_aligns
                as genomic_align_blocks and whether each genomic_align_block
                has two genomic_aligns.
                Required parameters (in $self->param())
                  method_link_species_set_id => method_link_species_set id for
                  the pairwise alignment.
                  genome_db_ids => array of genome_db_ids
                  method_link_type => method_link_type for pairwise segment
  Returntype  :
  Exceptions  : die on failure
  Caller      : general

=cut

sub _run_pairwise_gabs_test {
  my ($self) = @_;

  #print "_run_pairwise_gabs_test\n";

  my $method_link_species_set_id = $self->param('mlss_id') || $self->param('method_link_species_set_id');
  my $method_link_type = $self->param('method_link_type');
  my $genome_db_ids = $self->param('genome_db_ids');

  $self->test_table("genomic_align_block");
  $self->test_table("genomic_align");

  my $method_link_species_set_ids;
  if ($method_link_species_set_id) {
      $method_link_species_set_ids = [$method_link_species_set_id];
  } elsif ($method_link_type && $genome_db_ids) {
      my $mlss_adaptor = $self->compara_dba->get_MethodLinkSpeciesSetAdaptor;
      throw ("No method_link_species_set") if (!$mlss_adaptor);
      my $mlss = $mlss_adaptor->fetch_by_method_link_type_genome_db_ids($method_link_type, ${genome_db_ids});

      if (defined $mlss) {
	  $method_link_species_set_ids = [$mlss->dbID];
      }
  } else {
      $method_link_species_set_ids = $self->compara_dba->dbc->db_handle->selectcol_arrayref(
	 "SELECT DISTINCT method_link_species_set_id FROM genomic_align_block");
  }

  foreach my $this_method_link_species_set_id (@$method_link_species_set_ids) {

      ## Get the number of genomic_align_blocks
      my $count1 = $self->compara_dba->dbc->db_handle->selectrow_array(
		    "SELECT COUNT(*) FROM genomic_align_block WHERE method_link_species_set_id = \"$this_method_link_species_set_id\"");

      ## Get the number of genomic_aligns
      my $count2 = $self->compara_dba->dbc->db_handle->selectrow_array(
                     "SELECT COUNT(*) FROM genomic_align_block gab LEFT JOIN genomic_align USING (genomic_align_block_id) WHERE gab.method_link_species_set_id = \"$this_method_link_species_set_id\"");

      ## Get the number of genomic_align_blocks which don't have 2 genomic_aligns
      my $count3 =  $self->compara_dba->dbc->db_handle->selectrow_array(
	"SELECT COUNT(*) FROM (SELECT * FROM genomic_align WHERE method_link_species_set_id = \"$this_method_link_species_set_id\" GROUP BY genomic_align_block_id HAVING COUNT(*)!=2) cnt");

      #get the name for the method_link_species_set_id
      my $name = $self->compara_dba->dbc->db_handle->selectrow_array(
		   "SELECT name FROM method_link_species_set WHERE method_link_species_set_id = \"$this_method_link_species_set_id\"");

      #should be twice as many genomic_aligns as genomic_align_blocks for
      #pairwise alignments
      if (2*$count1 != $count2) {
	  die("There are $count1 genomic_align_blocks for $name while there are $count2 genomic_aligns!\n");
      }

      if ($count3 != 0) {
	  die("There are $count3 genomic_align_blocks which don't have 2 genomic_aligns for $name!\n");
      }

      $self->warning("Number of genomic_align_blocks for $name = $count1");
      $self->warning("Number of genomic_aligns for $name = $count2 2*$count1=" . ($count1*2));
      $self->warning("Number of genomic_align_blocks which don't have 2 genomic_aligns for $name = $count3");
  }
}

=head2 _run_compare_to_previous_db_test

  Description : Tests whether there are genomic_align_blocks, genomic_aligns
                and method_link_species_sets in the tables and whether the
                total number of genomic_align_blocks between 2 databases are
                within a certain percentage of each other.
                Required parameters (in $self->param())
                  previous_db_url => url of the previous database. Must be
                  defined.
                  previous_method_link_species_set_id => method_link_species_set
                  id for the pairwise alignments in the previous database.
                  current_method_link_species_set_id => method_link_species_set
                  id for the pairwise alignments in the current (this) database.
                  method_link_type => method_link_type for pairwise segment
                  current_genome_db_ids => array of genome_db_ids for current
                  (this) database
                  max_percent_diff => the percentage difference between the
                  number of genomic_align_blocks in the query and the target
                  databases before being flaged as an error. Default 20.
  Returntype  :
  Exceptions  : die on failure
  Caller      : general

=cut


sub _run_compare_to_previous_db_test {
  my ($self) = @_;

  #print "_run_compare_to_previous_db_test\n";
  
  my $max_percent_diff = defined $self->param('max_percent_diff') ? $self->param('max_percent_diff') : 20;
  
  my $previous_mlss_id = $self->param('previous_mlss_id') || $self->param('previous_method_link_species_set_id');
  
  my $current_mlss_id = $self->param('mlss_id') || $self->param('current_mlss_id') || $self->param('current_method_link_species_set_id');

  my $previous_db = $self->param_required('previous_db');

  my $method_link_type = $self->param('method_link_type');
  my $current_genome_db_ids = $self->param('current_genome_db_ids');

  my $ensembl_release = $self->param('ensembl_release');
  my $prev_release;
  if ($self->param('prev_release') == 0) {
      $self->param('prev_release', ($ensembl_release-1));
  }

  $self->test_table("genomic_align_block");
  $self->test_table("genomic_align");
  $self->test_table("method_link_species_set");

  #Check if $previous_db is a hash
  if ((ref($previous_db) eq "HASH") && !defined($previous_db->{'-dbname'})) {
      my $dbname = "ensembl_compara_" . $self->param('prev_release');
      $previous_db->{'-dbname'} = $dbname;
  }
  
  #Load previous url
  my $previous_compara_dba = $self->get_cached_compara_dba('previous_db');

  #get the previous method_link_species_set adaptor
  my $previous_mlss_adaptor = $previous_compara_dba->get_MethodLinkSpeciesSetAdaptor;
  throw ("No method_link_species_set") if (!$previous_mlss_adaptor);

  my $previous_genome_db_adaptor = $previous_compara_dba->get_GenomeDBAdaptor;
  throw ("No genome_db") if (!$previous_genome_db_adaptor);


  #get the current method_link_species_set adaptor
  my $current_mlss_adaptor = $self->compara_dba->get_MethodLinkSpeciesSetAdaptor;
  throw ("No method_link_species_set") if (!$current_mlss_adaptor);

  #get the current genome_db adaptor
  my $current_genome_db_adaptor = $self->compara_dba->get_GenomeDBAdaptor;
  throw ("No genome_db_adaptor") if (!$current_genome_db_adaptor);

  #get the current method_link_species_set object from method_link_type and
  #current genome_db_ids
  if (defined $method_link_type && defined $self->param('current_genome_db_ids')) {
      my $current_mlss = $current_mlss_adaptor->fetch_by_method_link_type_genome_db_ids($method_link_type, $self->param('current_genome_db_ids'));
      if (defined $current_mlss) {
	  $current_mlss_id = $current_mlss->dbID;
      }
  } elsif (defined $current_mlss_id) {
      my $mlss = $current_mlss_adaptor->fetch_by_dbID($current_mlss_id);
      $method_link_type = $mlss->method->type;
      @$current_genome_db_ids = map {$_->dbID} @{$mlss->species_set->genome_dbs};
  } else {
      $self->throw("No current_mlss_id or method_link_type and current_genome_db_ids set\n");
  }

  #get the previous method_link_species_set object from the method_link_type and
  #species corresponding to the current genome_db_ids
  if (defined $method_link_type && defined $current_genome_db_ids) {
      my $previous_gdbs;

      #covert genome_db_ids into species names
      foreach my $g_db_id (@$current_genome_db_ids) {
	  my $g_db = $current_genome_db_adaptor->fetch_by_dbID($g_db_id);

	  my $previous_gdb = $previous_genome_db_adaptor->fetch_by_dbID($g_db_id)
                               || $previous_genome_db_adaptor->fetch_by_name_assembly($g_db->name);
	  if (!$previous_gdb) {
	      $self->warning($g_db->name. " does not exist in the previous database (" . $previous_compara_dba->dbc->dbname . ")");
	      return;
	  } elsif ($g_db->genome_component and not $previous_gdb->genome_component) {
              $previous_gdb = $previous_gdb->component_genome_dbs($g_db->genome_component);
          }
	  push @$previous_gdbs, $previous_gdb->dbID;
      }

      #find corresponding method_link_species_set in previous database
      my $previous_mlss;
      eval {
	      $previous_mlss = $previous_mlss_adaptor->fetch_by_method_link_type_genome_db_ids($method_link_type, $previous_gdbs);

        ### HACK ###
        # if this is the first time this type of analysis is run, the MLSS will not exist in previous DB
        # in this case, find another MLSS of the same class
        unless ( defined $previous_mlss ) {
            # my $prev_mlss_class = $previous_mlss

            my $ss_adaptor = $self->compara_dba->get_SpeciesSetAdaptor;
            my $species_set = $ss_adaptor->fetch_by_GenomeDBs( $previous_gdbs );
            my $species_set_id = $species_set->dbID;
            my @alt_mlss_list = @{ $previous_mlss_adaptor->fetch_all_by_species_set_id( $species_set_id ) };

            #print Dumper \@alt_mlss_list;

            foreach my $mlss ( @alt_mlss_list ){
              my $mlss_class = $mlss->method->class;
              #print "MLSS_CLASS: $mlss_class\n";
              if ( $mlss_class =~ /pairwise_alignment/ ){
                $previous_mlss = $mlss;
                #print Dumper $previous_mlss;
                
                last;
              }
            }
        }  
        ### HACK END ###   

      };




      #Catch throw if these species do not exist in the previous database
      #and return success.
      if ($@ || !defined $previous_mlss) {
        my @names = map { $previous_genome_db_adaptor->fetch_by_dbID($_)->name() } @$previous_gdbs;
	print ("This pair of species (" .(join ",", @names) . ") with this method_link $method_link_type not do exist in this database " . $previous_compara_dba->dbc->dbname . "\n");
	  $self->warning("This pair of species (" .(join ",", @names) . ") with this method_link $method_link_type not do exist in this database " . $previous_compara_dba->dbc->dbname);
	  return;
      }
      $previous_mlss_id = $previous_mlss->dbID;
  } elsif (!defined $previous_mlss_id) {
      $self->throw("No previous_mlss_id or method_link_type and current_genome_db_ids set\n");
  }

  #get the name for the method_link_species_set_id
  my $previous_name = $previous_compara_dba->dbc->db_handle->selectrow_array(
	"SELECT name FROM method_link_species_set WHERE method_link_species_set_id = \"$previous_mlss_id\"");

  my $current_name = $self->compara_dba->dbc->db_handle->selectrow_array(
	"SELECT name FROM method_link_species_set WHERE method_link_species_set_id = \"$current_mlss_id\"");

  ## Get the number of genomic_align_blocks of previous db
  my $previous_count = $previous_compara_dba->dbc->db_handle->selectrow_array(
      "SELECT COUNT(*) FROM genomic_align_block WHERE method_link_species_set_id = \"$previous_mlss_id\"");

  ## Get number of genomic_align_blocks of current db
  my $current_count = $self->compara_dba->dbc->db_handle->selectrow_array(
      "SELECT COUNT(*) FROM genomic_align_block WHERE method_link_species_set_id = \"$current_mlss_id\"");


  ## Find percentage difference between the two
  my $current_percent_diff = abs($current_count-$previous_count)/$previous_count*100;

  my $c_perc = sprintf "%.2f", $current_percent_diff;
  ## Report an error if this is higher than max_percent_diff
  if ($current_percent_diff > $max_percent_diff) {
      die("The percentage difference between the number of genomic_align_blocks of the current database of $current_name results ($current_count) and the previous database of $previous_name results ($previous_count) is $c_perc% and is greater than $max_percent_diff%!\n");
  }
  
  $self->warning("The percentage difference between the number of genomic_align_blocks of the current database of $current_name results ($current_count) and the previous database of $previous_name results ($previous_count) is $c_perc% and is less than $max_percent_diff%!");

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
  my $count = $self->compara_dba->dbc->db_handle->selectrow_array(
      "SELECT count(*) FROM $table_name gat1 LEFT JOIN $table_name gat2 ON (gat1.node_id = gat2.root_id)".
      " WHERE gat1.parent_id IS NULL GROUP BY gat1.node_id".
      " HAVING COUNT(gat2.left_node_id) = 0".
      "  AND COUNT(gat2.right_node_id) = 0");

  if ($count == 0) {
    $self->warning("All trees in $table_name are linked to their neighbours: OK.");
  } else {
    die("Some entries ($count) in the $table_name table are not linked!\n");
  }
}

1;

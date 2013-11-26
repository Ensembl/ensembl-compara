=head1 LICENSE

Copyright [1999-2013] Wellcome Trust Sanger Institute and the EMBL-European Bioinformatics Institute

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

=head1 NAME

 Bio::EnsEMBL::Compara::PipeConfig::Example::VegaPairAligner_conf

=head1 SYNOPSIS

    #1. Update ensembl-hive, ensembl and ensembl-compara CVS repositories before each new release

    #2. You may need to update 'schema_version' in meta table to the current release number in ensembl-hive/sql/tables.sql

    #3. Make sure that all default_options are set correctly, especially:
        release
        pipeline_db (-host)
        resource_classes 
        ref_species (if not homo_sapiens)
        default_chunks (especially if the reference is not human, since the masking_option_file option will have to be changed)
        pair_aligner_options (eg if doing primate-primate alignments)
        bed_dir if running pairaligner_stats module

    #4. Run init_pipeline.pl script:
        Using command line arguments:
        init_pipeline.pl Bio::EnsEMBL::Compara::PipeConfig::PairAligner_conf --dbname hsap_ggor_lastz_64 --password <your_password) --mlss_id 536 --dump_dir /lustre/scratch103/ensembl/kb3/scratch/hive/release_64/hsap_ggor_nib_files/ --pair_aligner_options "T=1 K=5000 L=5000 H=3000 M=10 O=400 E=30 Q=/nfs/users/nfs_k/kb3/work/hive/data/primate.matrix --ambiguous=iupac" --bed_dir /nfs/ensembl/compara/dumps/bed/

        Using a configuration file:
        init_pipeline.pl Bio::EnsEMBL::Compara::PipeConfig::PairAligner_conf --password <your_password> --reg_conf reg.conf --conf_file input.conf --config_url mysql://user:pass\@host:port/db_name

    #5. Run the "beekeeper.pl ... -loop" command suggested by init_pipeline.pl


=head1 DESCRIPTION  

    The PipeConfig file for PairAligner pipeline that should automate most of the tasks. This is in need of further work, especially to deal with multiple pairs of species in the same database. Currently this is dealt with by using the same configuration file as before and the filename should be provided on the command line (--conf_file). 

    You may need to provide a registry configuration file if the core databases have not been added to staging (--reg_conf).

    A single pair of species can be run either by using a configuration file or by providing specific parameters on the command line and using the default values set in this file. On the command line, you must provide the LASTZ_NET mlss which should have been added to the master database (--mlss_id). The directory to which the nib files will be dumped can be specified using --dump_dir or the default location will be used. All the necessary directories are automatically created if they do not already exist. It may be necessary to change the pair_aligner_options default if, for example, doing primate-primate alignments. It is recommended that you provide a meaningful database name (--dbname). The username is automatically prefixed to this, ie -dbname hsap_ggor_lastz_64 will become kb3_hsap_ggor_lastz_64. A basic healthcheck is run and output is written to the job_message table. To write to the pairwise configuration database, you must provide the correct config_url. Even if no config_url is given, the statistics are written to the job_message table.


=head1 CONTACT

  Please contact ehive-users@ebi.ac.uk mailing list with questions/suggestions.

=cut

package Bio::EnsEMBL::Compara::PipeConfig::Example::VegaPairAligner_conf;

use strict;
use warnings;
use base ('Bio::EnsEMBL::Compara::PipeConfig::PairAligner_conf');

sub default_options {
  my ($self) = @_;
  return {
    %{$self->SUPER::default_options},   # inherit the generic ones

    'release'               => '73',
    #'dbname'               => '', #Define on the command line via the conf_file

    # dependent parameters:
    'rel_with_suffix'       => $self->o('release').$self->o('release_suffix'),
    'pipeline_name'         => 'LASTZ_'.$self->o('rel_with_suffix'),   # name the pipeline to differentiate the submitted processes

    'pipeline_db' => {                                  # connection parameters
      -host   => 'vegabuild',
      -port   => 5304,
      -user   => 'ottadmin',
      -pass   => $self->o('password'), 
      -dbname => $self->o('ENV', 'USER').'_vega_ga_20130722_73',
    },

    #need to overwrite the value from ../Lastz_conf.pm
    'masking_options_file' => '',

	#Set for single pairwise mode
#	'mlss_id' => '',

	#Set to use pairwise configuration file
#	'conf_file' => '',

	#directory to dump nib files
    'dump_dir' => '/lustre/scratch109/ensembl/' . $ENV{USER} . '/pair_aligner/nib_files/' . 'release_' . $self->o('rel_with_suffix') . '/',

	#min length to dump dna as nib file
#	'dump_min_size' => 11500000, 

	#Use 'quick' method for finding max alignment length (ie max(genomic_align_block.length)) rather than the more
	#accurate method of max(genomic_align.dnafrag_end-genomic_align.dnafrag_start+1)
#	'quick' => 1,

	#Use transactions in pair_aligner and chaining/netting modules (eg LastZ.pm, PairAligner.pm, AlignmentProcessing.pm)
#	'do_transactions' => 1,

        #
	#Default filter_duplicates
	#
#        'window_size' => 1000000,

	#
	#Default pair_aligner
	
    'pair_aligner_exe' => '/software/ensembl/compara/bin/lastz',
        #
	#Default pairaligner config
	#
#    'skip_pairaligner_stats' => 0, #skip this module if set to 1
    'output_dir' => '/lustre/scratch109/ensembl/' . $ENV{USER} . '/vega_ga_20130722_'.$self->o('release'),
    'bed_dir' => '/lustre/scratch109/ensembl/' . $ENV{USER} . '/vega_ga_20130722_'.$self->o('release') .'/bed_dir',
    };
}

#inherits from e! and adds two more
sub resource_classes {
  my ($self) = @_;
  my $resources = $self->SUPER::resource_classes;
  $resources->{'7.5Gb'}    = { -desc => 'himem2, 8h',     'LSF' => '-C0 -M7500 -R"select[mem>7500] rusage[mem=7500]"' };
  $resources->{'basement'} = { -desc => 'himem3, notime', 'LSF' => '-C0 -M17000 -R"select[mem>17000] rusage[mem=17000]" -q "basement"' };
  return $resources;
}

#grab hold of the e! analyses and modify them for our use
sub pipeline_analyses {
  my ($self) = @_;
  my $analyses = $self->SUPER::pipeline_analyses;

  # we know these are not needed for Vega
  my %analyses_to_ignore = map { $_ => 1 } qw(
                                              populate_new_database
                                              no_chunk_and_group_dna
                                              dump_large_nib_for_chains_factory
                                              dump_large_nib_for_chains
                                              dump_large_nib_for_chains_himem
                                              create_alignment_chains_jobs
                                              alignment_chains
                                              alignment_chains_himem
                                              remove_inconsistencies_after_chain
                                              update_max_alignment_length_after_chain
                                              create_alignment_nets_jobs
                                              set_internal_ids
                                              alignment_nets
                                              alignment_nets_himem
                                              remove_inconsistencies_after_net
                                              update_max_alignment_length_after_net
                                              healthcheck
                                              pairaligner_stats
                                              master_db
                                            );

  #get all analyses that we know about
  my @e_analyses = @{&e_analyses};

  #remove analyses that we know we don't want to use / prompt when new ones from e! are found
  my @new_analyses;
  for (my $i = @$analyses; $i >= 0; --$i) {
    my $analysis = $analyses->[$i];
    my $name = $analysis->{'-logic_name'};
    next unless $name;
    if (! grep {$name eq $_} @e_analyses) {
      push @new_analyses, $name;
    }
    if ($analyses_to_ignore{$name}) {
      splice @$analyses, $i, 1
    }

    #modify get_species_list
    if ($name eq 'get_species_list') {
      foreach (qw(master_db reg_conf core_dbs)) {
        print "Vega fix - removed parameter for $_\n";
        delete $analyses->[$i]{'-parameters'}{$_};
      }
      print "Vega fix - modifying flow into parameter for $name\n";
      $analyses->[$i]{'-flow_into'} = { 1 => [ 'parse_pair_aligner_conf' ] };
    }

    #modify parse_pair_aligner_conf
    if ($name eq 'parse_pair_aligner_conf') {
      foreach (qw(default_chain_output default_net_output default_chain_input default_net_input registry_dbs master_db do_compare_to_previous_db)) {
        print "Vega fix - removed parameter for $_\n";
        delete $analyses->[$i]{'-parameters'}{$_};
      }
      my @unwanted_flows = qw(create_alignment_nets_jobs healthcheck create_alignment_chains_jobs no_chunk_and_group_dna pairaligner_stats);
      foreach my $flow (keys %{$analyses->[$i]{'-flow_into'}}) {
        if (grep {$analyses->[$i]{'-flow_into'}{$flow}[0] eq $_} @unwanted_flows) {
          print "Vega fix - removed flow control rule for ".$analyses->[$i]{'-flow_into'}{$flow}[0] . "\n";
          delete $analyses->[$i]{'-flow_into'}{$flow};
        }
      }
    }
    # for Vega 49 had to manually add filter duplicate high memory jobs into the basement. This should be fixed
    # by Kathryn for next time, but if not then the code below should do it. However note this is not tested at all

    ##Create a new analysis for filter duplicates_highmem where jobs are passed to the basement queue
#    if ($name eq 'filter_duplicates_himem') {
#      my $himem_basement = { %$analysis };
#      $analyses->[$i]{'-flow_into'}->{-2} = ['filter_duplicates_himem_basement'];
#      $analyses->[$i]{'-flow_into'}->{-1} = ['filter_duplicates_himem_basement'];
#      warn Data::Dumper::Dumper($analysis);
##
#
#      $himem_basement->{'-rc_name'} = 'basement';
#      $himem_basement->{'-logic_name'} = 'filter_duplicates_himem_basment';
#      warn Data::Dumper::Dumper($himem_basement); exit;
#      push @$analyses,$himem_basement; 
 #   }
  }
  if (@new_analyses) {
    foreach my $name (@new_analyses) {
      print "Ensembl analysis \'$name\' is not known to us in Vega - review and decide what to do with it\n";
    }
    exit;
  }
  return $analyses;
}

1;

sub e_analyses {
  my $txt;
  my $analyses = [qw(
                     LastZ
                     LastZ_himem1
                     create_pair_aligner_jobs
                     chunk_and_group_dna
                     pairaligner_stats
                     alignment_chains
                     remove_inconsistencies_after_chain
                     innodbise_table_factory
                     create_alignment_nets_jobs
                     alignment_nets_himem
                     update_max_alignment_length_after_FD
                     update_max_alignment_length_after_net
                     alignment_nets
                     update_max_alignment_length_before_FD
                     dump_dna
                     no_chunk_and_group_dna
                     populate_new_database
                     dump_large_nib_for_chains
                     filter_duplicates
                     parse_pair_aligner_conf
                     alignment_chains_himem
                     remove_inconsistencies_after_net
                     dump_large_nib_for_chains_himem
                     remove_inconsistencies_after_pairaligner
                     get_species_list
                     set_internal_ids
                     store_sequence_again
                     dump_dna_factory
                     create_filter_duplicates_jobs
                     subst pair_aligner_logic_name:
                     update_max_alignment_length_after_chain
                     create_alignment_chains_jobs
                     healthcheck
                     subst pair_aligner_logic_name
                     dump_large_nib_for_chains_factory
                     filter_duplicates_himem
                     innodbise_table
                     coding_exon_stats
                     coding_exon_stats_summary
                     store_sequence)];
  push @$analyses, '#:subst pair_aligner_logic_name:#_himem1';
  push @$analyses, '#:subst pair_aligner_logic_name:#';
  return $analyses;
}

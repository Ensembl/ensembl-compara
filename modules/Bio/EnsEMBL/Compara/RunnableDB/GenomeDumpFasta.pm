#
# You may distribute this module under the same terms as perl itself
#
# POD documentation - main docs before the code

=pod 

=head1 NAME

Bio::EnsEMBL::Compara::RunnableDB::GenomeDumpFasta

=cut

=head1 SYNOPSIS

my $db      = Bio::EnsEMBL::Compara::DBAdaptor->new($locator);
my $repmask = Bio::EnsEMBL::Compara::RunnableDB::GenomeDumpFasta->new (
                                                    -db      => $db,
                                                    -input_id   => $input_id
                                                    -analysis   => $analysis );
$repmask->fetch_input(); #reads from DB
$repmask->run();
$repmask->output();
$repmask->write_output(); #writes to DB

=cut

=head1 DESCRIPTION

This RunnableDB takes a genome_db as input and creates a blast database in a shared directory
and creates a corresponding blast_<genome> analysis off of the blast_template analysis.
The new genome specific analysis is given a logic name like blast_1_NCBI35.

=cut

=head1 CONTACT

  Contact Jessica Severin on module implemetation/design detail: jessica@ebi.ac.uk
  Contact Abel Ureta-Vidal on EnsEMBL/Compara: abel@ebi.ac.uk
  Contact Ewan Birney on EnsEMBL in general: birney@sanger.ac.uk

=cut

=head1 APPENDIX

The rest of the documentation details each of the object methods.
Internal methods are usually preceded with a _

=cut

package Bio::EnsEMBL::Compara::RunnableDB::GenomeDumpFasta;

use strict;

use Bio::EnsEMBL::Analysis::Tools::BlastDB;
use Bio::EnsEMBL::Utils::Exception;

use base ('Bio::EnsEMBL::Compara::RunnableDB::BaseRunnable');


=head2 fetch_input

    Title   :   fetch_input
    Usage   :   $self->fetch_input
    Function:   Fetches input data for repeatmasker from the database
    Returns :   none
    Args    :   none

=cut


sub fetch_input {
    my $self = shift @_;

    my $subset_id   = $self->param('ss') or die "'ss' is an obligatory parameter";
    my $subset      = $self->compara_dba->get_SubsetAdaptor()->fetch_by_dbID($subset_id) or die "cannot fetch Subset with id '$subset_id'";
    $self->param('subset', $subset);

    my $genome_db_id = $self->param('genome_db_id') || $self->param('genome_db_id', $self->param('gdb'))        # for compatibility
        or die "'genome_db_id' is an obligatory parameter";

    my $genome_db = $self->compara_dba->get_GenomeDBAdaptor->fetch_by_dbID($genome_db_id) or die "cannot fetch GenomeDB with id '$genome_db_id'";
    $self->param('genome_db', $genome_db);

    my $logic_name = $self->param('logic_name') || 'blast_'.$genome_db_id.'_'.$genome_db->assembly();
    $self->param('logic_name', $logic_name);
}


sub write_output {
    my $self = shift @_;

      # dump longest peptide subset for this genome_db_id to a fasta file
      # and configure it to be used as a blast database
    my $blastdb = $self->dumpPeptidesToFasta();

    my $blast_analysis = $self->createBlastAnalysis($blastdb);

    if(my $beforeblast_logic_name = $self->param('beforeblast_logic_name')) {
        my $beforeblast_analysis = $self->db->get_AnalysisAdaptor->fetch_by_logic_name($beforeblast_logic_name);
        $self->db->get_AnalysisCtrlRuleAdaptor->create_rule($beforeblast_analysis, $blast_analysis);
    }
    if(my $afterblast_logic_name = $self->param('afterblast_logic_name')) {
        my $afterblast_analysis = $self->db->get_AnalysisAdaptor->fetch_by_logic_name($afterblast_logic_name);
        $self->db->get_AnalysisCtrlRuleAdaptor->create_rule($blast_analysis, $afterblast_analysis);
    }

    $self->dataflow_output_id( { 'genome_db_id' => $self->param('genome_db_id'), 'ss' => $self->param('ss'), 'logic_name' => $self->param('logic_name') }, 2);
}


##################################
#
# subroutines
#
##################################


    # using the genome_db and longest peptides subset, create a fasta
    # file which can be used as a blast database
sub dumpPeptidesToFasta {
  my $self = shift;

  my $fastafile = $self->param('fasta_dir') . '/';
  if($self->param('genome_db')) {
    $fastafile .= $self->param('genome_db')->name() . "_" . 
                  $self->param('genome_db')->assembly() . ".fasta";
  } else {
    $fastafile .= $self->param('logic_name') . ".fasta";
  }
  $fastafile =~ s/\s+/_/g;    # replace whitespace with '_' characters
  $fastafile =~ s/\/\//\//g;  # converts any // in path to /
  print("fastafile = '$fastafile'\n");

  # write fasta file
  $self->compara_dba->get_SubsetAdaptor->dumpFastaForSubset($self->param('subset'), $fastafile);

  # configure the fasta file for use as a blast database file
  my $blastdb        = Bio::EnsEMBL::Analysis::Tools::BlastDB->new(
      -sequence_file => $fastafile,
      -mol_type => 'PROTEIN');
  $blastdb->create_blastdb;

  my $seq_name = $blastdb->sequence_file;
  my ($dbname) = $seq_name =~ /([^\/]+)$/;
  print("registered ". $dbname . " for ".$blastdb->sequence_file . "\n");

  return $blastdb;
}


    # create an analysis of type MemberPep for this fasta/blastdb
    # that will run module BlastComparaPep
sub createBlastAnalysis {
  my $self    = shift;
  my $blastdb = shift;

  my $blast_template = $self->db->get_AnalysisAdaptor->fetch_by_logic_name('blast_template');

  my $params = '{'.
    "subset_id=>" . $self->param('ss') .
    ",genome_db_id=>" . $self->param('genome_db_id') .
    ",fasta_dir=>'" . $self->param('fasta_dir') . "'";

  if($blast_template->parameters()) {
    my $parmhash = eval($blast_template->parameters);
    if (defined $parmhash->{'blast_template_analysis_data_id'}) {
      my $blast_template_analysis_data_id = $parmhash->{'blast_template_analysis_data_id'};
      my $ada = $self->db->get_AnalysisDataAdaptor;
      my $new_params = eval($ada->fetch_by_dbID($blast_template_analysis_data_id));
      if (defined $new_params) {
        $parmhash = $new_params;
      }
    }
    if($parmhash->{'null_cigar'}) {
      $params .= ",null_cigar=>'" . $parmhash->{'null_cigar'} . "'";
    }
    if($parmhash->{'mlss_id'}) {
      $params .= ",mlss_id=>'" . $parmhash->{'mlss_id'} . "'";
    }
    if($parmhash->{'reuse_db'}) {
      $params .= ",reuse_db=>'" . $parmhash->{'reuse_db'} . "'";
    }
    if($parmhash->{'reuse_gdb'}) {
      $params .= ",reuse_gdb=>" . "[". join(",",@{$parmhash->{'reuse_gdb'}}). "]";
    }
    if($parmhash->{'options'}) {
      $params .= ",options=>'" . $parmhash->{'options'} . "'";
    }
  }
  $params .= '}';
  
  print("createBlastAnalysis\n  params = $params\n");
  my $seq_name = $blastdb->sequence_file;
  my ($dbname) = $seq_name =~ /([^\/]+)$/;

  my $analysis = Bio::EnsEMBL::Analysis->new(
      -db              => $dbname,
      -db_file         => $blastdb->sequence_file,
      -db_version      => '1',
      -logic_name      => $self->param('logic_name'),
      -program         => $blast_template->program(),
      -program_file    => $blast_template->program_file(),
      -program_version => $blast_template->program_version(),
      -module          => $blast_template->module(),
      -parameters      => $params,
  );

  $self->db->get_AnalysisAdaptor()->store($analysis);

  my $stats = $self->db->get_AnalysisStatsAdaptor->fetch_by_analysis_id($analysis->dbID);
  $stats->batch_size(    $self->param('blast_hive_batch_size') ||  40 );
  $stats->hive_capacity( $self->param('blast_hive_capacity')   || 450 );
  
  #If we support resources copy the ID from the blast_template
  if($self->_hive_supports_resources()) {
    my $rc_id = $blast_template->stats()->rc_id();
    $stats->rc_id($rc_id);
  }
  
  $stats->update();
  
  return $analysis;
}


#If we can get the resource adaptor then we assume that we have 
#AnalysisStats::rc_id available.
sub _hive_supports_resources {
  my ($self) = @_;
  my $okay = 0;
  eval {
    $self->hive_dba()->get_ResourceDescriptionAdaptor();
    $okay = 1;
  };
  return $okay;
}

1;

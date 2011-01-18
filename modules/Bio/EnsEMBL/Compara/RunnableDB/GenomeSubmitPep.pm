#
# You may distribute this module under the same terms as perl itself
#
# POD documentation - main docs before the code

=pod 

=head1 NAME

Bio::EnsEMBL::Compara::RunnableDB::GenomeSubmitPep

=cut

=head1 SYNOPSIS

my $db      = Bio::EnsEMBL::Compara::DBAdaptor->new($locator);
my $repmask = Bio::EnsEMBL::Compara::RunnableDB::GenomeSubmitPep->new (
                                                    -db      => $db,
                                                    -input_id   => $input_id
                                                    -analysis   => $analysis );
$repmask->fetch_input(); #reads from DB
$repmask->run();
$repmask->output();
$repmask->write_output(); #writes to DB

=cut

=head1 DESCRIPTION

Process module which takes the member peptides defined in a subset and genome_db
passed in the input_id and creates an new analysis and fills it with these peptides
as jobs to be flowed into the Blast analyses.

=cut

=head1 CONTACT

Describe contact details here

=cut

=head1 APPENDIX

The rest of the documentation details each of the object methods.
Internal methods are usually preceded with a _

=cut

package Bio::EnsEMBL::Compara::RunnableDB::GenomeSubmitPep;

use strict;

use Bio::EnsEMBL::Utils::Exception;
use Bio::EnsEMBL::Hive::DBSQL::AnalysisStatsAdaptor;
use Bio::EnsEMBL::Hive::DBSQL::AnalysisJobAdaptor;


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

    my $logic_name = $self->param('logic_name') || 'SubmitPep_'.$genome_db_id.'_'.$genome_db->assembly();
    $self->param('logic_name', $logic_name);
}


sub run {
    my $self = shift @_;

    $self->create_peptide_align_feature_table($self->param('genome_db'));
}


sub write_output {
    my $self = shift @_;

          # working from the longest peptide subset, create an analysis of
          # with logic_name 'SubmitPep_<taxon_id>_<assembly>'
          # with type MemberPep and fill the input_id_analysis table where
          # input_id is the member_id of a peptide and the analysis_id
          # is the above mentioned analysis
          #
          # This creates the starting point for the blasts (members against database)

    my $logic_name = $self->param('logic_name');
    my $subset     = $self->param('subset');

    my $analysis =  $self->db->get_AnalysisAdaptor->fetch_by_logic_name($logic_name) ||
                        $self->createSubmitPepAnalysis($logic_name, $subset);

    my $new_format = $self->param('new_format');

    $self->createJobsInAnalysis($analysis, $subset, $new_format);
}


##################################
#
# subroutines
#
##################################


sub create_peptide_align_feature_table {
  my ($self, $genome_db) = @_;

  my $genome_db_id = $genome_db->dbID;
  my $species_name = lc($genome_db->name);
  $species_name =~ s/\ /\_/g;
  my $table_name = "peptide_align_feature_${species_name}_${genome_db_id}";
  my $sql = "CREATE TABLE IF NOT EXISTS $table_name like peptide_align_feature";

  my $sth = $self->compara_dba->dbc->prepare($sql);
  $sth->execute();

  # Disable keys makes inserts faster
  $sql = "ALTER TABLE $table_name DISABLE KEYS";

  $sth = $self->compara_dba->dbc->prepare($sql);
  $sth->execute();
  $sth->finish();
}


        # working from the longest peptide subset, create an analysis of
        # with logic_name 'SubmitPep_<taxon_id>_<assembly>'
        # with type MemberPep and fill the input_id_analysis table where
        # input_id is the member_id of a peptide and the analysis_id
        # is the above mentioned analysis
        #
        # This creates the starting point for the blasts (members against database)
sub createSubmitPepAnalysis {
    my ($self, $logic_name, $subset) = @_;

    my $analysis = Bio::EnsEMBL::Analysis->new(
        -db              => '',
        -db_file         => $subset->dump_loc(),
        -db_version      => '1',
        -parameters      => "{subset_id=>" . $subset->dbID()."}",
        -logic_name      => $logic_name,
        -module          => 'Bio::EnsEMBL::Hive::RunnableDB::Dummy',
    );
    $self->db->get_AnalysisAdaptor()->store($analysis);

    my $stats = $self->db->get_AnalysisStatsAdaptor->fetch_by_analysis_id($analysis->dbID);
    $stats->batch_size(500);
    $stats->hive_capacity(10);
    $stats->status('BLOCKED');

    if($self->_hive_supports_resources()) {
        my $blast_template = $self->db->get_AnalysisAdaptor->fetch_by_logic_name('blast_template');
        my $rc_id = $blast_template->rc_id();
        $stats->rc_id($rc_id);
    }

    $stats->update();   

    # create unblocking rules from CreateBlastRules to this new analysis
    my $createRules = $self->db->get_AnalysisAdaptor->fetch_by_logic_name('CreateBlastRules');
    $self->db->get_AnalysisCtrlRuleAdaptor->create_rule($createRules, $analysis);

    return $analysis;
}


sub createJobsInAnalysis {
    my ($self, $analysis, $subset, $new_format) = @_;

    my @member_id_list = @{$subset->member_id_list()};

    foreach my $member_id (@member_id_list) {
        Bio::EnsEMBL::Hive::DBSQL::AnalysisJobAdaptor->CreateNewJob (
            -input_id       => ($new_format ? "{'member_id'=>$member_id}" : $member_id),
            -analysis       => $analysis,
            -input_job_id   => $self->input_job->dbID,
        );
    }
}


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

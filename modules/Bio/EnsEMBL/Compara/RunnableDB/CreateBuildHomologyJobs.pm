#
# You may distribute this module under the same terms as perl itself
#
# POD documentation - main docs before the code

=pod 

=head1 NAME

Bio::EnsEMBL::Compara::RunnableDB::CreateBuildHomologyJobs

=cut

=head1 SYNOPSIS

my $aa = $sdba->get_AnalysisAdaptor;
my $analysis = $aa->fetch_by_logic_name('CreateBuildHomologyJobs');
my $rdb = new Bio::EnsEMBL::Compara::RunnableDB::CreateBuildHomologyJobs(
                         -input_id   => [[1,2,3,14],[4,13],[11,16]]
                         -analysis   => $analysis);

$rdb->fetch_input
$rdb->run;

=cut

=head1 DESCRIPTION

This is a homology compara specific runnableDB, that based on an input
of arrayrefs of genome_db_ids, creates Homology_dNdS jobs in the hive 
analysis_job table.

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

package Bio::EnsEMBL::Compara::RunnableDB::CreateBuildHomologyJobs;

use strict;
use Bio::EnsEMBL::Compara::DBSQL::DBAdaptor;
use Bio::EnsEMBL::Hive;

use Bio::EnsEMBL::Hive::Process;
our @ISA = qw(Bio::EnsEMBL::Hive::Process);

sub fetch_input {
  my( $self) = @_;

  $self->{'species_sets_aref'} = undef;
  $self->throw("No input_id") unless defined($self->input_id);

  #create a Compara::DBAdaptor which shares the same DBI handle
  #with the pipeline DBAdaptor that is based into this runnable
  $self->{'comparaDBA'} = Bio::EnsEMBL::Compara::DBSQL::DBAdaptor->new(-DBCONN=>$self->db->dbc);

  $self->get_params($self->input_id);
  return 1;
}

sub get_params {
  my $self         = shift;
  my $param_string = shift;

  return unless($param_string);
  print("parsing parameter string : ",$param_string,"\n");
  
  my $params = eval($param_string);
  return unless($params);

  foreach my $key (keys %$params) {
    print("  $key : ", $params->{$key}, "\n");
  }

  if (defined $params->{'species_sets'}) {
    $self->{'species_sets_aref'} = $params->{'species_sets'};
  }
  
  return;
}

sub run
{
  my $self = shift;
  return 1 unless($self->{'species_sets_aref'});
  
  $self->create_analysis_jobs($self->{'species_sets_aref'});
  
  return 1;
}

sub write_output {
  my $self = shift;
  return 1;
}

##########################################
#
# internal methods
#
##########################################

sub create_analysis_jobs {
  my $self = shift;
  my $species_sets_aref = shift;

  foreach my $species_set (@{$species_sets_aref}) {
    while (my $gdb1 = shift @{$species_set}) {
      my $genome_db1 = $self->{'comparaDBA'}->get_GenomeDBAdaptor->fetch_by_dbID($gdb1);
      next unless($genome_db1);
      foreach my $gdb2 (@{$species_set}) {
        my $genome_db2 = $self->{'comparaDBA'}->get_GenomeDBAdaptor->fetch_by_dbID($gdb2);
        next unless($genome_db2);
        $self->createBuildHomologyJob($genome_db1, $genome_db2);
      }
    }
  }
}


sub createBuildHomologyJob
{
  my $self = shift;
  my $genome_db1 = shift;
  my $genome_db2 = shift;
  my $noRHS = shift;

  my $logic_name1 = 'blast_' .$genome_db1->dbID."_".$genome_db1->assembly;
  my $logic_name2 = 'blast_' .$genome_db2->dbID."_".$genome_db2->assembly;

  my $phylum1 = $self->phylumForGenomeDBID($genome_db1->dbID);
  my $phylum2 = $self->phylumForGenomeDBID($genome_db2->dbID);
  $noRHS='noRHS' if(!defined($noRHS) and $phylum1 ne $phylum2);

  my $output_id;

  if($genome_db1->dbID < $genome_db2->dbID) {
    $output_id = "{blasts=>['".$logic_name1 . "','". $logic_name2 . "']";
  } else {
    $output_id = "{blasts=>['".$logic_name2 . "','". $logic_name1 . "']";
  }
  if($noRHS and ($noRHS eq 'noRHS')) { $output_id .= ",noRHS=>1"; }
  $output_id .= "}";
  print("HOMOLOGY '$output_id'\n");


  # dataflow the output_id on branch_code 2, which will be configured in the graph
  # to flow into BuildHomology

  $self->dataflow_output_id($output_id, 2);

}


sub phylumForGenomeDBID
{
  my $self = shift;
  my $genome_db_id = shift;
  my $phylum;

  unless($genome_db_id) { return undef; }

  my $sql = "SELECT phylum FROM genome_db_extn " .
            "WHERE genome_db_id=$genome_db_id;";
  my $sth = $self->db->dbc->prepare( $sql );
  $sth->execute();
  $sth->bind_columns( undef, \$phylum );
  $sth->fetch();
  $sth->finish();

  return $phylum;
}



1;

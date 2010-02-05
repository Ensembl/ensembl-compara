#
# You may distribute this module under the same terms as perl itself
#
# POD documentation - main docs before the code

=pod 

=head1 NAME

Bio::EnsEMBL::Compara::RunnableDB::CreateNeighbourNodesJobs

=cut

=head1 SYNOPSIS

my $db      = Bio::EnsEMBL::Compara::DBAdaptor->new($locator);
my $low_coverage_aligment = Bio::EnsEMBL::Pipeline::RunnableDB::CreateNeighbourNodesJobs->new (
                                                    -db      => $db,
                                                    -input_id   => $input_id
                                                    -analysis   => $analysis );
$set_neighbour_nodes->fetch_input(); #reads from DB
$set_neighbour_nodes->run();
$set_neighbour_nodes->write_output(); #writes to DB

=cut

=head1 DESCRIPTION

=cut

=head1 CONTACT

Describe contact details here

=cut

=head1 APPENDIX

The rest of the documentation details each of the object methods.
Internal methods are usually preceded with a _

=cut

package Bio::EnsEMBL::Compara::Production::GenomicAlignBlock::CreateNeighbourNodesJobs;

use strict;

use Bio::EnsEMBL::Hive;
use Bio::EnsEMBL::Compara::Production::DBSQL::DBAdaptor;

use Bio::EnsEMBL::Analysis::RunnableDB;
use Bio::EnsEMBL::Hive::Process
our @ISA = qw(Bio::EnsEMBL::Hive::Process);

sub fetch_input {
  my $self = shift;

  #
  # parameters which can be set either via
  # $self->parameters OR
  # $self->input_id
  #
  $self->get_params($self->parameters);
  $self->get_params($self->input_id);

  # create a Compara::DBAdaptor which shares my DBConnection
  $self->{'comparaDBA'} = Bio::EnsEMBL::Compara::Production::DBSQL::DBAdaptor->new(-DBCONN => $self->db->dbc);

  return 1;
}


sub run
{
  my $self = shift;

  $self->createSetNeighbourNodesJobs();
  return 1;
}


sub write_output
{
  my $self = shift;
  return 1;
}

##################################
#
# subroutines
#
##################################

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
  if (defined($params->{'method_link_species_set_id'})) {
      $self->method_link_species_set_id($params->{'method_link_species_set_id'});
  }
                      
  return;
}
##########################################
#
# getter/setter methods
# 
##########################################

sub method_link_species_set_id {
  my $self = shift;
  $self->{'_method_link_species_set_id'} = shift if(@_);
  return $self->{'_method_link_species_set_id'};
}

sub createSetNeighbourNodesJobs
{
  my $self = shift;

  my $gab_adaptor = $self->{'comparaDBA'}->get_GenomicAlignBlockAdaptor;

  my $analysis = $self->db->get_AnalysisAdaptor->fetch_by_logic_name("SetNeighbourNodes");

  #Need to select genomic_align_blocks which are not ancestral segments
  #The quickest way is to query the database rather than go through the api

  my $dbname = $self->{'comparaDBA'}->dbc->dbname;
  my $analysis_id = $analysis->dbID;

  #NOTE: must have deleted base (9way) alignment before we get here.
  my $sql =  "select node_id from genomic_align_tree where parent_id = 0";

  my $sth = $self->{'comparaDBA'}->dbc->prepare($sql);
  $sth->execute();
  
  my $node_id;
  my @node_ids;
  $sth->bind_columns(\$node_id);
  while ($sth->fetch()) {
      push @node_ids, $node_id;
  }
  $sth->finish();

  my $count = 0;
  foreach my $node_id (@node_ids) {
      my $input_id = "{root_id=>" . $node_id . 
	",method_link_species_set_id=>" . $self->method_link_species_set_id . "}";
      Bio::EnsEMBL::Hive::DBSQL::AnalysisJobAdaptor->CreateNewJob (
        -input_id       => $input_id,
        -analysis       => $analysis,
        -input_job_id   => 0,
        );
      $count++;
  }
  printf("created %d jobs for SetNeighbourNodes\n", $count);
}

1;

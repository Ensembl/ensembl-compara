#
# You may distribute this module under the same terms as perl itself
#
# POD documentation - main docs before the code

=pod 

=head1 NAME

Bio::EnsEMBL::Compara::RunnableDB::CreateLowCoverageAlignmentJobs

=cut

=head1 SYNOPSIS

my $db      = Bio::EnsEMBL::Compara::DBAdaptor->new($locator);
my $low_coverage_aligment = Bio::EnsEMBL::Pipeline::RunnableDB::CreateLowCoverageAlignmentJobs->new (
                                                    -db      => $db,
                                                    -input_id   => $input_id
                                                    -analysis   => $analysis );
$low_coverage_aligment->fetch_input(); #reads from DB
$low_coverage_aligment->run();
$low_coverage_aligment->write_output(); #writes to DB

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

package Bio::EnsEMBL::Compara::Production::GenomicAlignBlock::CreateLowCoverageJobs;

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
  $self->{'base_method_link_species_set_id'}    = undef;
  $self->{'new_method_link_species_set_id'} = undef;
  $self->{'tree_analysis_data_id'} = undef;
  $self->{'pairwise_analysis_data_id'} = undef;
  $self->{'reference_species'} = undef;
  $self->{'taxon_tree_analysis_data_id'} = undef;

  $self->get_params($self->parameters);
  $self->get_params($self->input_id);

  #throw("Must specify import alignment logic name of ImportAlignment analysis (import_alignment_logic_name)")
  #  unless (!defined $self->import_alignment_logic_name);

  throw("Must specify the method_link_species_set_id for the alignment you wish to import (method_link_species_set_id)")
    unless (defined $self->base_method_link_species_set_id);

  # create a Compara::DBAdaptor which shares my DBConnection
  $self->{'comparaDBA'} = Bio::EnsEMBL::Compara::Production::DBSQL::DBAdaptor->new(-DBCONN => $self->db->dbc);

  return 1;
}


sub run
{
  my $self = shift;
  $self->createLowCoverageGenomeAlignmentJobs();
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
                      
  #if(defined($params->{'import_alignment_logic_name'})) {
   # $self->import_alignment_logic_name($params->{'import_alignment_logic_name'});
  #}
 
  if(defined($params->{'base_method_link_species_set_id'})) {
    $self->base_method_link_species_set_id($params->{'base_method_link_species_set_id'});
  }
  if(defined($params->{'new_method_link_species_set_id'})) {
    $self->new_method_link_species_set_id($params->{'new_method_link_species_set_id'});
  }
 if (defined($params->{'tree_analysis_data_id'})) {
      $self->tree_analysis_data_id($params->{'tree_analysis_data_id'});
  }
 if (defined($params->{'pairwise_analysis_data_id'})) {
      $self->pairwise_analysis_data_id($params->{'pairwise_analysis_data_id'});
  }
 if (defined($params->{'taxon_tree_analysis_data_id'})) {
      $self->taxon_tree_analysis_data_id($params->{'taxon_tree_analysis_data_id'});
  }
 if (defined($params->{'reference_species'})) {
      $self->reference_species($params->{'reference_species'});
  }
  
  return;
}

##########################################
#
# getter/setter methods
# 
##########################################
sub base_method_link_species_set_id {
  my $self = shift;
  $self->{'_base_method_link_species_set_id'} = shift if(@_);
  return $self->{'_base_method_link_species_set_id'};
}

sub new_method_link_species_set_id {
  my $self = shift;
  $self->{'_new_method_link_species_set_id'} = shift if(@_);
  return $self->{'_new_method_link_species_set_id'};
}

sub tree_analysis_data_id {
  my $self = shift;
  $self->{'_tree_analysis_data_id'} = shift if(@_);
  return $self->{'_tree_analysis_data_id'};
}
sub pairwise_analysis_data_id {
  my $self = shift;
  $self->{'_pairwise_analysis_data_id'} = shift if(@_);
  return $self->{'_pairwise_analysis_data_id'};
}
sub taxon_tree_analysis_data_id {
  my $self = shift;
  $self->{'_taxon_tree_analysis_data_id'} = shift if(@_);
  return $self->{'_taxon_tree_analysis_data_id'};
}
sub reference_species {
  my $self = shift;
  $self->{'_reference_species'} = shift if(@_);
  return $self->{'_reference_species'};
}

sub createLowCoverageGenomeAlignmentJobs
{
  my $self = shift;

  my $gab_adaptor = $self->{'comparaDBA'}->get_GenomicAlignBlockAdaptor;
  my $mlss_adaptor = $self->{'comparaDBA'}->get_MethodLinkSpeciesSetAdaptor;
  throw ("No method_link_species_set") if (!$mlss_adaptor);

  my $base_mlss = $mlss_adaptor->fetch_by_dbID($self->base_method_link_species_set_id);

  my $analysis = $self->db->get_AnalysisAdaptor->fetch_by_logic_name("LowCoverageGenomeAlignment");

  #Need to select genomic_align_blocks which are not ancestral segments
  #The quickest way is to query the database rather than go through the api

  my $dbname = $self->{'comparaDBA'}->dbc->dbname;
  my $analysis_id = $analysis->dbID;

  my $sql = "select genomic_align_block_id from genomic_align_block gab left join genomic_align ga using (genomic_align_block_id) left join dnafrag using (dnafrag_id) where gab.method_link_species_set_id=? and genome_db_id <> 63 group by genomic_align_block_id;";

  print "sql $sql " . $self->base_method_link_species_set_id . "\n";

  my $sth = $self->{'comparaDBA'}->dbc->prepare($sql);
  $sth->execute($self->base_method_link_species_set_id);
  
  my $genomic_align_block_id;
  my @genomic_align_block_ids;
  $sth->bind_columns(\$genomic_align_block_id);
  while ($sth->fetch()) {
      push @genomic_align_block_ids, $genomic_align_block_id;
  }
  $sth->finish();

  my $count = 0;
  foreach my $genomic_align_block_id (@genomic_align_block_ids) {
      my $input_id = "{genomic_align_block_id=>" . $genomic_align_block_id . 
	",method_link_species_set_id=>" . $self->new_method_link_species_set_id . 
	",tree_analysis_data_id=>" . $self->tree_analysis_data_id . 
	",pairwise_analysis_data_id=>" . $self->pairwise_analysis_data_id . 
	",taxon_tree_analysis_data_id=>" . $self->taxon_tree_analysis_data_id . 
	",reference_species=>'" . $self->reference_species . "'}";
      Bio::EnsEMBL::Hive::DBSQL::AnalysisJobAdaptor->CreateNewJob (
        -input_id       => $input_id,
        -analysis       => $analysis,
        -input_job_id   => 0,
        );
      $count++;
  }
  printf("created %d jobs for LowCoverageGenomeAlignment\n", $count);
}

1;

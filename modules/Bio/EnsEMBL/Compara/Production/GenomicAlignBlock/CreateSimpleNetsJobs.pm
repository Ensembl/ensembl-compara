#
# You may distribute this module under the same terms as perl itself
#
# POD documentation - main docs before the code

=pod 

=head1 NAME

Bio::EnsEMBL::Compara::RunnableDB::CreateSimpleNetsJobs

=cut

=head1 SYNOPSIS

my $db      = Bio::EnsEMBL::Compara::DBAdaptor->new($locator);
my $runnableDB = Bio::EnsEMBL::Pipeline::RunnableDB::CreateSimpleNetsJobs->new (
                                                    -input_id  => $input_id
                                                    -analysis   => $analysis );
$runnableDB->fetch_input(); #reads from DB
$runnableDB->run();
$runnableDB->output();
$runnableDB->write_output(); #writes to DB

=cut

=head1 DESCRIPTION

=cut

=head1 CONTACT

Abel Ureta-Vidal <abel@ebi.ac.uk>

=cut

=head1 APPENDIX

The rest of the documentation details each of the object methods.
Internal methods are usually preceded with a _

=cut

package Bio::EnsEMBL::Compara::Production::GenomicAlignBlock::CreateSimpleNetsJobs;

use strict;

use Bio::EnsEMBL::Compara::Production::DBSQL::DBAdaptor;
use Bio::EnsEMBL::Hive::DBSQL::AnalysisJobAdaptor;
use Bio::EnsEMBL::Hive::Process;
use Bio::EnsEMBL::Utils::Exception;

our @ISA = qw(Bio::EnsEMBL::Hive::Process);



sub fetch_input {
  my $self = shift;

  $self->get_params($self->parameters);
  $self->get_params($self->input_id);

  # get DnaCollection of query
  throw("must specify 'query_genome_db_id' to identify query of net") 
      if not defined $self->QUERY_GENOME_DB_ID;
  
  throw("must specify 'target_genome_db_id' to target of net") 
      if not defined $self->TARGET_GENOME_DB_ID;

  $self->compara_db(Bio::EnsEMBL::Compara::Production::DBSQL::DBAdaptor
                    ->new(-DBCONN => $self->db->dbc));

  my $mlss = $self->compara_db->get_MethodLinkSpeciesSetAdaptor
      ->fetch_by_method_link_type_genome_db_ids($self->INPUT_METHOD_LINK,
                                                [$self->QUERY_GENOME_DB_ID, $self->TARGET_GENOME_DB_ID]);

  throw("Could not identity a source MLSS from " . 
        $self->INPUT_METHOD_LINK . " " .
        $self->QUERY_GENOME_DB_ID . " " . 
        $self->TARGET_GENOME_DB_DB)
      if not defined $mlss;

  $self->input_method_link_species_set($mlss);

  my $out_analysis = $self->db->get_AnalysisAdaptor->fetch_by_logic_name($self->LOGIC_NAME);
  throw("Could not get output analysis object from " . $self->LOGIC_NAME)
      if not defined $out_analysis;

  $self->output_analysis($out_analysis);

  return 1;
}


sub get_params {
  my ($self, $param_string) = @_;

  return unless($param_string);
  print("parsing parameter string : ",$param_string,"\n");
  
  my $params = eval($param_string);
  return unless($params);

  # most parameters can be passed straight through to the job. 
  # we are concerned with the ones specific to each job here

  if (exists $params->{query_genome_db_id}) {
    $self->QUERY_GENOME_DB_ID($params->{query_genome_db_id});
  }
  if (exists $params->{target_genome_db_id}) {
    $self->TARGET_GENOME_DB_ID($params->{target_genome_db_id});
  }
  if (exists $params->{input_method_link}) {
    $self->INPUT_METHOD_LINK($params->{input_method_link});
  }
  if (exists $params->{logic_name}) {
    $self->LOGIC_NAME($params->{logic_name});
  }

}


sub run {
  my $self = shift;

  $self->createAlignmentNetsJobs();

  return 1;
}


sub write_output {
  my $self = shift;

  my $output_id_hash = {
    query_genome_db_id => $self->QUERY_GENOME_DB_ID,
    target_genom_db_id => $self->TARGET_GENOME_DB_ID,
  };
  my $output_id = $self->encode_hash($output_id_hash);

  $self->dataflow_output_id($output_id, 2);
  return 1;
}


sub createAlignmentNetsJobs {
  my $self = shift;

  # assumption: we only need to consider qy_dnafrags that have
  # alignments from the specified mlss, and dont need to consider
  # the target genome_db_id

  my $sql = "select distinct d.dnafrag_id ";
  $sql .= "from genomic_align ga, dnafrag d ";
  $sql .= "where ga.dnafrag_id = d.dnafrag_id ";
  $sql .= "and method_link_species_set_id = ? ";
  $sql .= "and genome_db_id = ?";

  my $sth = $self->compara_db->dbc->prepare($sql);
  $sth->execute($self->input_method_link_species_set->dbID, 
                $self->QUERY_GENOME_DB_ID);

  my ($qy_dnafrag_id);
  $sth->bind_columns(\$qy_dnafrag_id);
  my @qy_dnafrag_ids;
  while ($sth->fetch()) {
    push @qy_dnafrag_ids, $qy_dnafrag_id;
  }
  $sth->finish;

  foreach my $id (@qy_dnafrag_ids) {
    my $input_hash = {
      qy_dnafrag_id => $id,
      tg_genomedb_id => $self->TARGET_GENOME_DB_ID,
    };
    
    my $input_id = $self->encode_hash($input_hash);
    Bio::EnsEMBL::Hive::DBSQL::AnalysisJobAdaptor->CreateNewJob
        (-input_id       => $input_id,
         -analysis       => $self->output_analysis,
         -input_job_id   => 0);
  }
}


######################

sub compara_db {
  my ($self, $val) = @_;
  
  if (defined $val) {
    $self->{_compara_db} = $val;
  }
  
  return $self->{_compara_db};
}

sub input_method_link_species_set {
  my ($self, $val) = @_;

  if (defined $val) {
    $self->{_input_mlss} = $val;
  }

  return $self->{_input_mlss};
}


sub output_analysis {
  my ($self, $val) = @_;

  if (defined $val) {
    $self->{_output_analysis} = $val;
  }

  return $self->{_output_analysis};
}




#########
# Config variables
#########

sub QUERY_GENOME_DB_ID {
  my ($self, $val) = @_;

  if (defined $val){
    $self->{_query_genome_db_id} = $val;
  }
  return $self->{_query_genome_db_id};
}


sub TARGET_GENOME_DB_ID {
  my ($self, $val) = @_;

  if (defined $val){
    $self->{_target_genome_db_id} = $val;
  }
  return $self->{_target_genome_db_id};
}


sub INPUT_METHOD_LINK {
  my ($self, $val) = @_;

  if (defined $val){
    $self->{_input_method_link} = $val;
  }
  return $self->{_input_method_link};
}

sub LOGIC_NAME {
  my ($self, $val) = @_;

  if (defined $val) {
    $self->{_output_logic_name} = $val;
  }

  return $self->{_output_logic_name};
}

1;

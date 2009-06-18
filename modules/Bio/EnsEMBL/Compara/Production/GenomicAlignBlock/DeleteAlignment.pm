#
# You may distribute this module under the same terms as perl itself
#
# POD documentation - main docs before the code

=pod 

=head1 NAME

Bio::EnsEMBL::Compara::Production::GenomicAlignBlock::DeleteAlignment

=head1 SYNOPSIS


=head1 DESCRIPTION

This module deletes a specified alignment. This is used in the low coverage genome alignment pipeline for deleting the high coverage alignment which is used to build the low coverage genomes on.

=head1 PARAMETERS

=head1 CONTACT

Post questions to the Ensembl development list: ensembl-dev@ebi.ac.uk


=head1 APPENDIX

The rest of the documentation details each of the object methods. 
Internal methods are usually preceded with a _

=cut

package Bio::EnsEMBL::Compara::Production::GenomicAlignBlock::DeleteAlignment;

use strict;
use Bio::EnsEMBL::Registry;
use Bio::EnsEMBL::Compara::Production::DBSQL::DBAdaptor;
use Bio::EnsEMBL::Utils::Exception qw(throw);
use Bio::EnsEMBL::Compara::Graph::NewickParser;

use Bio::EnsEMBL::Hive::Process;

our @ISA = qw(Bio::EnsEMBL::Hive::Process);


=head2 fetch_input

    Title   :   fetch_input
    Usage   :   $self->fetch_input
    Function:   Fetches input data for gerp from the database
    Returns :   none
    Args    :   none

=cut

sub fetch_input {
  my( $self) = @_;

  #create a Compara::DBAdaptor which shares the same DBI handle
  #with $self->db (Hive DBAdaptor)
  $self->{'comparaDBA'} = Bio::EnsEMBL::Compara::Production::DBSQL::DBAdaptor->new(-DBCONN=>$self->db->dbc);
  $self->{'comparaDBA'}->dbc->disconnect_when_inactive(0);

   $self->{'hiveDBA'} = Bio::EnsEMBL::Hive::DBSQL::DBAdaptor->new(-DBCONN => $self->{'comparaDBA'}->dbc);

  #read from analysis table
  $self->get_params($self->parameters); 

  #read from analysis_job table
  $self->get_params($self->input_id);
  
}

=head2 run

    Title   :   run
    Usage   :   $self->run
    Function:   Run gerp
    Returns :   none
    Args    :   none

=cut

sub run {
    my $self = shift;
    $self->deleteAlignment();
}

=head2 write_output

    Title   :   write_output
    Usage   :   $self->write_output
    Function:   Write results to the database
    Returns :   1
    Args    :   none

=cut

sub write_output {
    my ($self) = @_;

    return 1;
}

#Deletes genomic_align_block, genomic_align, genomic_align_group and 
#genomic_align_tree of the high coverage alignment
sub deleteAlignment {
    my $self = shift;

    #delete genomic_align_tree
    my $sql = "delete genomic_align_tree from genomic_align_tree left join genomic_align_group on (node_id=group_id) left join genomic_align using (genomic_align_id) left join genomic_align_block using (genomic_align_block_id) where genomic_align_block.method_link_species_set_id=?";

    my $sth = $self->{'comparaDBA'}->dbc->prepare($sql);
    $sth->execute($self->method_link_species_set_id);
    $sth->finish();

    #delete genomic_align_group
    $sql = "delete genomic_align_group from genomic_align_group left join genomic_align using (genomic_align_id) left join genomic_align_block using (genomic_align_block_id) where genomic_align_block.method_link_species_set_id=?";

    $sth = $self->{'comparaDBA'}->dbc->prepare($sql);
    $sth->execute($self->method_link_species_set_id);
    $sth->finish();

    #delete genomic_align
    $sql = "delete genomic_align from genomic_align left join genomic_align_block using (genomic_align_block_id) where genomic_align_block.method_link_species_set_id=?";
    $sth = $self->{'comparaDBA'}->dbc->prepare($sql);
    $sth->execute($self->method_link_species_set_id);
    $sth->finish();

    #delete genomic_align_block
    $sql = "delete from genomic_align_block where method_link_species_set_id=?;";
    $sth = $self->{'comparaDBA'}->dbc->prepare($sql);
    $sth->execute($self->method_link_species_set_id);
    $sth->finish();
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

##########################################
#
# internal methods
#
##########################################

sub get_params {
  my $self         = shift;
  my $param_string = shift;

  return unless($param_string);
  print("parsing parameter string : ",$param_string,"\n");

  my $params = eval($param_string);
  return unless($params);

  if(defined($params->{'method_link_species_set_id'})) {
    $self->method_link_species_set_id($params->{'method_link_species_set_id'});
  }
  return 1;
}

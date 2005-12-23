#
# You may distribute this module under the same terms as perl itself
#
# POD documentation - main docs before the code

=pod 

=head1 NAME

Bio::EnsEMBL::Compara::Production::GenomicAlignBlock::FilterDuplicates

=cut

=head1 SYNOPSIS

my $db       = Bio::EnsEMBL::Compara::DBAdaptor->new($locator);
my $runnable = Bio::EnsEMBL::Pipeline::RunnableDB::FilterDuplicates->new (
                                                    -db      => $db,
                                                    -input_id   => $input_id
                                                    -analysis   => $analysis );
$runnable->fetch_input(); #reads from DB
$runnable->run();
$runnable->write_output(); #writes to DB

=cut

=head1 DESCRIPTION

This analysis/RunnableDB is designed to run after all GenomicAlignBlock entries for a 
specific MethodLinkSpeciesSet has been completed and filters out all duplicate entries
which can result from jobs being rerun or from regions of overlapping chunks generating
the same HSP hits.  It takes as input (on the input_id string) 

=cut

=head1 CONTACT

Describe contact details here

=cut

=head1 APPENDIX

The rest of the documentation details each of the object methods.
Internal methods are usually preceded with a _

=cut

package Bio::EnsEMBL::Compara::Production::GenomicAlignBlock::UpdateMaxAlignmentLength;

use strict;
use Time::HiRes qw(time gettimeofday tv_interval);
use Bio::EnsEMBL::Utils::Exception qw( throw warning verbose );
use Bio::EnsEMBL::Compara::Production::DBSQL::DBAdaptor;

use Bio::EnsEMBL::Pipeline::RunnableDB;
our @ISA = qw(Bio::EnsEMBL::Pipeline::RunnableDB);


=head2 fetch_input

    Title   :   fetch_input
    Usage   :   $self->fetch_input
    Function:   prepares global variables and DB connections
    Returns :   none
    Args    :   none

=cut

sub fetch_input {
  my( $self) = @_;

  #
  # parameters which can be set either via
  # $self->parameters OR
  # $self->input_id
  #
  $self->debug(0);

  #create a Compara::DBAdaptor which shares the same DBI handle
  #with the Pipeline::DBAdaptor that is based into this runnable
  $self->{'comparaDBA'} = Bio::EnsEMBL::Compara::Production::DBSQL::DBAdaptor->new(-DBCONN => $self->db->dbc);
  $self->{'comparaDBA'}->dbc->disconnect_when_inactive(0);
    
  return 1;
}


sub run
{
  my $self = shift;
  $self->update_meta_table;
  return 1;
}


sub write_output 
{
  my $self = shift;

  my $output_id = $self->input_id;

  print("output_id = $output_id\n");
  $self->input_id($output_id);
  return 1;
}


######################################
#
# subroutines
#
#####################################

sub update_meta_table {
  my $self = shift;

  my $dba = $self->{'comparaDBA'};
  my $mc = $dba->get_MetaContainer;

  $dba->dbc->do("analyze table genomic_align_block");
  $dba->dbc->do("analyze table genomic_align");
  $dba->dbc->do("analyze table genomic_align_group");

  my $sth = $dba->dbc->prepare("SELECT method_link_species_set_id,max(dnafrag_end - dnafrag_start + 1) FROM genomic_align group by method_link_species_set_id");
  $sth->execute();
  my $max_alignment_length = 0;
  my ($method_link_species_set_id,$max_align);
  $sth->bind_columns(\$method_link_species_set_id,\$max_align);

  while ($sth->fetch()) {
    my $key = "max_align_".$method_link_species_set_id;
    $mc->delete_key($key);
    $mc->store_key_value($key, $max_align + 1);
    $max_alignment_length = $max_align if ($max_align > $max_alignment_length);
    print STDERR "Stored key:$key value:",$max_align + 1," in meta table\n";
  }
  $mc->delete_key("max_alignment_length");
  $mc->store_key_value("max_alignment_length", $max_alignment_length + 1);
  print STDERR "Stored key:max_alignment_length value:",$max_alignment_length + 1," in meta table\n";

  $sth->finish;

}

1;

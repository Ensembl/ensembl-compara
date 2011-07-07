#
# You may distribute this module under the same terms as perl itself
#
# POD documentation - main docs before the code

=pod 

=head1 NAME

Bio::EnsEMBL::Compara::RunnableDB::FindSingleGenesOnTree

=cut

=head1 SYNOPSIS

my $db           = Bio::EnsEMBL::Compara::DBAdaptor->new($locator);
my $find_single_gene = Bio::EnsEMBL::Compara::RunnableDB::FindSingleGenesOnTree->new
  (
   -db         => $db,
   -input_id   => $input_id,
   -analysis   => $analysis
  );
$find_single_gene->fetch_input(); #reads from DB
$find_single_gene->run();
$find_single_gene->output();
$find_single_gene->write_output(); #writes to DB

=cut


=head1 DESCRIPTION

This Analysis will take a protein tree id and look for single gene of a species.
Those genes will be possible partial genes.

=cut


=head1 CONTACT

  Contact Thomas Maurel on module implementation/design detail: maurel@ebi.ac.uk
  Contact Javier Herrero on Split/partial genes in general: jherrero@ebi.ac.uk

=cut

=head1 APPENDIX

The rest of the documentation details each of the object methods. 
Internal methods are usually preceded with a _

=cut


package Bio::EnsEMBL::Compara::RunnableDB::FindSingleGenesOnTree;

use strict;

use base ('Bio::EnsEMBL::Compara::RunnableDB::BaseRunnable');
use List::Util qw[min max];

sub fetch_input {
  my $self = shift @_; 

  my $protein_tree_id  = $self->param('protein_tree_id') or die "'protein_tree_id' is an obligatory parameter";
  my $protein_tree_adaptor = $self->compara_dba->get_ProteinTreeAdaptor();
      # if fetch_node_by_node_id is insufficient, try fetch_tree_at_node_id
  my $protein_tree = $protein_tree_adaptor->fetch_node_by_node_id($protein_tree_id) or die "Could not fetch protein_tree by id=$protein_tree_id";
  $self->param('protein_tree', $protein_tree);
  $self->dbc->disconnect_when_inactive(1);
}

sub run {
  my $self = shift @_; 
  my $protein_tree = $self->param('protein_tree');
  my $kingdom = $self->param('kingdom') or '(none)';
  my @output_ids = (); 
  my @perc_pos=();
  my $first_loop=0;
  my %members=();
  my %pos_occupancy=();

# get all leaves,  all members of the tree
my @aligned_members = @{$protein_tree->get_all_leaves};
my @single_in_tree =();
#for each member get member of a species alone in the alignment
for (my $i=0;$i<@aligned_members;$i++)
{
  my $species_i=$aligned_members[$i]->genome_db->name;
  my $species_cpt=0;
  my $final_score=0;
#compare to other members
  for (my $j=0;$j<@aligned_members;$j++)
  {
#not the same members
    if($i==$j)
    {   
      next;
    }   
    if ($aligned_members[$j]->genome_db->name eq $species_i)
    {   
      $species_cpt++;
    }   
  }
  if ($species_cpt==0)
  {
    push(@single_in_tree,$aligned_members[$i]);
  }
}

foreach my $aligned_member (@single_in_tree){
#Push all result into an array
  push @output_ids, {
    'gene_stable_id' => $aligned_member->gene_member->stable_id,
      'protein_tree_stable_id' => $protein_tree->stable_id,
      'species_name' => $aligned_member->genome_db->name,
      'kingdom' => $kingdom,
 };

}
$self->param('output_ids', \@output_ids);
}
sub write_output {
  my $self = shift @_;
 
  my $output_ids = $self->param('output_ids');
 
  $self->dbc->disconnect_when_inactive(0);
  $self->dataflow_output_id($output_ids, 3);
}



1;


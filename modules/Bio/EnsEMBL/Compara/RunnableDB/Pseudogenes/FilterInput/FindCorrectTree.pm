package FilterInput::FindCorrectTree;

use strict;
use warnings;

use base ('Bio::EnsEMBL::Compara::RunnableDB::BaseRunnable');

use Data::Dumper;

sub fetch_input
{
  my $self = shift @_;

  my $compara_dba = $self->compara_dba;

  $self->param('tree_adaptor', $compara_dba->get_GeneTreeAdaptor);
  $self->param('gene_adaptor', $compara_dba->get_GeneMemberAdaptor);
}

sub run
{
  my $self = shift @_;

  my $align_data = $self->param('data');
  my $tree_adaptor = $self->param('tree_adaptor');
  my $gene_adaptor = $self->param('gene_adaptor');
  my %output_data;
  my %trees_to_create;

  foreach my $this_pseudogene(keys $align_data)
  {
    my @genes = keys $align_data->{$this_pseudogene};

    ## Tree set contains a hash of all tree, where the value is the lowest evalue for the alignments in that tree
    my %tree_set;
    my $tree;
    foreach my $gene_id(@genes)
    {
      my $gene = $gene_adaptor->fetch_by_stable_id($gene_id);
      $tree = $tree_adaptor->fetch_default_for_Member($gene);
      next unless $tree && $tree->stable_id;
      if(!exists($tree_set{$tree->stable_id}) || $tree_set{$tree->stable_id} < $align_data->{$gene_id}->{'score'})
      {
        $tree_set{$tree->stable_id} = $align_data->{$gene_id}->{'score'};
      }
    }
  


    ## If there is at least one tree 
    if(scalar keys %tree_set > 0)
    {
        my $best_tree = undef;
        my $min_evalue;
        foreach my $tree_id(keys %tree_set)
        {
          my $evalue = $tree_set{$tree->stable_id};
          if(!defined($best_tree) || $evalue < $tree_set{$tree->stable_id})
          {
	          $best_tree = $tree_id;
	          $min_evalue = $evalue;
          }
        }
        $output_data{$best_tree} .= $this_pseudogene.",";
    }

    ## If the gene functionnal gene isn't placed in any tree yet
    else
    {
      my $best_gene = shift(@genes);
      while(@genes)
      {
        my $candidate = shift(@genes);
        $best_gene = $candidate if($align_data->{$best_gene}->{'score'} < $align_data->{$candidate}->{'score'});
      }
      $trees_to_create{$best_gene} .= $this_pseudogene.",";
    }
  }
  ## print(Dumper(\%output_data)."\n");
  foreach my $tree_id(keys %output_data)
  {
    $self->dataflow_output_id( {'tree_stable_id' => $tree_id, 'pseudogenes' => $output_data{$tree_id}}, 3);
  }

  foreach my $gene_id(keys %trees_to_create)
  {
    $self->dataflow_output_id( {'functional_gene' => $gene_id, 'pseudogenes' => $trees_to_create{$gene_id}}, 4);
  }
}

1;

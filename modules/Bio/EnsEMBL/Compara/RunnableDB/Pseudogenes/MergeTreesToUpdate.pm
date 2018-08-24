use strict;
use warnings;

package MergeTreesToUpdate;

use Data::Dumper;
use base ('Bio::EnsEMBL::Compara::RunnableDB::BaseRunnable');

sub fetch_input
{
    my $self = shift;

    $self->param('gene_member_adaptor', $self->compara_dba->get_GeneMemberAdaptor);
}

sub run
{
  my $self = shift;

  my $gene_member_adaptor = $self->param('gene_member_adaptor');
  my %trees_to_create = %{$self->param('new_tree_data')};
  my %trees_to_update = %{$self->param('all_pairs')};
  my @to_remove;

  foreach my $parent_gene(keys %trees_to_create)
  {
    my $gene_member = $gene_member_adaptor->fetch_by_stable_id($parent_gene);    
    

    ## In case the parent gene is a pseudogene, we check for all tree to check if we plan to insert this gene somewhere
    my $tree_containing = 0;
    my $actual_tree = undef;
    if ($gene_member->biotype_group =~ /pseudogene/)
    {
      foreach my $tree(keys %trees_to_update)
      {
        if(grep { $_ =~ /$parent_gene/} @{$trees_to_update{$tree}})
        {
          $tree_containing++;
          $actual_tree = $tree;
        }
      }

      ## If the pseudogene is not inserted in any tree, we try insert it in the tree of one of its children
      unless($tree_containing)
      {
        warn $parent_gene, " is a pseudogene that has no parent in the given sets of homologies";
        foreach my $pseudogenes_list(@{$trees_to_create{$parent_gene}})
        {
          foreach my $pseudogene(split ',', $pseudogenes_list)
          {
            foreach my $tree(keys %trees_to_update)
            {
              if(grep { $_ =~ /$pseudogene/} @{$trees_to_update{$tree}} and $tree ne $actual_tree)
              {
                $tree_containing ++;
                $actual_tree = $tree;
              }
            }
          }
        }
      }
      die sprintf("Gene %s is a pseudogene that can be inserted in more than 1 (%d) trees", $parent_gene, $tree_containing) if($tree_containing > 1);

      if($tree_containing)
      {
        push @{$trees_to_update{$actual_tree}}, $trees_to_create{$parent_gene};
        push @{$trees_to_update{$actual_tree}}, [$parent_gene.","];
        push @to_remove, $parent_gene;
      }
    }

    ## If the gene is not a pseudogene, make sure that it is not a readthrough
    else
    {
      my $skip = 0;
      foreach my $seq_member(@{$gene_member->get_all_SeqMembers})
      {
        $skip += $seq_member->get_Transcript->get_all_Attributes('readthrough_tra');
      }
      if($skip)
      {
        push @to_remove, $parent_gene;
      }
    }
  }

  foreach my $key(@to_remove)
  {
    delete $trees_to_create{$key};
  }

  foreach my $key(keys %trees_to_update)
  {
    my $join = join '', @{$trees_to_update{$key}};
    my @split = split ',', $join;
    my @unique = @{rm_doubles(\@split)};
    my $final = join ',', @unique;
    $trees_to_update{$key} = $final;
    ## Many jobs that will update the trees (1 per tree)
    $self->dataflow_output_id({'tree_stable_id' => $key, 'pseudogenes' => $trees_to_update{$key}}, 2);
  }

  foreach my $key(keys %trees_to_create)
  {
    my $join = join '', @{$trees_to_create{$key}};
    my @split = split ',', $join;
    my @unique = @{rm_doubles(\@split)};
    my $final = join ',', @unique;
    $trees_to_create{$key} = $final;
  }

  ## One job that will create all new clusters
  $self->dataflow_output_id({'cluster_data' => \%trees_to_create}, 1);

}

sub rm_doubles
{
  my $list = shift;
  my %vals;
  foreach my $elt(@$list)
  {
    $vals{$elt} = 1;
  }
  return [keys %vals];
}

1;

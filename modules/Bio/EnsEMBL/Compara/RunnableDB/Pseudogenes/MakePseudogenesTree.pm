use strict;
use warnings;

package  Bio::EnsEMBL::Compara::RunnableDB::Pseudogenes::MakePseudogenesTree;

use base ('Bio::EnsEMBL::Compara::RunnableDB::GeneTrees::StoreClusters');

sub fetch_input
{
    my $self = shift;

    $self->param('gene_member_adaptor', $self->compara_dba->get_GeneMemberAdaptor);
}

sub run
{
    my $self = shift;

    my $gene_member_adaptor = $self->param('gene_member_adaptor');

    my %allclusters = ();
    my $cluster_id = 423325;

    ## OLD Request : Could create trees when the gene aligned with the parent but has another alignment in a given tree  
    ## my $sql = qq{SELECT CONCAT_WS(',', parent_id, GROUP_CONCAT(pseudogene_id SEPARATOR ',')) AS genes FROM pseudogenes_data WHERE tree_id IS NULL and status = "OK" GROUP BY parent_id};
    
    my $sql = qq{SELECT CONCAT_WS(',', parent_id, GROUP_CONCAT(pseudogene_id SEPARATOR ',')) AS genes FROM good_pseudogenes WHERE pseudogene_id in (SELECT pseudogene_id FROM good_pseudogenes WHERE pseudogene_id in (SELECT pseudogene_id FROM good_pseudogenes WHERE tree_id IS NULL) GROUP BY pseudogene_id HAVING COUNT(*) = 1) GROUP BY parent_id};
    my $sth = $self->compara_dba->dbc->prepare($sql);
    $sth->execute();

    while (my $h = $sth->fetchrow_hashref()) {
      my %this_row = %$h;
      my @cluster_list;

      foreach my $pseudogene(split ',', $this_row{'genes'})
      {
        my $gene = $gene_member_adaptor->fetch_by_stable_id($pseudogene);
        next unless(defined($gene));
        my $seq = $gene->get_canonical_SeqMember;
        if($gene->biotype_group =~ /pseudogene/)
        {
          foreach my $this_seq(@{$gene->get_all_SeqMembers})
          {
               print($this_seq->stable_id." : ".$this_seq->get_Transcript->biotype."\n") if($self->debug > 7);
               if($this_seq->get_Transcript->biotype =~ /pseudogene/)
               {
                    $seq = $this_seq;
               }
           }
         }
         push @cluster_list, $seq->dbID;
      }
      $allclusters{$cluster_id} = {'members' => \@cluster_list};
      $cluster_id++;
    }

    $sth->finish();
    $self->param('allclusters', \%allclusters);
}

sub write_output {
    my $self = shift @_;

    my $ids = $self->store_clusterset('default', $self->param('allclusters'));
    print(scalar @$ids, " trees created");
    foreach my $gene_id(@$ids)
    {
       $self->dataflow_output_id({'gene_tree_id' => $gene_id}, 2);
    }
}

1;

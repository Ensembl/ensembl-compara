package FilterInput::VerifyAssociation;

use strict;
use warnings;

use Bio::EnsEMBL::DBSQL::DBAdaptor;
use Capture::Tiny':all';
use Data::Dumper;

use base ('Bio::EnsEMBL::Compara::RunnableDB::BaseRunnable');

sub fetch_input
{
  my $self = shift @_;

  $self->param('gene_member_adaptor', $self->compara_dba->get_GeneMemberAdaptor);
}

sub run
{
  my $self = shift @_;  

  my $gene_member_adaptor = $self->param('gene_member_adaptor');
  ## my @associations = @{$self->param('assoc')};
  my @associations = @{$self->param('associations')};

  my %result;

  foreach my $this_pair(@associations)
  {
    my @genes_id = split(/\-/, $this_pair);
    my $pseudogene = $gene_member_adaptor->fetch_by_stable_id($genes_id[0]);
    my $parent_gene = $gene_member_adaptor->fetch_by_stable_id($genes_id[1]);
  
    ## Only Keeping homologies on the reference frag
    next unless ($pseudogene->dnafrag->is_reference and $parent_gene->dnafrag->is_reference);
    my $res = compute_all_alignments($self, $pseudogene, $parent_gene); ## Computing all alignements and store the results in the tree.
  
    if($res)
    {
      if(!(defined($result{$pseudogene})))
      {
        $result{$genes_id[0]} = ();
      }
      $result{$genes_id[0]}->{$genes_id[1]} = $res;
    }
    else
    {
      #printf("No alignement between genes %s and %s\n", $genes_id[0], $genes_id[1]); 
    }
  }
  $self->dataflow_output_id({'data' => \%result}, 1);
}

sub print_to_fasta
{
	my($self, $seq, $path)=@_;
	
	open(my $f, '>', $path);
	printf($f ">Fasta Sequence\n");

	my $count = 0;
	foreach my $c(split (//, $seq))
	{
		printf($f $c);
		if(++$count % 100 == 0)
		{
			printf($f "\n");
		}
	}
	close($f);
}


## Computes the alignement between two sequences and return the score of the alignment
sub compute_alignment
{
  my ($self, $query_sequence, $subject_sequence) = @_;
	
  my $worker_tmp = $self->worker_temp_directory;

  print_to_fasta($self, $query_sequence->other_sequence('cds'), "$worker_tmp/query_sequence.fa");
  print_to_fasta($self, $subject_sequence->other_sequence('cds'), "$worker_tmp/subject_sequence.fa");

  $self->run_command("tblastx -query $worker_tmp/query_sequence.fa -subject $worker_tmp/subject_sequence.fa -out $worker_tmp/output.txt -evalue 1e-4 -outfmt \'6 qlen slen length score evalue\'", { die_on_failure => 1 });
  my $cmd_out = $self->run_command("cat $worker_tmp/output.txt");
  if($cmd_out->out)
  {
    my @tab = split("\n", $cmd_out->out);
    ## print("\t\t".$tab[0]."\n");
    my @info = split("\t", $tab[0]);
    ## print(Dumper(\@info));
    my $hash = {'pseudogene_transcript' => $query_sequence->stable_id,
                'parent_transcript' => $subject_sequence->stable_id,
                'evalue' => $info[4],
                'score' => $info[3],
                'lenght' => $info[2],
                'pseudogene_coverage' => 100 * $info[2] / $info[0],
                };

    return $hash; 
  }
}

sub compute_all_alignments
{
  my ($self, $pseudogene, $parent) = @_;

  # printf("Comparing alignments between the genes %s and %s.\n", $pseudogene->stable_id, $parent->stable_id);
  my $best_eval = 1;
  my $hash;

  foreach my $pseudogene_membertranscript(@{$pseudogene->get_all_SeqMembers})
  {
    foreach my $parent_transcript(@{$parent->get_all_SeqMembers})
    {
      ## printf("\tComparing alignments between transcripts %s and %s.\n", $pseudogene_membertranscript->stable_id, $parent_transcript->stable_id);
      my $test = compute_alignment($self, $pseudogene_membertranscript, $parent_transcript);
      if($test and $test->{'evalue'} < $best_eval)
      {
        $hash = $test;
      }
    }
  }
  return $hash;
}

1;

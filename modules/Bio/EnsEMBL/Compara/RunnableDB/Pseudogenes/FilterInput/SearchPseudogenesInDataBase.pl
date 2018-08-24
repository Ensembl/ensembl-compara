=head
This file takes as input a file at least columns containing a slice (Chromosome:Start-End)
and a parent protein/Transcript/Gene and fetches all pseudogenes in the slice.

=cut

package FilterInput::SearchPseudogenesInDataBase;

use strict;
use warnings;

use Bio::EnsEMBL::DBSQL::DBAdaptor;
use Capture::Tiny':all';

use base ('Bio::EnsEMBL::Compara::RunnableDB::BaseRunnable');

sub fetch_input
{
  my $self = shift @_;
  
  die "The path to the file has to be defined.\n" unless $self->param('path');
  die sprintf("Could not read the file %s \n", $self->param('path')) unless -e $self->param('path'); 

  die "The specie has to be defined" unless defined($self->param('target_species'));
  die "The ref specie has to be defined" unless defined($self->param('ref_species'));
  
  $self->param('target_adaptor', get_correct_adaptor($self, $self->param('target_species'), $self->param('target_type')));
  $self->param('ref_adaptor', get_correct_adaptor($self, $self->param('ref_species'), $self->param('ref_type')));

  my $compara_dba = $self->compara_dba;
  $self->param('tree_adaptor', $compara_dba->get_GeneTreeAdaptor);
  $self->param('gene_member_adaptor', $compara_dba->get_GeneMemberAdaptor);
}

sub run
{
  my $self = shift @_;

  my $target_adaptor = $self->param('target_adaptor');
  my $ref_adaptor = $self->param('ref_adaptor');

  open(my $fd, '<', $self->param('path'));
  my $execs = 0;  

  my $input1;
  my $input2;

  ## For each line of the file
  foreach my $line(@{self->param('lines')})
  {
		$execs ++;

    my $count = 0;

		## Parsing all the info of the line
		my @params;
		my @words = split(" ", $line);
    my $genes;
    my $parents;

    push @params, $words[$self->param("target_col")];
    push @params, $words[$self->param("target_col") + 1];
    push @params, $words[$self->param("target_col") + 2];

    ## Gathering the prediction site
    if($self->param('target_type') eq 'slice')
    {
      my $slice = $target_adaptor->fetch_by_region("chromosome", $params[0], $params[1], $params[2]);
    
      if(!defined($slice))
      {
        print("Could not extract slice at coordinates ".$params[0].":".$params[1]."-".$params[2]."\n");
        next;
      }

      $genes = $slice->get_all_Genes();
      $input1 = $params[0]." ".$params[1]." ".$params[2];
    }

    else
    {
      if($params[0] =~ /(ENS[^\.]*)/)
      {
        $params[0] = $1;
      }
      else
      {
        next;
      }
      my $elem = $target_adaptor->fetch_by_stable_id($params[0]);
      next unless defined($elem);
      $elem = get_gene_object_from_other($elem, $self->param('target_type'));
      $genes = [$elem];
      $input1 = $params[0];
    }

    ## Gathering the parent prot
    push(@params, $words[$self->param("ref_col")]);
    push(@params, $words[$self->param("ref_col") + 1]);
    push(@params, $words[$self->param("ref_col") + 2]);
    ## Strips the stable id in order to remove the possible .X extension

    if($self->param('ref_type') eq 'slice')
    {
      my $slice = $ref_adaptor->fetch_by_region("chromosome", $params[3], $params[4], $params[5]);
    
      if(!defined($slice))
      {
        print("Could not extract slice at coordinates ".$params[3].":".$params[4]."-".$params[5]."\n");
        next;
      }

      $input2 = $params[3]." ".$params[4]." ".$params[5];
      $parents = $slice->get_all_Genes();
    }

    else
    {
      if($params[3] =~ /(ENS[^\.]*)/)
      {
        $params[3] = $1;
      }
      else
      {
        next;
      }
      my $elem = $ref_adaptor->fetch_by_stable_id($params[3]);
      next unless defined($elem);
      $elem = get_gene_object_from_other($elem, $self->param('ref_type'));
      $parents = [$elem];
      $input2 = $params[3];
    }

    print("Candidates: ", scalar @$genes, " Parents: ", scalar @$parents, "\n") if ($self->debug > 6);

    ## Registers all the regions where

    foreach my $parent_gene(@$parents)
    {
      if((scalar @$genes) == 0)tree_id
      {
        store_info($self, $parent_gene, undef, undef, $input1, $input2, "NO GENE", $execs);
        next;
      }

      foreach my $this_gene(@$genes)
      {
        ## Excluding polymorphic pseudogenes because they are not real pseudogene and will double the number of homologies from the given gene
        ## And willhave an homology with itself...
        ## TODO: Change with $this_gene->get_Biotype->biotype_group to work with e!93 
        if($this_gene->biotype =~ m/pseudogene/ and $this_gene->biotype !~ m/(P|p)olymorphic/)
        {
          ## Compute the alignement between the parent gene and the pseudogene
          my $aln_data = compute_all_alignments($self, $this_gene, $parent_gene);
          store_info($self, $parent_gene, $this_gene, $aln_data, $input1, $input2, "ALIGNMENT", $execs);
        } 
      }
    }
  }
}

sub store_info
{
  my $self = shift;
  my ($parent, $pseudogene, $aln_data, $pseudo_input, $parent_input, $status, $line) = @_;

  my $sql = "REPLACE INTO pseudogenes_data (parent_id, pseudogene_id, tree_id, score, evalue, parent_species, parent_query, parent_type, pseudogene_species, pseudogene_query, pseudogene_type, status, filepath, line) VALUES (?,?,?,?,?,?,?,?,?,?,?,?,?,?)";
  my $sth = $self->compara_dba->dbc->prepare($sql);
  if($aln_data)
  {
    $sth->execute($parent->stable_id, $pseudogene->stable_id, get_tree_id($self, $parent->stable_id), $aln_data->{score}, $aln_data->{evalue}, $self->param('ref_species'), $parent_input, $self->param('ref_type'), $self->param('target_species'), $pseudo_input, $self->param('target_type'), "OK", $self->param('path'), $line);
  }
  else
  {
    $sth->execute($parent->stable_id, $pseudogene ? $pseudogene->stable_id : undef, undef, undef, undef, $self->param('ref_species'), $parent_input, $self->param('ref_type'), $self->param('target_species'), $pseudo_input, $self->param('target_type'), $status, $self->param('path'), $line);
  }
  $sth->finish;
}

sub get_correct_adaptor
{
    my ($self, $species, $type) = @_;
    my $compara_dba = $self->compara_dba;
    
    Bio::EnsEMBL::Registry->load_registry_from_url($self->param('registry_url')); ## or die sprintf( "Could not load registry for url %s", $self->param('registry_url'));
    my $core_dba = Bio::EnsEMBL::Registry->get_DBAdaptor($species, 'core') or die sprintf( "Could not find specie %s in registry %s", $species, $self->param('registry_url'));

    ## Fetches the right adaptor to use
    if($type eq 'gene')
    {
      return $compara_dba->get_GeneMemberAdaptor;
    }
    elsif($type eq 'sequence')
    {
      return $compara_dba->get_SeqMemberAdaptor;
    }
    elsif($type eq 'transcript')
    {
      return $core_dba->get_TranscriptAdaptor;
    }
    elsif($type eq 'protein')
    {
      return $core_dba->get_TranslationAdaptor;
    }
    elsif($type eq 'slice')
    {
      return $core_dba->get_SliceAdaptor;
    }
    die "Type of element shoul be one of gene, sequence, slice, protein, transcript";
}

sub get_gene_object_from_other
{
    my ($elem, $type) = @_;
    return $elem->gene_member if($type eq 'sequence');
    return $elem->transcript->get_Gene if($type eq 'protein');
    return $elem->get_Gene if($type eq 'transcript'); 	
    return $elem->get_Gene if($type eq 'gene'); 
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
  my ($self, $query, $subject) = @_;
	
  my $worker_tmp = $self->worker_temp_directory;

  print_to_fasta($self, get_Sequence($query), "$worker_tmp/query_sequence.fa");
  print_to_fasta($self, get_Sequence($subject), "$worker_tmp/subject_sequence.fa");

  $self->run_command("tblastx -query $worker_tmp/query_sequence.fa -subject $worker_tmp/subject_sequence.fa -out $worker_tmp/output.txt -evalue 1e-4 -outfmt \'6 qlen slen length score evalue\'", { die_on_failure => 1 });
  my $cmd_out = $self->run_command("cat $worker_tmp/output.txt");
  if($cmd_out->out)
  {
    my @tab = split("\n", $cmd_out->out);
    ## print("\t\t".$tab[0]."\n");
    my @info = split("\t", $tab[0]);
    ## print(Dumper(\@info));
    

    my $hash = {'pseudogene_transcript' => $query->stable_id,
                'parent_transcript' => $subject->stable_id,
                'evalue' => $info[4],
                'score' => $info[3],
                'lenght' => $info[2],
                'pseudogene_coverage' => 100 * $info[2] / $info[0],
                };

    return $hash; 
  }
}

### Return the hash containing informations about the best alignment (lowest e-value) between the parent gene and the pseudogene
sub compute_all_alignments
{
  my ($self, $pseudogene, $parent) = @_;

  # printf("Comparing alignments between the genes %s and %s.\n", $pseudogene->stable_id, $parent->stable_id);
  my $best_eval = 1;
  my $hash;

  foreach my $pseudogene_seq(get_all_Sequences($pseudogene))
  {
    foreach my $parent_seq(get_all_Sequences($parent))
    {
      ## printf("\tComparing alignments between transcripts %s and %s.\n", $pseudogene_membertranscript->stable_id, $parent_transcript->stable_id);
      my $test = compute_alignment($self, $pseudogene_seq, $parent_seq);
      if($test and $test->{'evalue'} < $best_eval)
      {
        $hash = $test;
      }
    }
  }
  return $hash;
}

sub get_all_Sequences
{
	my $object = shift;
	if (ref $object =~ /GeneMember/)
	{
		return @{$object->get_all_SeqMembers};
	}
	else
	{
		return @{$object->get_all_Transcripts};
	}
}

sub get_Sequence
{
	my $object = shift;
	if (ref $object =~ /SeqMember/)
	{
		return $object->other_sequence('cds');
	}
	return $object->seq->seq;
}

sub get_tree_id
{
  my $self = shift;
  my $stable_id = shift;

  my $gene = $self->param('gene_member_adaptor')->fetch_by_stable_id($stable_id);
  return undef unless($gene);
  my $tree = $self->param('tree_adaptor')->fetch_default_for_Member($gene);
  return $tree ? $tree->root_id : undef;
}

1;

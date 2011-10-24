#
# You may distribute this module under the same terms as perl itself
#
# POD documentation - main docs before the code

=pod 

=head1 NAME

Bio::EnsEMBL::Compara::RunnableDB::FindSplitGenesOnTree

=cut

=head1 SYNOPSIS

my $db           = Bio::EnsEMBL::Compara::DBAdaptor->new($locator);
my $find_split_genes = Bio::EnsEMBL::Compara::RunnableDB::FindSplitGenesOnTree->new
  (
   -db         => $db,
   -input_id   => $input_id,
   -analysis   => $analysis
  );
$find_split_genes->fetch_input(); #reads from DB
$find_split_genes->run();
$find_split_genes->output();
$find_split_genes->write_output(); #writes to DB

=cut


=head1 DESCRIPTION

This Analysis will take a protein tree id and calcul the species intersection score, alignment overlap score, overlap, etc. 
for each possible pair of split genes 

=cut


=head1 CONTACT

  Contact Thomas Maurel on module implementation/design detail: maurel@ebi.ac.uk
  Contact Javier Herrero on Split/partial genes in general: jherrero@ebi.ac.uk

=cut


=head1 APPENDIX

The rest of the documentation details each of the object methods. 
Internal methods are usually preceded with a _

=cut


package Bio::EnsEMBL::Compara::RunnableDB::FindSplitGenesOnTree;

use strict;

use base ('Bio::EnsEMBL::Compara::RunnableDB::BaseRunnable');

sub fetch_input {
  my $self = shift @_;

  my $protein_tree_id      = $self->param('protein_tree_id') or die "'protein_tree_id' is an obligatory parameter";
  my $protein_tree_adaptor = $self->compara_dba->get_ProteinTreeAdaptor();
      # if fetch_node_by_node_id is insufficient, try fetch_tree_at_node_id
  my $protein_tree         = $protein_tree_adaptor->fetch_node_by_node_id($protein_tree_id) or die "Could not fetch protein_tree by id=$protein_tree_id";
  $self->param('protein_tree', $protein_tree);
  my $homology_adaptor     = $self->compara_dba->get_HomologyAdaptor();
  my $homologies           = $homology_adaptor->fetch_all_by_tree_node_id($protein_tree_id);
  $self->param('homologies', $homologies);

  $self->dbc->disconnect_when_inactive(1);
}


sub run {
  my $self = shift @_;

  my $protein_tree = $self->param('protein_tree');
  my $homologies   = $self->param('homologies');
  my $kingdom      = $self->param('kingdom') or '(none)';
  my @output_ids = ();

        # That will return a reference to an array with all homologies (orthologues in
        # other species and paralogues in the same one)
        # And then only split gene are kept in a array called @homologie_split_gene
        my @homologies_split_gene=();
        foreach my $homologies_search (@{$homologies}) 
        {
          if ($homologies_search->description =~ /gene_split/)
          {
            push (@homologies_split_gene,$homologies_search);
          } 
        }
 

        my %pairs_of_split_genes = ();
        foreach my $homology (@homologies_split_gene)
        {
        # You will find different kind of description
        # UBRH, MBRH, RHS, YoungParalogues
        # see ensembl-compara/docs/docs/schema_doc.html for more details
          my ($member1, $member2) = @{$homology->get_all_Members};
          if(defined $member1)
          {
            $pairs_of_split_genes{$member1->stable_id}{$member2->stable_id} = 1;
            $pairs_of_split_genes{$member2->stable_id}{$member1->stable_id} = 1;
          }
        }

      # get all leaves,  all proteins of the tree
      my @aligned_members = @{$protein_tree->get_all_leaves};                                                                                                                                          
      # Group aligned members per species
      my $aligned_member_per_species = {};
      for (my $i = 0; $i < @aligned_members; $i++) 
      {
        push(@{$aligned_member_per_species->{$aligned_members[$i]->genome_db->name}}, $aligned_members[$i]);
      }                                     
                                           
      # Study each set of aligned members in turn                                                          
      foreach  my $these_aligned_members (values %$aligned_member_per_species)                            
      {                                                                                              
                                                                                                  
      for (my $i = 0; $i < @$these_aligned_members; $i++)                                          
      {                                                                                          
          my $score = 0;                                                                      
          my $first_aa_length =0;                                                              
          my $length =0;                                                                    
          my $first_aa=0;                                                                    
          my $overlap = 0;                                                                 
          my $is_a_split_gene=0;                                                         
          my $perc_confidence=0;                                                          
          my $unknown_aa_seq = 0;                                                      
          my $unknown2_aa_seq =0;                                                       
          my $possible_split_gene=0;
          my $ancestor =0;                                                            
          my $duplication_confidence_score=0;                                        
          my $duplication_confidence_score_rounded=0;                              
          my $isec = 0;                                                             
          my $union = 0;                                                          
          my $msplit= "NA";                                                     
                                                                                 
          for (my $j = $i + 1 ; $j < @$these_aligned_members; $j++)           
          {                                                                    
              #used of a subroutine compare_aligned_members to compare proteins with each others and find shortests.  
              ($score,$first_aa_length,$length, $first_aa,$overlap, $unknown_aa_seq,$unknown2_aa_seq)=compare_aligned_members(@$these_aligned_members[$i], @$these_aligned_members[$j]); 
                                                                                                                     
              #Fetch Gene Stable ID of the possible split gene                                                      
              $possible_split_gene= @$these_aligned_members[$j];
              # get the ancestor of two aligned members                                                            
              $ancestor =$these_aligned_members->[$i]->find_first_shared_ancestor(@$these_aligned_members[$j]);   
                                                                                                                  
                                                                                                                
            #Result of a subroutine checking if those two aligned members are referenced as a split gene in the homology table 
            $is_a_split_gene = 0;
            if ($pairs_of_split_genes{$these_aligned_members->[$i]->gene_member->stable_id}{$these_aligned_members->[$j]->gene_member->stable_id}) {
              $is_a_split_gene = 1;
            }                  

            #Concatenate Number of unknonwn aa on two partial genes matching                                      
            #$final_unknown_aa_seq=$final_unknown_aa_seq."X".$final_unknown2_aa_seq."X";                        
                                                                                                                 
            #Result of a subroutine that will get the percentage of confidence of the duplication node         
            ($duplication_confidence_score,$isec,$union,$msplit) = duplication_confidence_score($protein_tree,$ancestor,@$these_aligned_members[$i],$possible_split_gene);                       
                                                                                                              
            #Round up the duplication confidence score.                                                      
            $duplication_confidence_score_rounded = sprintf("%.3f",$duplication_confidence_score);          
       

           #Push all the result into an array
            push @output_ids, {
              'tagged_as_split_gene_by_gene_tree_pipeline' => $is_a_split_gene,
              'overlap' => $overlap,
              'score_inter_union' => int($score*1000)/10,
              'first_aa_prot' => $first_aa,
              'unknown_aa_prot1' => $unknown_aa_seq,
              'unknown_aa_prot2' => $unknown2_aa_seq,
              'rounded_duplication_confidence_score' => $duplication_confidence_score_rounded,
              'intersection_duplication_score' => $isec,
              'union_duplication_confidence_score' => $union,
              'merged_by_gene_tree_pipeline' => $msplit,
              'chr_name' => @$these_aligned_members[$i]->chr_name,
              'chr_strand' => @$these_aligned_members[$i]->chr_strand,
              'first_part_split_gene_stable_id' => @$these_aligned_members[$i]->gene_member->stable_id,
              'second_part_split_gene_stable_id' => $possible_split_gene->gene_member->stable_id,
              'protein1_label' => (@$these_aligned_members[$i]->gene_member->display_label or "NA"),
              'protein1_length_in_aa' => $first_aa_length,
              'alignment_length' => $length,
              'species_name' => @$these_aligned_members[$i]->genome_db->name,
              'kingdom' => $kingdom,
            };
          }           
        }
      }
      $self->param('output_ids', \@output_ids);
}

sub write_output {
  my $self = shift @_;

  my $output_ids = $self->param('output_ids');

  $self->dbc->disconnect_when_inactive(0);

  $self->dataflow_output_id($output_ids, 3);
}


#Subroutine witch compare two proteins and return a score, lower score is for a shorter protein and highest for a longest
sub compare_aligned_members {
    my ($first_aligned_member, $second_aligned_member) = @_;
    my $first_alignment_string = $first_aligned_member->alignment_string;
    my $second_alignment_string = $second_aligned_member->alignment_string;

    #Compare the length of two proteins
    my $length = length($first_alignment_string);
    die "Whoohoohoho" if ($length != length($second_alignment_string));

    #initialise variables
    my $union = 0;
    my $intersection = 0;
    my $second_aa_length = 0;
    my $first_aa_length =0 ;
    my $first_aa = 0;
    my $overlap=1000000;
    my $first_aa_boolean =0;
    my $unknown_seq =0;
    my $unknown2_seq = 0;
    my $unknown_aa_seq = 0;
    my $unknown2_aa_seq =0;

    # PROT1:  ATGDSGDFAS----DFS---GERGEW------
    # PROT2:  --AGFGJEJSGSDHJKYITSDEWRW-------
    # inter   00111111110000111000111110000000 => 16 aa
    # union   11111111111111111111111111000000 => 26 aa
    # score = 16/26

    # PROT1:  ATGDSGDFASFGDWDFS---GERGEW------
    # PROT2:  -----------------YITSDEWRW------
    # inter   00000000000000000000111111000000 => 6 aa
    # union   11111111111111111111111111000000 => 26 aa
    # score = 6/26

    # We want to know if prot1 is shorter -> compare intersection with second_aa_length
    
    for (my $i = 0; $i <= $length - 1; $i++) {
	#substr used to cut the string in pieces, to get each amino acid.
	my $first = substr($first_alignment_string, $i, 1);
	my $second = substr($second_alignment_string, $i, 1);
	#if the character of the second protein is not a gap "_" increment second_aa_length.
	if ($second ne "-") {
	    $second_aa_length++;
	}
	if ($first ne "-"){
	    $first_aa_length++;
	}
	if ($first ne "-" and $second ne "-") {
	    $union++;
	    $intersection++;
	} elsif ($first ne "-" or $second ne "-") {
	    $union++;
	}
	if (($first ne "-") and $first_aa_boolean == 0 )
	{
	    $first_aa = $first;
	    $first_aa_boolean = 1;
	}
	#if the Protein aa is Unknown
	if ($first eq "X")
	{
	    $unknown_seq++;
	}
	#same for the other gene
	if ($second eq "X")
	{
	    $unknown2_seq++;
	}
    }   
    # score is the number of intersection over the number of union.
    my $score = $intersection / $union;

    # Check if two members of the same species are overlapping, throw the nomber of overlap 
    if(($first_aligned_member->genome_db->name eq $second_aligned_member->genome_db->name))
    {
	$overlap=$intersection;	
	$unknown_aa_seq = $unknown_seq;
	$unknown2_aa_seq = $unknown2_seq;
    }
    return ($score,$first_aa_length,$length,$first_aa,$overlap,$unknown_aa_seq,$unknown2_aa_seq);
}

sub duplication_confidence_score {   
    
    my ($protein_tree,$ancestor,$aligned_members_i,$possible_split_gene)=@_;
    # This assumes bifurcation!!! No multifurcations allowed 
    my ($child_a, $child_b, $dummy) = @{$ancestor->children}; 
    throw("tree is multifurcated in duplication_confidence_score\n") if (defined($dummy)); 
    my $child_a_id =$aligned_members_i->stable_id;
    my $child_b_id =$possible_split_gene->stable_id;
    my @child_a_gdbs = keys %{get_ancestor_species_hash($protein_tree,$child_a)}; 
    #return undef if (!defined($child_b));
    my @child_b_gdbs = keys %{get_ancestor_species_hash($protein_tree,$child_b)}; 
    #$DB::single=1;1;
    my %seen = ();my @gdb_a = grep { ! $seen{$_} ++ } @child_a_gdbs;
    %seen = (); my @gdb_b = grep { ! $seen{$_} ++ } @child_b_gdbs; 
    my @isect = my @diff = my @union = ();my %count;
    foreach my $e (@gdb_a, @gdb_b) { $count{$e}++ } 
    foreach my $e (keys %count) 
    {  
	push(@union, $e); push @{ $count{$e} == 2 ? \@isect : \@diff }, $e;
    } 
    my $duplication_confidence_score = 0;
    my $scalar_isect = scalar(@isect);
    my $scalar_union = scalar(@union); 
    my $ancestor_node_id="";
    $duplication_confidence_score = (($scalar_isect)/$scalar_union) unless (0 == $scalar_isect);
    my $msplit="NA"; 
    #Check if gene  was already merged by the pipeline
    $msplit = "msplit_${child_a_id}_${child_b_id}" if $protein_tree->has_tag("msplit_${child_a_id}_${child_b_id}");
    $msplit = "msplit_${child_b_id}_${child_a_id}" if $protein_tree->has_tag("msplit_${child_b_id}_${child_a_id}");

    # subroutine won't tried to write on the database, it's not the point here.
    $protein_tree->{_readonly} = 1;
    $ancestor->store_tag ( 
			   "duplication_confidence_score", 
			   $duplication_confidence_score 
			   ) unless ($protein_tree->{'_readonly'});
    my $rounded_duplication_confidence_score = (int((100.0 * $scalar_isect / $scalar_union + 0.5))); 
    my $species_intersection_score = $ancestor->get_tagvalue("species_intersection_score");
    unless (defined($species_intersection_score)) 
    { 
	$ancestor_node_id = $ancestor->node_id;
	#warn("Difference in the ProteinTree: duplication_confidence_score [$duplication_confidence_score] whereas species_intersection_score [$species_intersection_score] is undefined in njtree - ancestor $ancestor_node_id\n");
	return ($duplication_confidence_score,$scalar_isect,$scalar_union,$msplit);
    } 
    if ($species_intersection_score ne $rounded_duplication_confidence_score && !defined($protein_tree->{_readonly})) 
    { 
	$ancestor_node_id = $ancestor->node_id;
	$protein_tree->throw("Inconsistency in the ProteinTree: duplication_confidence_score [$duplication_confidence_score] != species_intersection_score [$species_intersection_score] - $ancestor_node_id\n");
    } 
    return ($duplication_confidence_score,$scalar_isect,$scalar_union,$msplit);

}

sub get_ancestor_species_hash {
    my ($protein_tree,$node)=@_;
    my $species_hash=0;
    $species_hash = $node->get_tagvalue('species_hash');
    return ($species_hash) if($species_hash); 
    $species_hash = {}; 
    my $duplication_hash = {};
    my $is_dup=0; 
    if($node->isa('Bio::EnsEMBL::Compara::GeneTreeMember')) 
    { 
	my $node_genome_db_id = $node->genome_db_id;
	$species_hash->{$node_genome_db_id} = 1; 
	$node->add_tag('species_hash', $species_hash);
	return ($species_hash);
    } 
    foreach my $child (@{$node->children}) 
    { 
	my $t_species_hash = get_ancestor_species_hash($protein_tree,$child);
	next unless(defined($t_species_hash)); 
        #shouldn't happen 
	foreach my $genome_db_id (keys(%$t_species_hash)) 
	{
	    unless(defined($species_hash->{$genome_db_id})) 
	    { 
		$species_hash->{$genome_db_id} = $t_species_hash->{$genome_db_id};
	    } 
	    else 
	    { #this species already existed in one of the other children 
              #this means this species was duplicated at this point between 
              #the species 
		$is_dup=1;
		$duplication_hash->{$genome_db_id} = 1; 
		$species_hash->{$genome_db_id} += $t_species_hash->{$genome_db_id};
	    } 
	} 
    } 
    $node->add_tag("species_hash", $species_hash); 
    if($is_dup && !($protein_tree->{'_treefam'})) 
    { 
      if ($node->get_tagvalue('node_type', '') eq 'speciation')
	{ 
            # RAP did not predict a duplication here 
	    $node->add_tag('duplication_hash', $duplication_hash);
	    $node->store_tag('node_type', 'duplication') unless ($protein_tree->{'_readonly'});
	} 
    } 
    return ($species_hash); 
} 

1;

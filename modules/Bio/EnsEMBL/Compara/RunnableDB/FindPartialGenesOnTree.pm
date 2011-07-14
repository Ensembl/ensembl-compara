#
# You may distribute this module under the same terms as perl itself
#
# POD documentation - main docs before the code

=pod 

=head1 NAME

Bio::EnsEMBL::Compara::RunnableDB::FindPartialGenesOnTree

=cut

=head1 SYNOPSIS


my $db           = Bio::EnsEMBL::Compara::DBAdaptor->new($locator);
my $find_partial_genes = Bio::EnsEMBL::Compara::RunnableDB::FindPartialGenesOnTree->new
  (
   -db         => $db,
   -input_id   => $input_id,
   -analysis   => $analysis
  );
$find_partial_genes->fetch_input(); #reads from DB
$find_partial_genes->run();
$find_partial_genes->output();
$find_partial_genes->write_output(); #writes to DB

=cut


=head1 DESCRIPTION

This Analysis will take a protein tree id and calcul the coverage on core region score and  alignment overlap score, 
in order to find possible partial gene of a tree.

=cut


=head1 CONTACT

  Contact Thomas Maurel on module implementation/design detail: maurel@ebi.ac.uk
  Contact Javier Herrero on Split/partial genes in general: jherrero@ebi.ac.uk

=cut

=head1 APPENDIX

The rest of the documentation details each of the object methods. 
Internal methods are usually preceded with a _

=cut


package Bio::EnsEMBL::Compara::RunnableDB::FindPartialGenesOnTree;

use strict;

use base ('Bio::EnsEMBL::Compara::RunnableDB::BaseRunnable');
use List::Util qw[min max];

sub fetch_input {
  my $self = shift @_; 

  my $protein_tree_id      = $self->param('protein_tree_id') or die "'protein_tree_id' is an obligatory parameter";
  my $protein_tree_adaptor = $self->compara_dba->get_ProteinTreeAdaptor();
      # if fetch_node_by_node_id is insufficient, try fetch_tree_at_node_id
  my $protein_tree         = $protein_tree_adaptor->fetch_node_by_node_id($protein_tree_id) or die "Could not fetch protein_tree by id=$protein_tree_id";
  $self->param('protein_tree', $protein_tree);
  $self->dbc->disconnect_when_inactive(1);
}

sub run {
  my $self = shift @_; 
  my $protein_tree = $self->param('protein_tree');
  my $threshold = $self->param('threshold') or die "'threshold' is an obligatory parameter";
  my $kingdom = $self->param('kingdom') or '(none)';
  my @output_ids = (); 
  my @perc_pos=();
  my $first_loop=0;
  my %members=();
  my %pos_occupancy=();

# get all leaves,  all members of the tree
my @aligned_members = @{$protein_tree->get_all_leaves};
#initialize the array for each new tree
my $first_member_string = $aligned_members[0]->alignment_string;
my $alignment_length = length($first_member_string);
#the array is initilise at 0 for each position of the aligned_member
for(my $j=0;$j<$alignment_length;$j++)
{
  $perc_pos[$j]=0;
}

for (my $i = 0; $i < @aligned_members ; $i++) 
{
#get the cigar line of an aligned_member
  my $cigar_line=$aligned_members[$i]->cigar_line();
#get the length of the aligned member
  my $first_alignment_string = $aligned_members[$i]->alignment_string;
  my $alignment_length = length($first_alignment_string);
  my $pos=0;
  my $final_pos=0;
#create a new array for a members
  $members{$i}=[];
###First step : for each members, getting the coverage of each protein compared to the alignment###

#get the value and the code of a cigar line using Perl regular expressions
# for 2D50M2M
# in the first loop $value=2 and $code=D
# if there is only one letter for one match or one deletion $code_alone will take this letter and be defined.
 while ($cigar_line =~ m/(\d+)([MID])|([MID])/g) 
  {
    my $value = $1;
    my $code  = $2;
    my $code_alone=$3;
 if ( defined($code_alone) and $code_alone eq "D")
    {   
      $final_pos=1+$pos;
      $members{$i}[$pos]=0;
      $pos++;
    }   
    if (defined($code) and $code eq "D")
    {   
#if its a D, do nothing in the array, just increased the position variable
      $final_pos=$value+$pos;
      while($pos < $final_pos)
      {   
#for a deletion (D) the members will have a 0 at the given position
        $members{$i}[$pos]=0;
        $pos++;
      }   
    }   
    if (defined($code_alone) and $code_alone eq "M")
    {   
      my $las=$perc_pos[$pos];
      $las++;
      $final_pos=1+$pos;
      $members{$i}[$pos]=1;
$members{$i}[$pos]=1;
      $perc_pos[$pos]=$las;
      $pos++;
    }   
    if (defined($code) and $code eq "M")
    {   
#if its a M , increased the value at the position gived by $pos
      $final_pos=$value+$pos;
      while($pos < $final_pos)
      {   
#for multiple match , members will have a 1 at each positions given by the number in front of the match (M)
# and perc_pos array will increased the total for each position
      my $last=$perc_pos[$pos];
        $last ++; 
        $perc_pos[$pos]=$last;
        $members{$i}[$pos]=1;
        $pos++;
       }   
    }   
  }
} 

#getting the maximum of core position 
my $max=0; 
foreach my $maxpos (@perc_pos)
{ 
  if ($maxpos>$max)
  {
    $max=$maxpos;
  }
}

#create a Treshold for example with (@aligned_members*90)/100, the maximum occupancy position will be kept if there is 90% of all members overlaping this positions.
my $threshold_T1 = ($max*$threshold)/100;
#Find postions with maximum of position occupancy taking the treshold in account and add it on a hash table.
for(my $j=0;$j<$alignment_length;$j++)
{
  if ($perc_pos[$j] >= $threshold_T1)
  {
    $pos_occupancy{$j}=$perc_pos[$j];
  }    
}

#Getting the alignment overlap score for each genes
#the alignment overlap score i = average(i!=j)(intersection ij/length j)
my @alignment_overlap_score=();
for (my $i=0;$i<@aligned_members;$i++)
{
  my $final_score=0;
  for (my $j=0;$j<@aligned_members;$j++)
  {
    if($i==$j)
    {
      next;
    }
    my $alignment_overlap_score =0;
    my $intersection=0;
    my $length=0;
    for (my $p=0; $p<@{$members{$j}};$p++)
    {
    if ($members{$i}[$p]==1 and $members{$j}[$p]==1)
    {
    $intersection++;
    }
    if ($members{$j}[$p]==1)
    {
    $length++;
    }
    }
# alignment overlap score is the intersection over length
    $alignment_overlap_score=$intersection/$length;
#add previous score
    $final_score=$final_score+$alignment_overlap_score;
  }
#final score is the average of score over number total of members
  $alignment_overlap_score[$i]=$final_score/(@aligned_members-1);
}

#Now check for each aligned member at the occupancy position if there is an overlap
for (my $l=0; $l<@aligned_members; $l++)
{
  my $total_occupancy=0;
  my $member_occupancy=0;
  my $coverage_on_core_region=0;
  my $alignment_overlap_score=0;
#foreach occupancy positions
  foreach my $pos (keys %pos_occupancy)
  {
    $total_occupancy++;
#if match between member and occupancy position
    if (defined $members{$l}[$pos])
    {
      if ($members{$l}[$pos] eq 1)
      {
        $member_occupancy++;
      }
    }
  }
  if ($total_occupancy!=0){
    $coverage_on_core_region=($member_occupancy*100)/$total_occupancy;
  }
#Push all result into an array
      push @output_ids, {
      'gene_stable_id' => $aligned_members[$l]->gene_member ? $aligned_members[$l]->gene_member->stable_id : 'protein_member_id='.$aligned_members[$l]->dbID(),
      'protein_tree_stable_id' => $protein_tree->stable_id,
      'coverage_on_core_regions_score' => $coverage_on_core_region,
      'alignment_overlap_score' => $alignment_overlap_score[$l],
      'species_name' => $aligned_members[$l]->genome_db->name,
      'kingdom' => $kingdom,
 };

#  push @output_ids, {
#    'gene_stable_id' => $aligned_members[$l]->gene_member->stable_id,
#      'coverage_on_core_regions_score' => $coverage_on_core_region,
#      'species_name' => $aligned_members[$l]->genome_db->name,
#  };  

}
$self->param('output_ids', \@output_ids);
}

sub write_output {
  my $self = shift @_;
 
  my $output_ids = $self->param('output_ids');
 
  $self->dbc->disconnect_if_idle();
  #$self->dbc->disconnect_when_inactive(0);
  $self->dataflow_output_id($output_ids, 3);
}



1;


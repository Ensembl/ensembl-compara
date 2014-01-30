=head1 LICENSE

Copyright [1999-2014] Wellcome Trust Sanger Institute and the EMBL-European Bioinformatics Institute

Licensed under the Apache License, Version 2.0 (the "License");
you may not use this file except in compliance with the License.
You may obtain a copy of the License at

     http://www.apache.org/licenses/LICENSE-2.0

Unless required by applicable law or agreed to in writing, software
distributed under the License is distributed on an "AS IS" BASIS,
WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
See the License for the specific language governing permissions and
limitations under the License.

=cut

=pod 

=head1 NAME

Bio::EnsEMBL::Compara::RunnableDB::RunPhylofit

=cut

=head1 SYNOPSIS

=cut

package Bio::EnsEMBL::Compara::RunnableDB::MakeNTSpeciesTree::RunPhylofit;

use strict;
use Bio::EnsEMBL::Compara::Graph::NewickParser;
use Bio::EnsEMBL::Compara::SpeciesTreeNode;
use Bio::EnsEMBL::Compara::DBSQL::DBAdaptor;
use Bio::EnsEMBL::Registry;
use Bio::AlignIO;
use Bio::EnsEMBL::Utils::Exception;
use Data::Dumper;

use base('Bio::EnsEMBL::Compara::RunnableDB::BaseRunnable');

sub fetch_input {
 my $self = shift @_;
 # print the species tree
 my $species_tree_a = $self->compara_dba->get_SpeciesTreeAdaptor;
 my $species_tree = $species_tree_a->fetch_by_method_link_species_set_id_label(
                     $self->param('tree_mlss_id') );
 throw("no species tree found for mlssid ".$self->param('tree_mlss_id')) unless $species_tree;
 my $newick_tree = $species_tree->species_tree;
 $newick_tree=~s/[\d\.:]+//g;
 $self->param("newick_tree", lc($newick_tree));
 
 Bio::EnsEMBL::Registry->load_registry_from_multiple_dbs(@{ $self->param('core_dbs') });
 
 # previous release db from which to get the gabs
 my $prev_compara_dba = new Bio::EnsEMBL::Compara::DBSQL::DBAdaptor( 
 %{ $self->param('previous_compara_db') } );


# print the genomic_align_block
 my $gab_a = $prev_compara_dba->get_GenomicAlignBlockAdaptor;

 my $gab_id = $self->param('block_id');

 my $gab = $gab_a->fetch_by_dbID( $gab_id );

 my ($simple_align,%fasta_set);

 {  
  local *STDOUT;
  open STDOUT, ">", \$simple_align or die $@;
  
  my $alignIO = Bio::AlignIO->newFh(
   -interleaved => 0,
   -format => 'fasta',
   -displayname_flat => 1,
  );

  print $alignIO $gab->get_SimpleAlign;
 }

 my @align_seqs = map { if(scalar $_){$_}else{} } split ">", $simple_align;
 foreach my $aligned_seq(@align_seqs){
  my@fasta = split "\n", $aligned_seq;
  my ($species_name) = split "/", shift @fasta;
  $aligned_seq = join "", @fasta;
  if($aligned_seq=~s/\.//g){
   $fasta_set{'LC'}{$species_name} .= $aligned_seq;
  } else {
   push(@{ $fasta_set{'HC'}{$species_name} }, $aligned_seq);
  }
 }
 $self->param('fasta_set', \%fasta_set);

}

sub write_output {
 my $self = shift @_;
 my $block_id = $self->param('block_id');
 my $gab_file = "/tmp/".$block_id;

 my $msa_fasta_file = "/tmp/msa_fasta.$block_id"; 
 open(IN, ">$msa_fasta_file") or throw("cant open $msa_fasta_file");
 my $fasta_set = $self->param('fasta_set');
 foreach my $assemb_type(keys %{ $fasta_set }){
  if($assemb_type eq "HC"){
   foreach my $species(keys %{ $fasta_set->{$assemb_type} }){
    print IN join("\n", ">$species", $fasta_set->{"HC"}->{"$species"}->[0]), "\n";
   }
  } else {
   foreach my $species(keys %{ $fasta_set->{$assemb_type} }){
    print IN join("\n", ">$species", $fasta_set->{"LC"}->{"$species"}), "\n";
   }
  }
 }
 my $species_tree_file = "/tmp/species_tree.$block_id";
 open(TR, ">$species_tree_file") or throw("cant open $species_tree_file file\n");
 print TR $self->param('newick_tree');
 close(TR);
# run phylofit 
 my $command = $self->param('phylofit_exe'). " --tree \"$species_tree_file\" --subst-mod HKY85 --out-root $gab_file " . $msa_fasta_file;
 system($command); 
 open(TREE, "/tmp/$block_id.mod") or throw("cant open /tmp/$block_id.mod");
 my ($newick_tree_string) = map {if($_=~s/TREE: //){$_}} grep {/^TREE:/} <TREE>;
# store the tree
 my $species_tree_ad = $self->compara_dba->get_SpeciesTreeAdaptor;
 my $tree = $species_tree_ad->new_from_newick($newick_tree_string, "$block_id.pf", 'name'); 
 $species_tree_ad->store($tree, $self->param('tree_mlss_id'));

# my $sql = "INSERT INTO method_link_species_set_tag VALUES (?,?,?)";
# my $sth = $self->compara_dba->dbc->prepare($sql);
# $sth->execute($self->param('tree_mlss_id'), "alignment_tree", $newick_tree_string);


# remove the files
 unlink "$species_tree_file", "$gab_file", "$msa_fasta_file", "/tmp/$block_id.mod";
}


1;

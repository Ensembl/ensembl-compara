=head1 LICENSE

Copyright [1999-2015] Wellcome Trust Sanger Institute and the EMBL-European Bioinformatics Institute
Copyright [2016-2018] EMBL-European Bioinformatics Institute

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

Bio::EnsEMBL::Compara::RunnableDB::MakeNTSpeciesTree::ExonPhylofitFactory

=cut

=head1 SYNOPSIS

=cut


package Bio::EnsEMBL::Compara::RunnableDB::MakeNTSpeciesTree::ExonPhylofitFactory;

use strict;
use warnings;

use List::Util qw(sum0);

use Bio::EnsEMBL::Registry;
use Bio::EnsEMBL::Compara::DBSQL::DBAdaptor;
use Bio::EnsEMBL::Utils::Exception ('throw');
use Data::Dumper;

use base('Bio::EnsEMBL::Compara::RunnableDB::BaseRunnable');

sub fetch_input {
 my $self = shift @_;
 
 Bio::EnsEMBL::Registry->load_registry_from_multiple_dbs( @{ $self->param('core_dbs') } );
 
 my $ref_species_name = $self->param('ref_species_name');
 my $exon_a = Bio::EnsEMBL::Registry->get_adaptor( $ref_species_name, "core", "Exon");
 my $trans_a = Bio::EnsEMBL::Registry->get_adaptor( $ref_species_name, "core", "Transcript");
 my $slice_a = Bio::EnsEMBL::Registry->get_adaptor( $ref_species_name, "core", "Slice");
 my $canonical_trans = $trans_a->fetch_by_stable_id( $self->param('transcript_id') );
 my $exons = $exon_a->fetch_all_by_Transcript( $canonical_trans );
 my ($coord_sys, $seq_region) = (split ":", $canonical_trans->seqname)[0,2];

 my $prev_compara_dba = new Bio::EnsEMBL::Compara::DBSQL::DBAdaptor(
  %{ $self->param('previous_compara_db') } );

 my $gab_a = $prev_compara_dba->get_GenomicAlignBlockAdaptor;
 my $mlss_a = $prev_compara_dba->get_MethodLinkSpeciesSetAdaptor;
 my $mlss = $mlss_a->fetch_by_dbID($self->param('msa_mlssid'));

 my $msa_species_tree = $mlss->species_tree;
 my $orig_species = lc join ":", sort {$a cmp $b} map {$_->name} @{$msa_species_tree->root->get_all_leaves};
 $self->param('msa_species_tree_string', $msa_species_tree->root->newick_format('ryo', '%{n}:%{d}'));

 my(%exon_aligns,%species_names);

 foreach my $exon(@{ $exons }){
  my $slice = $slice_a->fetch_by_region($coord_sys, $seq_region, $exon->start, $exon->end);
  my $gabs = $gab_a->fetch_all_by_MethodLinkSpeciesSet_Slice($mlss, $slice);
  foreach my $gab(@$gabs){
   my $restricted_gab = $gab->restrict_between_reference_positions($exon->start, $exon->end);
   my $genomic_aligns = $restricted_gab->genomic_align_array;
   foreach my $ga(@$genomic_aligns){
    my $seq;
    eval { $seq = $ga->aligned_sequence };
    if($@){
     $self->warning($@);
     next;
    }
    my $ratio_n = ($seq=~tr/N/N/) / length($seq);
    my $ratio_dot = ($seq=~tr/\./\./) / length($seq);
    next if($ratio_n + $ratio_dot > 0.1); # arbitrary 10% cut off for removing sequences with Ns and .s
    my $species_name = $ga->dnafrag->genome_db->name;
    if(exists $exon_aligns{ $exon->dbID }{ $species_name } ){
     my $stored_cigar = $exon_aligns{ $exon->dbID }{ $species_name }{ 'cigar' };
     my $stored_total = sum0 $stored_cigar=~/(\d+)M/g; # sum up all the matches in the cigar
     my $new_total = sum0 $ga->cigar_line=~/(\d+)M/g;
     next if ($new_total < $stored_total); # for a species with more than one seq in the alignment choose the one with the most matches
    }
    $species_names{ $species_name }++;
    $exon_aligns{ $exon->dbID }{ $species_name }{ 'cigar' } = $ga->cigar_line;
    $exon_aligns{ $exon->dbID }{ $species_name }{ 'seq' } = $seq;
   }
  } 
 }
 my $exon_species = join ":", sort {$a cmp $b } keys %species_names;
 if($exon_species eq $orig_species){ # only going to use exons from blocks containig all species from the original species tree
  $self->param('exon_set', \%exon_aligns);
 } else { return 1; }
}

sub write_output {
 my $self = shift @_;
 my $exon_set = $self->param('exon_set');
 foreach my$exon_id(keys %{ $exon_set }){
  my $exon_dir = $self->worker_temp_directory."/exon_$exon_id";
  mkdir $exon_dir or throw "could not make $exon_dir";
  my $msa_fasta_file = "$exon_dir/msa_fasta.$exon_id";
  open(IN, ">$msa_fasta_file") or throw("cant open $msa_fasta_file");
  foreach my $species_name(keys %{ $exon_set->{$exon_id} } ){
   print IN ">".ucfirst($species_name)."\n", $exon_set->{$exon_id}->{$species_name}->{'seq'}, "\n";
  }
  my $tree_file = "$exon_dir/msa_species_tree";
  $self->_spurt($tree_file, $self->param('msa_species_tree_string'));
  my $phylo_out_file = "$exon_dir/phylo$exon_id";
  my @command = ($self->param('phylofit_exe'), '--tree', $tree_file, '--subst-mod', 'HKY85', '--out-root', $phylo_out_file, $msa_fasta_file);
  $self->run_command(\@command, { die_on_failure => 1 });
  if( -e "$phylo_out_file.mod" ){
   open(TREE, "$phylo_out_file.mod") or warn ("cant open $phylo_out_file.mod");
   my($training_lnl, $phylo_newick);
   while(<TREE>){
    chomp;
    if($_=~/TRAINING_LNL: /){
     $_=~s/TRAINING_LNL: //;
     $training_lnl = $_;
    } elsif ($_=~/TREE: /){
     $_=~s/TREE: //; 
     $phylo_newick = $_;
    }
   }
   $self->dataflow_output_id( { 'exon_id' => $exon_id, 'training_lnl' => $training_lnl, 'phylofit_tree_string' => $phylo_newick }, 2);
   unlink "$phylo_out_file.mod";
  }
  unlink "$tree_file", "$msa_fasta_file";
  rmdir $exon_dir;
 }
}

1;

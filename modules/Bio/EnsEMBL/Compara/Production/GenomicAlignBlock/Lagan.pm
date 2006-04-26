#
# POD documentation - main docs before the code
#

=pod 

=head1 NAME

Bio::EnsEMBL::Compara::Production::GenomicAlignBlock::Lagan

=cut

=head1 SYNOPSIS

=cut

=head1 DESCRIPTION

This module interfaces the Hive and the Analsys systems: it allows to run Lagan jobs in an
ensembl-hive production systems. Jobs are run using the Bio::EnsEMBL::Analysis::Runnable::Lagan
module.

=cut

=head1 AUTHORS

Javier Herrero
Abel Ureta-Vidal

=head1 COPYRIGHT

Copyright (c) 2006. EnsEMBL Team

You may distribute this module under the same terms as perl itself

=head1 CONTACT

This modules is part of the EnsEMBL project (http://www.ensembl.org)

Questions can be posted to the ensembl-dev mailing list:
ensembl-dev@ebi.ac.uk

=cut

=head1 APPENDIX

The rest of the documentation details each of the object methods. 
Internal methods are usually preceded with a _

=cut

package Bio::EnsEMBL::Compara::Production::GenomicAlignBlock::Lagan;

use strict;
use Bio::EnsEMBL::Analysis::Runnable::Lagan;
use Bio::EnsEMBL::Compara::DnaFragRegion;
use Bio::EnsEMBL::Compara::Production::DBSQL::DBAdaptor;;
use Bio::EnsEMBL::Utils::Exception;
use Bio::EnsEMBL::Compara::NestedSet;
use Bio::EnsEMBL::Compara::Graph::NewickParser;
use Time::HiRes qw(time gettimeofday tv_interval);

use Bio::EnsEMBL::Hive::Process;
our @ISA = qw(Bio::EnsEMBL::Hive::Process);

$| = 1;


=head2 fetch_input

    Title   :   fetch_input
    Usage   :   $self->fetch_input
    Function:   Fetches input data for repeatmasker from the database
    Returns :   none
    Args    :   none

=cut

sub fetch_input {
  my( $self) = @_;

  $self->{'comparaDBA'} = Bio::EnsEMBL::Compara::Production::DBSQL::DBAdaptor->new(-DBCONN=>$self->db->dbc);
  $self->get_params($self->parameters);
  $self->get_params($self->input_id);

  $self->dumpFasta;

  return 1;
}

sub run
{
  my $self = shift;

  my $runnable = new Bio::EnsEMBL::Analysis::Runnable::Lagan
    (-workdir => $self->worker_temp_directory,
     -fasta_files => $self->fasta_files,
     -tree_string => $self->tree_string,
     -analysis => $self->analysis);
  $self->{'_runnable'} = $runnable;
  $runnable->run_analysis;
}

sub write_output {
  my ($self) = @_;

  my $mlssa = $self->{'comparaDBA'}->get_MethodLinkSpeciesSetAdaptor;
  my $mlss = $mlssa->fetch_by_dbID($self->method_link_species_set_id);
  my $gaba = $self->{'comparaDBA'}->get_GenomicAlignBlockAdaptor;
  foreach my $gab (@{$self->{'_runnable'}->output}) {
    foreach my $ga (@{$gab->genomic_align_array}) {
      $ga->method_link_species_set($mlss);
      my $dfr = $self->{'_dnafrag_regions'}{$ga->dnafrag_id};
      $ga->dnafrag_id($dfr->dnafrag_id);
      $ga->dnafrag($dfr->dnafrag);
      $ga->dnafrag_start($dfr->dnafrag_start);
      $ga->dnafrag_end($dfr->dnafrag_end);
      $ga->dnafrag_strand($dfr->dnafrag_strand);
      $ga->level_id(1);
      $dfr->release;
      unless (defined $gab->length) {
        $gab->length(length($ga->aligned_sequence));
      }
    }
    $gab->method_link_species_set($mlss);
    $gaba->store($gab);
  }
  return 1;
}

##########################################
#
# getter/setter methods
# 
##########################################

#sub input_dir {
#  my $self = shift;
#  $self->{'_input_dir'} = shift if(@_);
#  return $self->{'_input_dir'};
#}

sub synteny_region_id {
  my $self = shift;
  $self->{'_synteny_region_id'} = shift if(@_);
  return $self->{'_synteny_region_id'};
}

sub fasta_files {
  my $self = shift;

  $self->{'_fasta_files'} = [] unless (defined $self->{'_fasta_files'});

  if (@_) {
    my $value = shift;
    push @{$self->{'_fasta_files'}}, $value;
  }

  return $self->{'_fasta_files'};
}

sub tree_file {
  my $self = shift;
  $self->{'_tree_file'} = shift if(@_);
  return $self->{'_tree_file'};
}

sub tree_string {
  my $self = shift;
  $self->{'_tree_string'} = shift if(@_);
  return $self->{'_tree_string'};
}

sub method_link_species_set_id {
  my $self = shift;
  $self->{'_method_link_species_set_id'} = shift if(@_);
  return $self->{'_method_link_species_set_id'};
}

##########################################
#
# internal methods
#
##########################################

sub get_params {
  my $self         = shift;
  my $param_string = shift;

  return unless($param_string);
#   print("parsing parameter string : ",$param_string,"\n");

  my $params = eval($param_string);
  return unless($params);

  if(defined($params->{'synteny_region_id'})) {
    $self->synteny_region_id($params->{'synteny_region_id'});
  }
  if(defined($params->{'method_link_species_set_id'})) {
    $self->method_link_species_set_id($params->{'method_link_species_set_id'});
  }
  if(defined($params->{'tree_file'})) {
    $self->tree_file($params->{'tree_file'});
  }

  return 1;
}

sub dumpFasta {
  my $self = shift;

#  $self->{'comparaDBA'}->dbc->disconnect_when_inactive(1);

  my $sra = $self->{'comparaDBA'}->get_SyntenyRegionAdaptor;

  my $sr = $sra->fetch_by_dbID($self->synteny_region_id);

  my $idx = 1;

  foreach my $dfr (@{$sr->children}) {  
    my $file = $self->worker_temp_directory . "/seq" . $idx . ".fa";
    my $masked_file = $self->worker_temp_directory . "/seq" . $idx . ".fa.masked";
    $idx++;

    open F, ">$file" || throw("Couldn't open $file");
    open MF, ">$masked_file" || throw("Couldn't open $masked_file");

    # WARNING this is a hack. It won't work at all on self comparisons!!!
    # This will be more generic and fixed when the retain/release call will be
    # cleaned from the Node/Link/NestedSet code.
    # !!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!
    $self->{'_dnafrag_regions'}{$dfr->dnafrag_id} = $dfr;
    $dfr->retain;
    $dfr->disavow_parent;
    my $slice = $dfr->slice;
    print F ">DnaFrag" . $dfr->dnafrag_id . ".\n";
    print MF ">DnaFrag" . $dfr->dnafrag_id . ".\n";
    my $seq = $slice->seq;
    $seq =~ s/(.{80})/$1\n/g;
    chomp $seq;
    print F $seq,"\n";
    $seq = $slice->get_repeatmasked_seq->seq;
    $seq =~ s/(.{80})/$1\n/g;
    chomp $seq;
    print MF $seq,"\n";
  
    close F;
    close MF;

    push @{$self->fasta_files}, $file;
  }
#  $self->{'comparaDBA'}->dbc->disconnect_when_inactive(0);

  $sr->release_tree;

  if ($self->tree_file) {
    my $tree_string = $self->build_tree_string;
    $self->tree_string($tree_string);
  }
  return 1;
}

sub build_tree_string {
  my $self = shift;
  my $tree_file = $self->tree_file;
  open F, $tree_file || throw("Can not open $tree_file");
  my $newick = "";
  while (<F>) {
    chomp;
    if (/^\s*(.*)\s*$/) {
      $newick .= $1;
    }
  }
  close F;

  my $tree = Bio::EnsEMBL::Compara::Graph::NewickParser::parse_newick_into_tree($newick);

  $self->update_node_names($tree);

  my $tree_string = $tree->newick_simple_format;

  $tree_string =~ s/:\d+\.\d+//g;
  $tree_string =~ s/[,;]/ /g;
  $tree_string =~ s/\"//g;

  $tree->release_tree;

  return $tree_string;
}

sub update_node_names {
  my $self = shift;
  my $tree = shift;
  my %gdb_id2dfr;
  foreach my $dfr (values %{$self->{'_dnafrag_regions'}}) {
    $gdb_id2dfr{$dfr->dnafrag->genome_db->dbID} = "DnaFrag".$dfr->dnafrag_id .".";
  }

  foreach my $leaf (@{$tree->get_all_leaves}) {
    if (defined $gdb_id2dfr{$leaf->name}) {
      $leaf->name($gdb_id2dfr{$leaf->name});
    } else {
      $leaf->disavow_parent;
      $tree = $tree->minimize_tree;
    }
  }
  if ($tree->get_child_count == 1) {
    my $child = $tree->children->[0];
    $child->parent->merge_children($child);
    $child->disavow_parent;
  }
  return $tree;
}

1;

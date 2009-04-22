#
# Ensembl module for Bio::EnsEMBL::Compara::Production::GenomicAlignBlock::PhastCons
#
# Copyright Ensembl Team
#
# You may distribute this module under the same terms as perl itself

# POD documentation - main docs before the code

=head1 NAME

Bio::EnsEMBL::Compara::Production::GenomicAlignBlock::PhastCons

=head1 SYNOPSIS

    $phastCons->fetch_input();
    $phastCons->run();
    $phastCons->write_output(); writes to database

=head1 DESCRIPTION

    Given a genomic_align_tree Bio::EnsEMBL::Compara::DBSQL::GenomicAlignTree
    identifier it fetches the alignment and the tree from a compara database and runs
    the program phastCons. At the moment, only conserved elements are supported,
    the parser for conservation scores is not implemented yet.

    WARNING: This is preliminary version nd the paths/options/etc are hard-coded.
    Please, refer to the TODO section for more details.

=head1 AUTHOR - Javier Herrero


=head1 CONTACT

This modules is part of the EnsEMBL project (http://www.ensembl.org)

Questions can be posted to the ensembl-dev mailing list:
ensembl-dev@ebi.ac.uk


=head1 TODO

- Implement the parsing and storing of conservation scores

- Move the path to software to a configuration module

- Allow to specify the method_link_type for phastCons using the input_id or the parameters hash

- Allow to change the model file, in particular the alphabet, background distribution and
  rate matrix.

- Allow to specify phastCons options using the input_id or the parameters hash

- Allow to specify the species you want to skip (if any), the uninformative species
  and the reference species using the input_id or the parameters hash.

- Support to run phastCons with no reference sequence.

- Maybe store the MethodLinkSpeciesSet in the database if it doesn't exist yet.

=head1 APPENDIX

The rest of the documentation details each of the object methods. 
Internal methods are usually preceded with a _

=cut

package Bio::EnsEMBL::Compara::Production::GenomicAlignBlock::PhastCons;

use strict;
use File::Basename;

use Bio::EnsEMBL::Compara::Production::DBSQL::DBAdaptor;
use Bio::EnsEMBL::Utils::Exception;
use Bio::EnsEMBL::Compara::ConservationScore;

use Bio::EnsEMBL::Hive::Process;
our @ISA = qw(Bio::EnsEMBL::Hive::Process);

#location of phast binaries:
my $BIN_DIR = "/software/ensembl/compara/phast";
my $MSA_VIEW_EXE = "$BIN_DIR/msa_view";
my $PHAST_CONS_EXE = "$BIN_DIR/phastCons";

my $METHOD_LINK_TYPE = "PHASTCONS_CONSTRAINED_ELEMENT";

=head2 fetch_input

    Title   :   fetch_input
    Usage   :   $self->fetch_input
    Function:   Fetches input data for gerp from the database
    Returns :   none
    Args    :   none

=cut

sub fetch_input {
  my( $self) = @_;

  #create a Compara::DBAdaptor which shares the same DBI handle
  #with $self->db (Hive DBAdaptor)
  $self->{'comparaDBA'} = Bio::EnsEMBL::Compara::Production::DBSQL::DBAdaptor->new(-DBCONN=>$self->db->dbc);
  $self->{'comparaDBA'}->dbc->disconnect_when_inactive(0);

  #read from analysis table
  $self->get_params($self->parameters); 

  #read from analysis_job table
  $self->get_params($self->input_id);

  my $gata = $self->{'comparaDBA'}->get_GenomicAlignTreeAdaptor;
  my $root_id = $self->root_id;
  $self->{gat} = $gata->fetch_node_by_node_id($root_id);
  if ($root_id != $self->{gat}->node_id) {
    die "Cannot find a tree with this node ID: ".$root_id."\n";
  }

  my $reference_leaves = [];
  my @species_to_skip = ("Gorilla gorilla", "Pongo pygmaeus");
  my @uninformative_species = ("Pan troglodytes");
  my $reference_species = "Homo sapiens";

  ## Trim sequences from species to skip, find all the reference ones and tag uninformatives ones
  foreach my $leaf (@{$self->{gat}->get_all_leaves}) {
    my $species_name = $leaf->genomic_align_group->genome_db->name;
    if (grep {$_ eq $species_name} @species_to_skip) {
      $leaf->disavow_parent;
      $self->{gat} = $self->{gat}->minimize_tree;
      next;
    }
    # phastCons might take number only names as indexes. Prepend gat_ to node_id to build the name
    $leaf->name("gat_".$leaf->node_id);
    if (grep {$_ eq $species_name} @uninformative_species) {
      push(@{$self->{uninformative_leaves}}, $leaf->node_id);
    } elsif (!$reference_species or $species_name eq $reference_species) {
      push(@$reference_leaves, $leaf->node_id);
    }
  }

  ## Store the model file
  $self->{mod_file} = $self->worker_temp_directory . "gat_".$root_id.".mod";
  open(MOD, ">".$self->{mod_file}) or die;
  print MOD "ALPHABET: A C G T
ORDER: 0
SUBST_MOD: REV
BACKGROUND: 0.295000 0.205000 0.205000 0.295000
RATE_MAT:
  -0.976030    0.165175    0.539722    0.271133
   0.237691   -0.990352    0.189637    0.563024
   0.776673    0.189637   -1.248143    0.281833
   0.271133    0.391254    0.195849   -0.858237
TREE: ";
  print MOD $self->{gat}->newick_format("simple"), "\n";
  close(MOD);

  foreach my $this_ref_node_id (@$reference_leaves) {
    ## Check if the file already exists
    my $root_file_name = $self->worker_temp_directory . "gat_".$root_id.".$this_ref_node_id";
    my $multifasta_file = "$root_file_name.mfa";
    my $ref_fasta_file = "$root_file_name.fa";
    my $suff_stats_file = "$root_file_name.ss";
    open(MULTIFASTA, ">$multifasta_file") or die;

    ## Write the ref sequence first
    my $chr_name;
    foreach my $leaf (@{$self->{gat}->get_all_leaves}) {
      next if ($leaf->node_id != $this_ref_node_id);
      # Make sure the reference sequence is in the forward strand
      if ($leaf->genomic_align_group->get_all_GenomicAligns->[0]->dnafrag_strand == -1) {
        $self->{gat}->reverse_complement;
      }
      print MULTIFASTA ">", $leaf->name, "\n";
      my $aligned_sequence = $leaf->aligned_sequence;
      $aligned_sequence =~ tr/./-/;
      print MULTIFASTA $aligned_sequence, "\n";

      # Write the ref sequence in FASTA format, required for msa_view -> phastCons
      open(FASTA, ">$ref_fasta_file ") or die;
      print FASTA ">", $leaf->name, "\n";
      my $original_sequence = $leaf->aligned_sequence;
      $original_sequence =~ tr/./-/;
      print FASTA $original_sequence, "\n";
      close(FASTA);

      last;
    }
    ## Write the remaining sequences
    foreach my $leaf (@{$self->{gat}->get_all_leaves}) {
      next if ($leaf->node_id == $this_ref_node_id);
      print MULTIFASTA ">", $leaf->name, "\n";
      my $aligned_sequence = $leaf->aligned_sequence;
      $aligned_sequence =~ tr/./-/;
      print MULTIFASTA $aligned_sequence, "\n";
    }
    close(MULTIFASTA);

    # Get the multiple alignment in Sufficient Statistics format:
    my $run_str = "$MSA_VIEW_EXE -i FASTA $multifasta_file -o SS".
        " --refseq 2$ref_fasta_file > $suff_stats_file";
    system($run_str) == 0
        or die "$run_str failed: $?";
    die if (!-e $suff_stats_file);
    $self->{ss_files}->{$this_ref_node_id} = $suff_stats_file;
  }

  # free up some memory
  foreach my $leaf (@{$self->{gat}->get_all_leaves}) {
    free_aligned_sequence($leaf);
  }

  return 1;
}

=head2 run

    Title   :   run
    Usage   :   $self->run
    Function:   Run gerp
    Returns :   none
    Args    :   none

=cut

sub run {
  my $self = shift;

  while (my ($node_id, $ss_file_name) = each %{$self->{ss_files}}) {
    my $bed_file_name = $ss_file_name;
    $bed_file_name =~ s/(\.ss)?$/\.bed/;
    my $run_str = "$PHAST_CONS_EXE $ss_file_name ". $self->{mod_file}.
        " -i SS --rho 0.3 --expected-length 45 --target-coverage 0.3";
    if ($self->{uninformative_leaves} and @{$self->{uninformative_leaves}}) {
      $run_str .= " --not-informative gat_".join(",gat_", @{$self->{uninformative_leaves}});
    }
    $run_str .= " --most-conserved $bed_file_name --no-post-probs".
        " --seqname gat_".$node_id." --idpref phastCons.$node_id";
    system($run_str) == 0
        or die "$run_str failed: $?";
    die if (!-e $bed_file_name);
    $self->{bed_files}->{$node_id} = $bed_file_name;
  }
}

=head2 write_output

    Title   :   write_output
    Usage   :   $self->write_output
    Function:   Write results to the database
    Returns :   1
    Args    :   none

=cut

sub write_output {
  my ($self) = @_;

  print STDERR "Write Output\n";
  ## Get the MethodLinkSpeciesSet
  my $gat_method_link_species_set = $self->{gat}->get_all_leaves->[0]->
      genomic_align_group->get_all_GenomicAligns->[0]->method_link_species_set;
  my $phastCons_mlss = $gat_method_link_species_set;
  $phastCons_mlss = $gat_method_link_species_set->adaptor->fetch_by_method_link_type_GenomeDBs(
      $METHOD_LINK_TYPE, $phastCons_mlss->species_set);
  print "MLSS: ", $phastCons_mlss->dbID;

  my $constrained_element_adaptor = $gat_method_link_species_set->adaptor->db->get_ConstrainedElementAdaptor;

  while (my ($node_id, $bed_file_name) = each %{$self->{bed_files}}) {
    print "OUTPUT FOR NODE $node_id: $bed_file_name\n";
    print qx"head -20 $bed_file_name", "[...]\n\n";

    # Find the leaf
    my $genomic_align_node;
    foreach my $leaf (@{$self->{gat}->get_all_leaves}) {
      if ($leaf->node_id == $node_id) {
        $genomic_align_node = $leaf;
        last;
      }
    }

    ## We always run phastCons on the FWD strand
    my $genomic_align = $genomic_align_node->genomic_align_group->get_all_GenomicAligns->[0];
    my $dnafrag_id = $genomic_align->dnafrag_id;
    my $genomic_align_start = $genomic_align->dnafrag_start;

    ## Store the constrained elements
    my @constrained_elements;
    open(BED, $bed_file_name) or die;
    while (<BED>) {
      my ($seq_name, $start0, $end, @rest) = split(/\s+/, $_);
      #create new genomic align blocks by converting alignment
      #coords to chromosome coords
      my $constrained_element_block;
      my $constrained_element =  new Bio::EnsEMBL::Compara::ConstrainedElement(
            -reference_dnafrag_id => $dnafrag_id,
            -start => $genomic_align_start + $start0,
            -end => $genomic_align_start + $start0,
            -method_link_species_set_id => $phastCons_mlss->dbID,
            -score => 0,
        );
      push(@$constrained_element_block, $constrained_element);
      push(@constrained_elements, $constrained_element_block);
    }
    close(BED);
    #store in constrained_element table
    $constrained_element_adaptor->store($phastCons_mlss, \@constrained_elements);
  }

  return 1;
}

##########################################
#
# getter/setter methods
# 
##########################################
#read from input_id from analysis_job table
sub root_id {
  my $self = shift;
  $self->{'_root_id'} = shift if(@_);
  return $self->{'_root_id'};
}

#read method_link_type from analysis table
sub constrained_element_method_link_type {
  my $self = shift;
  $self->{'_constrained_element_method_link_type'} = shift if(@_);
  return $self->{'_constrained_element_method_link_type'};
}

#read options from analysis table
sub options {
  my $self = shift;
  $self->{'_options'} = shift if(@_);
  return $self->{'_options'};
}

#read from parameters of analysis table
sub program {
  my $self = shift;
  $self->{'_program'} = shift if(@_);
  return $self->{'_program'};
}

sub program_file {
  my $self = shift;
  $self->{'_program_file'} = shift if(@_);
  return $self->{'_program_file'};
}

#read from parameters of analysis table
sub program_version {
  my $self = shift;
  $self->{'_program_version'} = shift if(@_);
  return $self->{'_program_version'};
}

#read from parameters of analysis table
sub param_file {
  my $self = shift;
  $self->{'_param_file'} = shift if(@_);
  return $self->{'_param_file'};
}

#read from parameters of analysis table
sub tree_file {
  my $self = shift;
  $self->{'_tree_file'} = shift if(@_);
  return $self->{'_tree_file'};
}

#name of temporary parameter file
sub param_file_tmp {
  my $self = shift;
  $self->{'_param_file_tmp'} = shift if(@_);
  return $self->{'_param_file_tmp'};
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
    
    my $params = eval($param_string);
    return unless($params);

    if (defined($params->{'program'})) {
	$self->program($params->{'program'}); 
    }
    
    #read from parameters in analysis table
    if (defined($params->{'param_file'})) {
	$self->param_file($params->{'param_file'});
    }
    if (defined($params->{'tree_file'})) {
	$self->tree_file($params->{'tree_file'});
    }
    if (defined($params->{'window_sizes'})) {
	$self->window_sizes($params->{'window_sizes'});
    }
    if (defined($params->{'constrained_element_method_link_type'})) {
	$self->constrained_element_method_link_type($params->{'constrained_element_method_link_type'});
    }
    if (defined($params->{'options'})) {
	$self->options($params->{'options'});
    }

    #read from input_id in analysis_job table
    if (defined($params->{'root_id'})) {
        $self->root_id($params->{'root_id'}); 
    }
    if(defined($params->{'species_set'})) {
        $self->species_set($params->{'species_set'});
    }
    return 1;
}

sub free_aligned_sequence {
  my ($leaf) = @_;

  my $genomic_align_group = $leaf->genomic_align_group;

  foreach my $this_genomic_align (@{$genomic_align_group->get_all_GenomicAligns}) {
    undef($this_genomic_align->{'aligned_sequence'});
  }
}


1;

#
# You may distribute this module under the same terms as perl itself
#
# POD documentation - main docs before the code

=pod 

=head1 NAME

Bio::EnsEMBL::Compara::RunnableDB::NJTREE_PHYML

=cut

=head1 SYNOPSIS

my $db           = Bio::EnsEMBL::Compara::DBAdaptor->new($locator);
my $njtree_phyml = Bio::EnsEMBL::Compara::RunnableDB::NJTREE_PHYML->new
  (
   -db         => $db,
   -input_id   => $input_id,
   -analysis   => $analysis
  );
$njtree_phyml->fetch_input(); #reads from DB
$njtree_phyml->run();
$njtree_phyml->output();
$njtree_phyml->write_output(); #writes to DB

=cut


=head1 DESCRIPTION

This Analysis/RunnableDB is designed to take ProteinTree as input
This must already have a multiple alignment run on it. It uses that alignment
as input into the NJTREE PHYML program which then generates a phylogenetic tree

input_id/parameters format eg: "{'protein_tree_id'=>1234}"
    protein_tree_id : use 'id' to fetch a cluster from the ProteinTree

=cut


=head1 CONTACT

  Contact Albert Vilella on module implementation/design detail: avilella@ebi.ac.uk
  Contact Abel Ureta-Vidal on EnsEMBL/Compara: abel@ebi.ac.uk
  Contact Ewan Birney on EnsEMBL in general: birney@sanger.ac.uk

=cut


=head1 APPENDIX

The rest of the documentation details each of the object methods. 
Internal methods are usually preceded with a _

=cut


package Bio::EnsEMBL::Compara::RunnableDB::NJTREE_PHYML;

use strict;
use IO::File;
use File::Basename;
use Time::HiRes qw(time gettimeofday tv_interval);

use Bio::EnsEMBL::Compara::Member;
use Bio::EnsEMBL::Compara::Graph::NewickParser;
use Bio::SimpleAlign;
use Bio::AlignIO;
use Bio::EnsEMBL::Compara::RunnableDB::OrthoTree; # check_for_split_gene method

use base ('Bio::EnsEMBL::Compara::RunnableDB::BaseRunnable', 'Bio::EnsEMBL::Compara::RunnableDB::OrthoTree');


sub param_defaults {
    return {
            'cdna'              => 1,   # always use cdna for njtree_phyml
            'bootstrap'         => 1,
            'max_gene_count'    => 410,
    };
}


sub fetch_input {
    my $self = shift @_;

    $self->check_job_fail_options;
    $self->check_if_exit_cleanly;

    $self->param('member_adaptor',       $self->compara_dba->get_MemberAdaptor);
    $self->param('protein_tree_adaptor', $self->compara_dba->get_ProteinTreeAdaptor);

    my $protein_tree_id     = $self->param('protein_tree_id') or die "'protein_tree_id' is an obligatory parameter";
    my $protein_tree        = $self->param('protein_tree_adaptor')->fetch_node_by_node_id( $protein_tree_id )
                                        or die "Could not fetch protein_tree with protein_tree_id='$protein_tree_id'";

    if ($protein_tree->get_tagvalue('gene_count') > $self->param('max_gene_count')) {
            # 3 is QuickTreeBreak -- 2 is NJTREE_PHYML jackknife
        $self->dataflow_output_id($self->input_id, 3);
        $protein_tree->release_tree;
        $self->param('protein_tree', undef);
        $self->input_job->incomplete(0);
        die "Cluster size over threshold, dataflowing to QuickTreeBreak\n";
    }

    $self->param('protein_tree', $protein_tree);
}


sub run {
  my $self = shift;

  $self->check_if_exit_cleanly;
  $self->run_njtree_phyml;
}


sub write_output {
  my $self = shift;

  $self->check_if_exit_cleanly;
  $self->store_proteintree;
}


sub DESTROY {
  my $self = shift;

  if(my $protein_tree = $self->param('protein_tree')) {
    printf("NJTREE_PHYML::DESTROY  releasing tree\n") if($self->debug);
    $protein_tree->release_tree;
    $self->param('protein_tree', undef);
  }

  $self->SUPER::DESTROY if $self->can("SUPER::DESTROY");
}


##########################################
#
# internal methods
#
##########################################


sub run_njtree_phyml {
  my $self = shift;

    my $protein_tree = $self->param('protein_tree');

  my $starttime = time()*1000;

  $self->check_for_split_genes;

  my $input_aln = $self->dumpTreeMultipleAlignmentToWorkdir ( $protein_tree ) or return;

  my $newick_file = $input_aln . "_njtree_phyml_tree.txt ";

  my $njtree_phyml_executable = $self->analysis->program_file || '';

  unless (-e $njtree_phyml_executable) {
    if (`uname -m` =~ /ia64/) {
      $njtree_phyml_executable = "/nfs/users/nfs_a/avilella/src/treesoft/trunk/treebest/ia64/treebest";
    } else {
      # it is a linux machine
      # md5sum 91a9da7ad7d38ebedd5ce363a28d509b
      # $njtree_phyml_executable = "/lustre/work1/ensembl/avilella/bin/i386/njtree_gcc";
      # $njtree_phyml_executable = "/nfs/acari/avilella/src/_treesoft/treebest/treebest";
      $njtree_phyml_executable = "/nfs/users/nfs_a/avilella/src/treesoft/trunk/treebest/treebest";
    }
  }

  $self->throw("can't find a njtree executable to run\n") unless(-e $njtree_phyml_executable);

  # Defining a species_tree
  # Option 1 is species_tree_string in protein_tree_tag, which then doesn't require tracking files around
  # Option 2 is species_tree_file which should still work for compatibility
  my $sql1 = "select value from protein_tree_tag where tag='species_tree_string'";
  my $sth1 = $self->dbc->prepare($sql1);
  $sth1->execute;
  my $species_tree_string = $sth1->fetchrow_hashref;
  $sth1->finish;
  my $eval_species_tree;
  eval {
    $eval_species_tree = Bio::EnsEMBL::Compara::Graph::NewickParser::parse_newick_into_tree($species_tree_string->{value});
    my @leaves = @{$eval_species_tree->get_all_leaves};
  };

  if($@) {
    unless(-e $self->param('species_tree_file')) {
      $self->throw("can't find species_tree\n");
    }
  } else {
    $self->param('species_tree_string', $species_tree_string->{value});
    my $spfilename = $self->worker_temp_directory . "spec_tax.nh";
    open SPECIESTREE, ">$spfilename" or die "$!";
    print SPECIESTREE $self->param('species_tree_string');
    close SPECIESTREE;
    $self->param('species_tree_file', $spfilename);
  }

  # ./njtree best -f spec-v4.1.nh -p tree -o $BASENAME.best.nhx \
  # $BASENAME.nucl.mfa -b 100 2>&1/dev/null

  my $cmd = $njtree_phyml_executable;
  if (1 == $self->param('bootstrap')) {
    $cmd .= " best ";
    if ($self->param('species_tree_file')) {
      $cmd .= " -f ". $self->param('species_tree_file');
    }
    $cmd .= " ". $input_aln;
    $cmd .= " -p tree ";
    $cmd .= " -o " . $newick_file;
    my $logfile = $self->worker_temp_directory. "proteintree_". $protein_tree->node_id . ".log";
    my $errfile = $self->worker_temp_directory. "proteintree_". $protein_tree->node_id . ".err";
    $cmd .= " 1>$logfile 2>$errfile";
    #     $cmd .= " 2>&1 > /dev/null" unless($self->debug);

    $self->compara_dba->dbc->disconnect_when_inactive(1);
    print("$cmd\n") if($self->debug);
    my $worker_temp_directory = $self->worker_temp_directory;

    unless(system("cd $worker_temp_directory; $cmd") == 0) {
      my $njtree_error = $!;
      print("$cmd\n");
      open ERRFILE,"$errfile" or die "couldnt open logfile $errfile: $!\n";
      while (<ERRFILE>) {
        if ($_ =~ /NNI/) {
          # Do jack-knife treebest starting by the sequence with more Ns
          my $jackknife_value = $self->param('jackknife') if ($self->param('jackknife'));
          $jackknife_value++;
          my $output_id = sprintf("{'protein_tree_id'=>%d, 'clusterset_id'=>1, 'jackknife'=>$jackknife_value}", $protein_tree->node_id);
          $self->input_job->input_id($output_id);
          $self->dataflow_output_id($output_id, 2);
          $protein_tree->release_tree;
          $self->param('protein_tree', undef);
          $self->input_job->incomplete(0);
          die "NNI error, dataflowing to NJTREE_PHYML+jackknife\n";
        }
      }
      $self->check_job_fail_options;
      $self->throw("error running njtree phyml: $njtree_error\n");
    }

    $self->compara_dba->dbc->disconnect_when_inactive(0);
  } elsif (0 == $self->param('bootstrap')) {
    # first part
    # ./njtree phyml -nS -f species_tree.nh -p 0.01 -o $BASENAME.cons.nh $BASENAME.nucl.mfa
    $cmd = $njtree_phyml_executable;
    $cmd .= " phyml -nS";
    if($self->param('species_tree_file')) {
      $cmd .= " -f ". $self->param('species_tree_file');
    }
    $cmd .= " ". $input_aln;
    $cmd .= " -p 0.01 ";

    my $intermediate_newick_file = $input_aln . "_intermediate_njtree_phyml_tree.txt ";
    $cmd .= " -o " . $intermediate_newick_file;
    $cmd .= " 2>&1 > /dev/null" unless($self->debug);

    print("$cmd\n") if($self->debug);
    my $worker_temp_directory = $self->worker_temp_directory;
    if(system("cd $worker_temp_directory; $cmd")) {
      print("$cmd\n");
      $self->check_job_fail_options;
      $self->throw("error running njtree phyml noboot (step 1 of 2), $!\n");
    }
    # second part
    # nice -n 19 ./njtree sdi -s species_tree.nh $BASENAME.cons.nh > $BASENAME.cons.nhx
    $cmd = $njtree_phyml_executable;
    $cmd .= " sdi ";
    if ($self->param('species_tree_file')) {
      $cmd .= " -s ". $self->param('species_tree_file');
    }
    $cmd .= " ". $intermediate_newick_file;
    $cmd .= " 1> " . $newick_file;
    $cmd .= " 2> /dev/null" unless($self->debug);

    $self->compara_dba->dbc->disconnect_when_inactive(1);
    print("$cmd\n") if($self->debug);
    my $worker_temp_directory = $self->worker_temp_directory;
    if(system("cd $worker_temp_directory; $cmd")) {
      print("$cmd\n");
      $self->check_job_fail_options;
      $self->throw("error running njtree phyml noboot (step 2 of 2), $!\n");
    }
    $self->compara_dba->dbc->disconnect_when_inactive(0);
  } else {
    $self->throw("NJTREE PHYML -- wrong bootstrap option");
  }

      #parse the tree into the datastucture:
  $self->parse_newick_into_proteintree( $newick_file );

  my $runtime = time()*1000-$starttime;

  $protein_tree->store_tag('NJTREE_PHYML_runtime_msec', $runtime);
}


sub check_job_fail_options {
  my $self = shift;

  # This will go to QuickTreeBreak
  if($self->input_job->retry_count >= 1 && !$self->param('jackknife')) {
    $self->dataflow_output_id($self->input_id, 3);

    $self->DESTROY;
    $self->input_job->incomplete(0);
    die "job failed, dataflowing to QuickTreeBreak\n";
  }
}


########################################################
#
# ProteinTree input/output section
#
########################################################

sub dumpTreeMultipleAlignmentToWorkdir {
  my $self = shift;
  my $protein_tree = shift;

  my $alignment_edits = $self->param('alignment_edits');

  my $leafcount = scalar(@{$protein_tree->get_all_leaves});
  if($leafcount<3) {
    printf(STDERR "tree cluster %d has <3 proteins - can not build a tree\n", 
           $protein_tree->node_id);
    return undef;
  }

  my $file_root = $self->worker_temp_directory. "proteintree_". $protein_tree->node_id;
  $file_root =~ s/\/\//\//g;  # converts any // in path to /

  my $aln_file = $file_root . '.aln';
  return $aln_file if(-e $aln_file);
  if($self->debug) {
    printf("dumpTreeMultipleAlignmentToWorkdir : %d members\n", $leafcount);
    print("aln_file = '$aln_file'\n");
  }

  open(OUTSEQ, ">$aln_file")
    or $self->throw("Error opening $aln_file for write");

  # Using append_taxon_id will give nice seqnames_taxonids needed for
  # njtree species_tree matching
  my %sa_params = $self->param('use_genomedb_id') ? ('-APPEND_GENOMEDB_ID', 1) : ('-APPEND_TAXON_ID', 1);

  ########################################
  # Gene split mirroring code
  #
  # This will have the effect of grouping the different
  # fragments of a gene split event together in a subtree
  #
  unless ($self->param('gs_mirror') =~ /FALSE/) {
    foreach my $split_type (keys %$alignment_edits) {
      foreach my $split_event (@{$alignment_edits->{$split_type}}) {
        my ($protein1,$protein2) = $split_event->get_nodes;
        my $cdna1 = $protein1->cdna_alignment_string;
        my $cdna2 = $protein2->cdna_alignment_string;
        # We start with the original cdna alignment string and add the
        # position in the other cdna for every gap position
        # e.g.
        # cdna1 = AAA AAA AAA AAA AAA --- --- --- --- --- ---
        # cdna2 = --- --- --- --- --- --- TTT TTT TTT TTT TTT
        # become
        # cdna1 = AAA AAA AAA AAA AAA --- TTT TTT TTT TTT TTT
        # cdna2 = AAA AAA AAA AAA AAA --- TTT TTT TTT TTT TTT
        $cdna1 =~ s/-/substr($cdna2, pos($cdna1), 1)/eg;
        $cdna2 =~ s/-/substr($cdna1, pos($cdna2), 1)/eg;
        # We then directly override the cached cdna_alignment_string
        # hash, which will be used next time is called for
        $protein1->{'cdna_alignment_string'} = $cdna1;
        $protein2->{'cdna_alignment_string'} = $cdna2;
        print STDERR "$split_type: Joining in ", $protein1->stable_id, " and ", $protein2->stable_id, " in input cdna alignment\n" if ($self->debug);

        $protein_tree->store_tag('msplit_'.$protein1->stable_id."_".$protein2->stable_id,$split_type);
        # In case of more than 2 fragments, the projection is going to
        # be done incrementally, the closest pairs pairs first.
        # e.g.
        # Fragment 1 and 2 are closer together than with 3
        # cdna1 = AAA AAA AAA AAA AAA --- --- --- --- --- --- --- --- --- --- --- ---
        # cdna2 = --- --- --- --- --- --- TTT TTT TTT TTT TTT --- --- --- --- --- ---
        # become
        # cdna1 = AAA AAA AAA AAA AAA --- TTT TTT TTT TTT TTT --- --- --- --- --- ---
        # cdna2 = AAA AAA AAA AAA AAA --- TTT TTT TTT TTT TTT --- --- --- --- --- ---
        #
        # and now then paired with 3, they becomes the full gene model:
        #
        # Original cdna3 will combine in pairs with previously merged cdna1/cdna2:
        # cdna3 = --- --- --- --- --- --- --- --- --- --- --- --- CCC CCC CCC CCC CCC
        # and form:
        # cdna1 = AAA AAA AAA AAA AAA --- TTT TTT TTT TTT TTT --- CCC CCC CCC CCC CCC
        # cdna2 = AAA AAA AAA AAA AAA --- TTT TTT TTT TTT TTT --- CCC CCC CCC CCC CCC
        # cdna3 = AAA AAA AAA AAA AAA --- TTT TTT TTT TTT TTT --- CCC CCC CCC CCC CCC
      }
    }
  }
  ########################################

  print STDERR "fetching alignment\n" if ($self->debug);
  my $sa = $protein_tree->get_SimpleAlign
    (
     -id_type => 'MEMBER',
     -cdna=>$self->param('cdna'),
     -stop2x => 1,
     %sa_params
    );
  $sa->set_displayname_flat(1);
  if ($self->param('jackknife')) {
    # my $coverage_hash;
    my $empty_hash;
    foreach my $seq ($sa->each_seq) {
      my $sequence = $seq->seq;
      $sequence =~ s/\-//g;
      my $full_length = length($sequence);
      $sequence =~ s/N//g;
      my $covered_length = length($sequence);
      my $coverage_proportion = $covered_length/$full_length;
      my $empty_length = $full_length - $covered_length;
      # $coverage_hash->{$coverage_proportion} = $seq->display_id if ($coverage_proportion < 1);
      $empty_hash->{$empty_length} = $seq->display_id if ($empty_length > 0);
    }
    my @lowest = sort {$b<=>$a} keys %$empty_hash;
    my $i = 0;
    while ($i < $self->param('jackknife')) {
      $sa->remove_seq($sa->each_seq_with_id($empty_hash->{$lowest[$i]}));
      $sa = $sa->remove_gaps(undef,1);
      $i++;
    }
  }

  my $alignIO = Bio::AlignIO->newFh
    (
     -fh => \*OUTSEQ,
     -format => "fasta"
    );
  print $alignIO $sa;

  close OUTSEQ;

  return $aln_file;
}


sub store_proteintree
{
  my $self = shift;

    my $protein_tree = $self->param('protein_tree') or return;
    my $protein_tree_adaptor = $self->param('protein_tree_adaptor');

  printf("PHYML::store_proteintree\n") if($self->debug);

  $protein_tree_adaptor->sync_tree_leftright_index( $protein_tree );
  $protein_tree->clusterset_id( $self->param('clusterset_id') );
  $protein_tree_adaptor->store( $protein_tree );
  $protein_tree_adaptor->delete_nodes_not_in_tree( $protein_tree );

  if($self->debug >1) {
    print("done storing - now print\n");
    $protein_tree->print_tree;
  }

  $protein_tree->store_tag('PHYML_alignment', 'njtree_phyml');
  $protein_tree->store_tag('reconciliation_method', 'njtree_best');
  $self->store_tags( $protein_tree );

  $self->_store_tree_tags;

  return undef;
}

sub store_tags
{
  my $self = shift;
  my $node = shift;

    my $protein_tree = $self->param('protein_tree');

  if($self->param('jackknife')) {
    my $leaf_count = $protein_tree->num_leaves;
    $protein_tree->store_tag( 'gene_count', $leaf_count );
  }

  if($node->get_tagvalue("Duplication") eq '1') {
    if($self->debug) { printf("store duplication : "); $node->print_node; }
    $node->store_tag('Duplication', 1);
  } else {
    $node->store_tag('Duplication', 0);
  }

  if (defined($node->get_tagvalue("B"))) {
    my $bootstrap_value = $node->get_tagvalue("B");
    if (defined($bootstrap_value) && $bootstrap_value ne '') {
      if ($self->debug) {
        printf("store bootstrap : $bootstrap_value "); $node->print_node;
      }
      $node->store_tag('Bootstrap', $bootstrap_value);
    }
  }
  if (defined($node->get_tagvalue("DD"))) {
    my $dubious_dup = $node->get_tagvalue("DD");
    if (defined($dubious_dup) && $dubious_dup ne '') {
      if ($self->debug) {
        printf("store dubious_duplication : $dubious_dup "); $node->print_node;
      }
      $node->store_tag('dubious_duplication', $dubious_dup);
    }
  }
  if (defined($node->get_tagvalue("E"))) {
    my $n_lost = $node->get_tagvalue("E");
    $n_lost =~ s/.{2}//;        # get rid of the initial $-
    my @lost_taxa = split('-',$n_lost);
    my %lost_taxa;
    foreach my $taxon (@lost_taxa) {
      $lost_taxa{$taxon} = 1;
    }
    foreach my $taxon (keys %lost_taxa) {
      if ($self->debug) {
        printf("store lost_taxon_id : $taxon "); $node->print_node;
      }
      $node->store_tag('lost_taxon_id', $taxon, 1);
    }
  }
  if (defined($node->get_tagvalue("SISi"))) {
    my $sis_score = $node->get_tagvalue("SISi");
    if (defined($sis_score) && $sis_score ne '') {
      if ($self->debug) {
        printf("store SISi : $sis_score "); $node->print_node;
      }
      $node->store_tag('SISi', $sis_score);
    }
  }
  if (defined($node->get_tagvalue("SISu"))) {
    my $sis_score = $node->get_tagvalue("SISu");
    if (defined($sis_score) && $sis_score ne '') {
      if ($self->debug) {
        printf("store SISu : $sis_score "); $node->print_node;
      }
      $node->store_tag('SISu', $sis_score);
    }
  }
  if (defined($node->get_tagvalue("SIS"))) {
    my $sis_score = $node->get_tagvalue("SIS");
    if (defined($sis_score) && $sis_score ne '') {
      if ($self->debug) {
        printf("store species_intersection_score : $sis_score "); $node->print_node;
      }
      $node->store_tag('species_intersection_score', $sis_score);
    }
  }
  if (defined($node->get_tagvalue("SIS1"))) {
    my $sis_score = $node->get_tagvalue("SIS1");
    if (defined($sis_score) && $sis_score ne '') {
      if ($self->debug) {
        printf("store SIS1 : $sis_score "); $node->print_node;
      }
      $node->store_tag('SIS1', $sis_score);
    }
  }
  if (defined($node->get_tagvalue("SIS2"))) {
    my $sis_score = $node->get_tagvalue("SIS2");
    if (defined($sis_score) && $sis_score ne '') {
      if ($self->debug) {
        printf("store SIS2 : $sis_score "); $node->print_node;
      }
      $node->store_tag('SIS2', $sis_score);
    }
  }

  foreach my $child (@{$node->children}) {
    $self->store_tags($child);
  }
  return undef;
}

sub parse_newick_into_proteintree {
  my $self = shift;
  my $newick_file = shift;

  my $protein_tree = $self->param('protein_tree');
  
  #cleanup old tree structure- 
  #  flatten and reduce to only GeneTreeMember leaves
  $protein_tree->flatten_tree;
  $protein_tree->print_tree(20) if($self->debug);
  foreach my $node (@{$protein_tree->get_all_leaves}) {
    next if($node->isa('Bio::EnsEMBL::Compara::GeneTreeMember'));
    $node->disavow_parent;
  }

  #parse newick into a new tree object structure
  my $newick = '';
  print("load from file $newick_file\n") if($self->debug);
  open (FH, $newick_file) or $self->throw("Couldnt open newick file [$newick_file]");
  while(<FH>) { $newick .= $_;  }
  close(FH);

  my $newtree = 
    Bio::EnsEMBL::Compara::Graph::NewickParser::parse_newick_into_tree($newick);
  $newtree->print_tree(20) if($self->debug > 1);
  # get rid of the taxon_id needed by njtree -- name tag
  foreach my $leaf (@{$newtree->get_all_leaves}) {
    my $njtree_phyml_name = $leaf->get_tagvalue('name');
    $njtree_phyml_name =~ /(\d+)\_\d+/;
    my $member_name = $1;
    $leaf->add_tag('name', $member_name);
  }

  # Leaves of newick tree are named with member_id of members from
  # input tree move members (leaves) of input tree into newick tree to
  # mirror the 'member_id' nodes
  foreach my $member (@{$protein_tree->get_all_leaves}) {
    my $tmpnode = $newtree->find_node_by_name($member->member_id);
    if($tmpnode) {
      $tmpnode->add_child($member, 0.0);
      $tmpnode->minimize_node; #tmpnode is now redundant so it is removed
    } else {
      print("unable to find node in newick for member"); 
      $member->print_member;
    }
  }

  # Merge the trees so that the children of the newick tree are now
  # attached to the input tree's root node
  $protein_tree->merge_children($newtree);

  # Newick tree is now empty so release it
  $newtree->release_tree;

  $protein_tree->print_tree if($self->debug);
  # check here on the leaf to test if they all are GeneTreeMember as
  # minimize_tree/minimize_node might not work properly
  foreach my $leaf (@{$self->param('protein_tree')->get_all_leaves}) {
    unless($leaf->isa('Bio::EnsEMBL::Compara::GeneTreeMember')) {
      $self->throw("Phyml tree does not have all leaves as GeneTreeMembers\n");
    }
  }

  return undef;
}

sub _store_tree_tags {
    my $self = shift;

  my $protein_tree = $self->param('protein_tree');
    my $pta = $self->compara_dba->get_ProteinTreeAdaptor;

    print "Storing Tree tags...\n";

    my @leaves = @{$protein_tree->get_all_leaves};
    my @nodes = @{$protein_tree->get_all_nodes};

    # Tree number of leaves.
    my $tree_num_leaves = scalar(@leaves);
    $protein_tree->store_tag("tree_num_leaves",$tree_num_leaves);

    # Tree number of human peptides contained.
    my $num_hum_peps = 0;
    foreach my $leaf (@leaves) {
	$num_hum_peps++ if ($leaf->taxon_id == 9606);
    }
    $protein_tree->store_tag("tree_num_human_peps",$num_hum_peps);

    # Tree max root-to-tip distance.
    my $tree_max_length = $protein_tree->max_distance;
    $protein_tree->store_tag("tree_max_length",$tree_max_length);

    # Tree max single branch length.
    my $tree_max_branch = 0;
    foreach my $node (@nodes) {
        my $dist = $node->distance_to_parent;
        $tree_max_branch = $dist if ($dist > $tree_max_branch);
    }
    $protein_tree->store_tag("tree_max_branch",$tree_max_branch);

    # Tree number of duplications and speciations.
    my $tree_num_leaves = scalar(@{$protein_tree->get_all_leaves});
    my $num_dups = 0;
    my $num_specs = 0;
    foreach my $node (@{$protein_tree->get_all_nodes}) {
	my $dup = $node->get_tagvalue("Duplication");
	if ($dup ne '' && $dup > 0) {
	    $num_dups++;
	} else {
	    $num_specs++;
	}
    }
    $protein_tree->store_tag("tree_num_dup_nodes",$num_dups);
    $protein_tree->store_tag("tree_num_spec_nodes",$num_specs);

    print "Done storing stuff!\n" if ($self->debug);
}

sub check_for_split_genes {
  my $self = shift;
  my $protein_tree = $self->param('protein_tree');

  my $alignment_edits = $self->param('alignment_edits', {});

  my $tmp_time = time();

  my @all_protein_leaves = @{$protein_tree->get_all_leaves};
  printf("%1.3f secs to fetch all leaves\n", time()-$tmp_time) if ($self->debug);

  if($self->debug) {
    printf("%d proteins in tree\n", scalar(@all_protein_leaves));
  }
  printf("build paralogs graph\n") if($self->debug);
  my @genepairlinks;
  my $graphcount = 0;
  my $tree_node_id = $protein_tree->node_id;
  while (my $protein1 = shift @all_protein_leaves) {
    foreach my $protein2 (@all_protein_leaves) {
      next unless ($protein1->genome_db_id == $protein2->genome_db_id);
      my $genepairlink = new Bio::EnsEMBL::Compara::Graph::Link
        (
         $protein1, $protein2, 0
        );
      $genepairlink->add_tag("tree_node_id", $tree_node_id);
      push @genepairlinks, $genepairlink;
      print STDERR "build graph $graphcount\n" if ($graphcount++ % 10 == 0);
    }
  }
  printf("%1.3f secs build links and features\n", time()-$tmp_time) if($self->debug>1);

  # We sort the pairings by seq_region (chr) name, then by distance between
  # the start of link_node pairs.
  # This is to try to do the joining up of cdnas in the best order in
  # cases of e.g. 2 cases of 3-way split genes in same species.
  my @sorted_genepairlinks = sort { 
    $a->{_link_node1}->chr_name <=> $b->{_link_node1}->chr_name 
 || $a->{_link_node2}->chr_name <=> $b->{_link_node2}->chr_name 
 || abs($a->{_link_node1}->chr_start - $a->{_link_node2}->chr_start) <=> abs($b->{_link_node1}->chr_start - $b->{_link_node2}->chr_start) } @genepairlinks;

  foreach my $genepairlink (@sorted_genepairlinks) {
    my $type = 'within_species_paralog';
    my ($protein1, $protein2) = $genepairlink->get_nodes;
    my ($cigar_line1, $perc_id1, $perc_pos1,
        $cigar_line2, $perc_id2, $perc_pos2) = 
        $self->generate_attribute_arguments($protein1, $protein2,$type);
    print STDERR "Pair: ", $protein1->stable_id, " - ", $protein2->stable_id, "\n" if ($self->debug);

    # Checking for gene_split cases
    if ($type eq 'within_species_paralog' && 0 == $perc_id1 && 0 == $perc_id2 && 0 == $perc_pos1 && 0 == $perc_pos2) {

      # Condition A1: If same seq region and less than 1MB distance
      my $gene_member1 = $protein1->gene_member; my $gene_member2 = $protein2->gene_member;
      if ($gene_member1->chr_name eq $gene_member2->chr_name 
          && (1000000 > abs($gene_member1->chr_start - $gene_member2->chr_start)) 
          && $gene_member1->chr_strand eq $gene_member2->chr_strand ) {

        # Condition A2: there have to be the only 2 or 3 protein coding
        # genes in the range defined by the gene pair. This should
        # strictly be 2, only the pair in question, but in clean perc_id
        # = 0 cases, we allow for 2+1: the rare case where one extra
        # protein coding gene is partially or fully embedded in another.
        my $start1 = $gene_member1->chr_start; my $start2 = $gene_member2->chr_start; my $starttemp;
        my $end1 = $gene_member1->chr_end; my $end2 = $gene_member2->chr_end; my $endtemp;
        if ($start1 > $start2) { $starttemp = $start1; $start1 = $start2; $start2 = $starttemp; }
        if ($end1   <   $end2) {   $endtemp = $end1;     $end1 = $end2;     $end2 = $endtemp; }
        my $strand1 = $gene_member1->chr_strand; my $taxon_id1 = $gene_member1->taxon_id; my $name1 = $gene_member1->chr_name;
        print STDERR "Checking split genes overlap\n";
        my @genes_in_range = @{$self->param('member_adaptor')->_fetch_all_by_source_taxon_chr_name_start_end_strand_limit('ENSEMBLGENE',$taxon_id1,$name1,$start1,$end1,$strand1,4)};

        if (3 < scalar @genes_in_range) {
          foreach my $gene (@genes_in_range) {
            print STDERR "More than 2 genes in range...";
            print STDERR "Genes in range ($start1,$end1,$strand1): ", $gene->stable_id,",", $gene->chr_start,",", $gene->chr_end,"\n";
          }
          next;
        }
        push @{$alignment_edits->{contiguous_gene_split}}, $genepairlink;
      }


      # This is a second level of contiguous gene split events, more
      # stringent on contig but less on alignment, for "skidding"
      # alignment cases.

      # These cases take place when a few of the aminoacids in the
      # alignment have been wrongly displaced from the columns that
      # correspond to the fragment, so the identity level is slightly
      # above 0. This small number of misplaced aminoacids look like
      # "skid marks" in the alignment view.

      # Condition B1: all 4 percents below 10
    } elsif ($type eq 'within_species_paralog' 
             && $perc_id1 < 10 
             && $perc_id2 < 10 
             && $perc_pos1 < 10 
             && $perc_pos2 < 10) {
      my $gene_member1 = $protein1->gene_member; my $gene_member2 = $protein2->gene_member;

    # Condition B2: If non-overlapping and smaller than 500kb start and 500kb end distance
      if ($gene_member1->chr_name eq $gene_member2->chr_name 
          && (500000 > abs($gene_member1->chr_start - $gene_member2->chr_start)) 
          && (500000 > abs($gene_member1->chr_end - $gene_member2->chr_end)) 
          && (($gene_member1->chr_start - $gene_member2->chr_start)*($gene_member1->chr_end - $gene_member2->chr_end)) > 1
          && $gene_member1->chr_strand eq $gene_member2->chr_strand ) {

    # Condition B3: they have to be the only 2 genes in the range:
        my $start1 = $gene_member1->chr_start; my $start2 = $gene_member2->chr_start; my $starttemp;
        my $end1 = $gene_member1->chr_end; my $end2 = $gene_member2->chr_end; my $endtemp;
        if ($start1 > $start2) { $starttemp = $start1; $start1 = $start2; $start2 = $starttemp; }
        if ($end1   <   $end2) {   $endtemp = $end1;     $end1 = $end2;     $end2 = $endtemp; }
        my $strand1 = $gene_member1->chr_strand; my $taxon_id1 = $gene_member1->taxon_id; my $name1 = $gene_member1->chr_name;

        my @genes_in_range = @{$self->param('member_adaptor')->_fetch_all_by_source_taxon_chr_name_start_end_strand_limit('ENSEMBLGENE',$taxon_id1,$name1,$start1,$end1,$strand1,4)};
        if (2 < scalar @genes_in_range) {
          foreach my $gene (@genes_in_range) {
            print STDERR "More than 2 genes in range...";
            print STDERR "Genes in range ($start1,$end1,$strand1): ", $gene->stable_id,",", $gene->chr_start,",", $gene->chr_end,"\n";
          }
          next;
        }

    # Condition B4: discard if the smaller protein is 1/10 or less of the larger and all percents above 2
        my $len1 = length($protein1->sequence); my $len2 = length($protein2->sequence); my $temp;
        if ($len1 < $len2) { $temp = $len1; $len1 = $len2; $len2 = $temp; }
        if ($len1/$len2 > 10 && $perc_id1 > 2 && $perc_id2 > 2 && $perc_pos1 > 2 && $perc_pos2 > 2) {
          next;
        }
        push @{$alignment_edits->{skidding_contiguous_gene_split}}, $genepairlink;
      }
    }
  }

  printf("%1.3f secs label gene splits\n", time()-$tmp_time) if($self->debug>1);

  if($self->debug) {
    printf("%d pairings\n", scalar(@sorted_genepairlinks));
  }

  return 1;
}


1;

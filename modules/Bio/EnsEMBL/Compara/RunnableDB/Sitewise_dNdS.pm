#
# You may distribute this module under the same terms as perl itself
#
# POD documentation - main docs before the code

=pod 

=head1 NAME

Bio::EnsEMBL::Compara::RunnableDB::Sitewise_dNdS

=cut

=head1 SYNOPSIS

my $db            = Bio::EnsEMBL::Compara::DBAdaptor->new($locator);
my $sitewise_dNdS = Bio::EnsEMBL::Compara::RunnableDB::Sitewise_dNdS->new
  (
   -db         => $db,
   -input_id   => $input_id,
   -analysis   => $analysis
  );
$sitewise_dNdS->fetch_input(); #reads from DB
$sitewise_dNdS->run();
$sitewise_dNdS->output();
$sitewise_dNdS->write_output(); #writes to DB

=cut


=head1 DESCRIPTION

This Analysis/RunnableDB is designed to take a ProteinTree or subtree
as input. This must already have a multiple alignment and a genetree
run on it. It uses the alignment and tree as input into the SLR
program which then generates annotations for the codons/peptides and
the branches in the genetree.

input_id/parameters format eg: "{'protein_tree_id'=>1234}"
    protein_tree_id : use 'id' to fetch a cluster from the ProteinTree

=cut


=head1 CONTACT

  Contact Albert Vilella on module implementation/design detail: avilella@ebi.ac.uk
  Contact Ewan Birney on EnsEMBL in general: birney@sanger.ac.uk

=cut


=head1 APPENDIX

The rest of the documentation details each of the object methods. 
Internal methods are usually preceded with a _

=cut


package Bio::EnsEMBL::Compara::RunnableDB::Sitewise_dNdS;

use strict;
use Getopt::Long;
use IO::File;
use File::Basename;
use Time::HiRes qw(time gettimeofday tv_interval);

use Bio::EnsEMBL::DBSQL::DBAdaptor;
use Bio::EnsEMBL::Compara::DBSQL::DBAdaptor;

use Bio::AlignIO;
use Bio::TreeIO;
use Bio::SimpleAlign;

use Cwd;

use Bio::EnsEMBL::Hive;
our @ISA = qw(Bio::EnsEMBL::Hive::Process);


=head2 fetch_input

    Title   :   fetch_input
    Usage   :   $self->fetch_input
    Function:   Fetches input data for repeatmasker from the database
    Returns :   none
    Args    :   none

=cut


sub fetch_input {
  my( $self) = @_;

  $self->check_job_fail_options;
  throw("No input_id") unless defined($self->input_id);

  #create a Compara::DBAdaptor which shares the same DBI handle
  #with the Pipeline::DBAdaptor that is based into this runnable
  $self->{'comparaDBA'} = Bio::EnsEMBL::Compara::DBSQL::DBAdaptor->new
    (
     -DBCONN=>$self->db->dbc
    );

  $self->get_params($self->parameters);
  $self->get_params($self->input_id);
  $self->print_params if($self->debug);
  $self->check_if_exit_cleanly;

  unless ($self->{'protein_tree'}) {
    throw("undefined ProteinTree as input\n");
  }
  my $num_leaves = $self->{'protein_tree'}->num_leaves;
  $self->{'protein_tree'}->print_tree(10) if ($self->debug);
  if ($num_leaves < 4) {
    $self->{'protein_tree'}->release_tree;
    $self->{'protein_tree'} = undef;
    return undef;
    # throw("Sitewise_dNdS : cluster size under 4 threshold and FAIL it");
  }
  $self->{'cds_aln'} = $self->{'protein_tree'}->get_SimpleAlign(-cdna => 1);
  $self->{'tree'} = $self->{'protein_tree'}->newick_format("int_node_id");

  return 1;
}


=head2 run

    Title   :   run
    Usage   :   $self->run
    Function:   runs SLR
    Returns :   none
    Args    :   none

=cut


sub run {
  my $self = shift;
  $self->check_if_exit_cleanly;
  $self->run_sitewise_dNdS;
}


=head2 write_output

    Title   :   write_output
    Usage   :   $self->write_output
    Function:   stores SLR annotations
    Returns :   none
    Args    :   none

=cut


sub write_output {
  my $self = shift;

  unless (defined($self->{results})) {
    $self->input_job->update_status('FAILED');
    return undef;
  }
  $self->check_if_exit_cleanly;
  if (defined($self->{'results'}{saturated})) {
    $self->{'protein_tree'}->store_tag('Sitewise_dNdS_saturated', $self->{'results'}{saturated});
    # create another job for each subtree
    if (defined($self->{'results'}{trees})) {
      $self->{treeDBA} = $self->{'comparaDBA'}->get_ProteinTreeAdaptor;
      foreach my $subtree_num (keys %{$self->{'results'}{trees}}) {
        my $subtree = $self->{'results'}{trees}{$subtree_num};
        my @nodes;
        foreach my $node ($subtree->get_nodes) {
          if ($node->is_Leaf) {
            push @nodes, $node->id;
          }
        }
        my $members;
        foreach my $node (@nodes) {
          $node =~ s/\s+//;
          $members->{$node} = 1;
        }
        my $partial_tree = $self->{treeDBA}->fetch_node_by_node_id($self->{'protein_tree'}->node_id);
        # print STDERR "[subtree $subtree_num] ",time()-$self->{starttime}," secs...\n" if ($self->debug); $self->{starttime} = time();
        foreach my $leaf (@{$partial_tree->get_all_leaves}) {
          next if (defined($members->{$leaf->stable_id}));
          $leaf->disavow_parent;
          $partial_tree = $partial_tree->minimize_tree;
        }
        my $subroot = $partial_tree->node_id;
        $partial_tree->release_tree;
        next if ($partial_tree->num_leaves >= $self->{'protein_tree'}->num_leaves);

        my $output_id = sprintf("{'protein_tree_id'=>%d, 'clusterset_id'=>1}", $subroot);
        $self->input_job->input_id($output_id);
        $self->dataflow_output_id($output_id, 2);
      }
    }
    $self->input_job->update_status('FAILED');
    $self->{'protein_tree'}->release_tree;
    $self->{'protein_tree'} = undef;
    warn("Sitewise_dNdS : cluster saturated, creating jobs for subtrees and FAIL it");
    return undef;
    #throw("Sitewise_dNdS : cluster saturated, creating jobs for subtrees and FAIL it");

  } elsif (defined($self->{'results'}{sites})) {
    $self->store_sitewise_dNdS;
  } else {
    # something wrong went on
    $self->{'protein_tree'}->release_tree;
  }
}


sub DESTROY {
  my $self = shift;

  if ($self->{'protein_tree'}) {
    printf("Sitewise_dNdS::DESTROY  releasing tree\n") if($self->debug);
    $self->{'protein_tree'}->release_tree;
    $self->{'protein_tree'} = undef;
  }

  $self->SUPER::DESTROY if $self->can("SUPER::DESTROY");
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
  print("parsing parameter string : ",$param_string,"\n") if($self->debug);

  my $params = eval($param_string);
  return unless($params);

  if (defined($params->{'protein_tree_id'})) {
    $self->{'protein_tree'} = 
      $self->{'comparaDBA'}->get_ProteinTreeAdaptor->
        fetch_node_by_node_id($params->{'protein_tree_id'});
  } elsif (defined($params->{'saturated'})) {
        $self->{'saturated'} = $params->{'saturated'};
  }

  return;
}


sub print_params {
  my $self = shift;

  print("params:\n");
  print("  tree_id   : ", $self->{'protein_tree'}->node_id,"\n") if($self->{'protein_tree'});
}


sub run_sitewise_dNdS
{
  my $self = shift;

  return undef unless (defined($self->{protein_tree}));
  $self->{starttime} = time()*1000;

  my $slrexe = $self->analysis->program_file;
  unless (-e $slrexe) {
    $slrexe = "/software/ensembl/compara/bin/Slr_ensembl";
  }

  throw("can't find an slr executable to run\n") 
    unless(-e $slrexe);

  my $aln = $self->{'cds_aln'};

  my $tree_string = $self->{'tree'};
  open(my $fake_fh, "+<", \$tree_string);
  my $treein = new Bio::TreeIO
    (-fh => $fake_fh,
     -format => 'newick');
  my $tree = $treein->next_tree;
  $treein->close;
  throw("can't find cds_aln\n") if ( ! $aln );
  throw("can't find tree\n") if ( ! $tree );

  # Reorder the alignment according to the tree
  my $ct = 1;
  my %order;
  foreach my $node ($tree->get_leaf_nodes) {
    $order{$node->id} = $ct++;
  }

  my @seq; my @ids;
  foreach my $seq ( $aln->each_seq() ) {
    push @seq, $seq;
    push @ids, $seq->display_id;
  }
  # use the map-sort-map idiom:
  my @sorted = map { $_->[1] } sort { $a->[0] <=> $b->[0] } map { [$order{$_->id()}, $_] } @seq;
  my $sorted_aln = Bio::SimpleAlign->new();
  foreach (@sorted) {
    $sorted_aln->add_seq($_);
  }

  # Mask the aligment
  $self->run_gblocks(0.5,$sorted_aln);
  my $mask;
  my $aln_length = $sorted_aln->length;
  foreach my $seq ($sorted_aln->each_seq) {
    my $seqstring = $seq->seq;
    my $start = 1;
    foreach my $segment ($self->{flanks} =~ /(\[\d+  \d+\])/g) {
      my ($segm_start,$segm_end) = $segment =~ /\[(\d+)  (\d+)\]/;
      my $mask = 'N' x ($segm_start-$start);
      if (0 != $segm_start-$start) {
        substr($seqstring,($start-1),($segm_start-$start),$mask);
      }
      $start = $segm_end + 1;
    }
    if ($start < $aln_length) { # last segment to mask
      my $mask = 'N' x ($aln_length-$start+1); substr($seqstring,($start-1),($aln_length-$start+1),$mask);
    }
    $seq->seq($seqstring);
  }
  throw("malformed masked alignment of the wrong length") unless ($aln_length == $sorted_aln->length);
  ####

  my $tmpdir = $self->worker_temp_directory;
  my $alnout = Bio::AlignIO->new
    ('-format'      => 'phylip',
     '-file'          => ">$tmpdir/aln",
     '-interleaved' => 0,
     '-idlinebreak' => 1,
     '-idlength'    => $aln->maxdisplayname_length + 1);
  $alnout->write_aln($sorted_aln);
  $alnout->close();
  undef $alnout;

  my $treeout = Bio::TreeIO->new('-format' => 'newick',
                                 '-file'     => ">$tmpdir/tree");
  # We need to add a line with the num of leaves ($ct-1) and the
  # num of trees (1)
  $treeout->_print(sprintf("%d 1\n",($ct-1)));
  $treeout->write_tree($tree);
  $treeout->close();

  # now let's print the ctl file.
  # many of the these programs are finicky about what the filename is 
  # and won't even run without the properly named file.
  my $slr_ctl = "$tmpdir/slr.ctl";
  open(SLR, ">$slr_ctl") or throw("cannot open $slr_ctl for writing");
  print SLR "seqfile\: aln\n";
  print SLR "treefile\: tree\n";
  my $outfile = "slr.res";
  print SLR "outfile\: $outfile\n";
  if (defined($self->{'saturated'})) {
    print SLR "saturated\: ". $self->{'saturated'} . "\n";
  }
  if (defined($self->{'gencode'})) {
    print SLR "gencode\: ". $self->{'gencode'} . "\n";
  }
  print SLR "aminof\: 1\n"; # aminof
  close(SLR);

  my ($rc,$results) = (1);
  {
    my $cwd = cwd();
    my $exit_status;
    chdir($tmpdir);
    my $run;
    my $quiet = ''; $quiet = ' 2>/dev/null' unless ($self->debug);
    $self->{'comparaDBA'}->dbc->disconnect_when_inactive(1);
    open($run, "$slrexe $quiet |") or throw("Cannot open exe $slrexe");
    my @output = <$run>;
    $exit_status = close($run);
    $self->{'comparaDBA'}->dbc->disconnect_when_inactive(0);
    $self->{error_string} = (join('',@output));
    if ( (grep { /is saturated/ } @output)) {
      $results->{saturated} = $self->{'saturated'};
      my $min = 999;
      foreach my $line (grep { /is saturated/ } @output) {
        $line =~ /length = (\S+)/;
        $min = $1 if ($1 < $min);
      }
      $results->{saturated} = sprintf("%2.3f",$min);
      if (-e "$tmpdir/subtrees.out") {
        my $treeio = Bio::TreeIO->new
          ('-format' => 'newick',
           '-file'   => "$tmpdir/subtrees.out");
        my $tree_num= 1;
        while ( my $tree = $treeio->next_tree ) {
          $results->{trees}{$tree_num} = $tree;
          $tree_num++;
        }
      }
      chdir($cwd);
      $self->{'results'} = $results;
      $self->{'rc'} = $rc;
      return undef;
    }

    foreach my $outline (@output) {
      if ($outline =~ /lnL = (\S+)/) {
        $results->{lnL} = $1;
      }
      if ($outline =~ /kappa = (\S+)/) {
        $results->{kappa} = $1;
      }
      if ($outline =~ /omega = (\S+)/) {
        $results->{omega} = $1;
      }
    }
    if ( (grep { /\berr(or)?: /io } @output)  || !$exit_status) {
      warn("There was an error - see error_string for the program output");
      warn('Error string: '.$self->{error_string}) if $self->debug;
      $rc = 0;
    }
    eval {
      open RESULTS, "$tmpdir/$outfile" or die "couldnt open results file: $!\n";
      my $okay = 0;
      my $sites;
      my $type = 'default';
      while (<RESULTS>) {
        chomp $_;
        if ( /^\#/ ) {
          next;
        }
        if ( /\!/ ) {
          $type = 'random';
        }                     # random is last
        elsif ( /\+\+\+\+\s+/ ) {
          $type = 'positive4';
        } elsif ( /\+\+\+\s+/ ) {
          $type = 'positive3';
        } elsif ( /\+\+\s+/ ) {
          $type = 'positive2';
        } elsif ( /\+\s+/ ) {
          $type = 'positive1';
        } elsif ( /\-\-\-\-\s+/ ) {
          $type = 'negative4';
        } elsif ( /\-\-\-\s+/ ) {
          $type = 'negative3';
        } elsif ( /\-\-\s+/ ) {
          $type = 'negative2';
        } elsif ( /\-\s+/ ) {
          $type = 'negative1';
        } elsif ( /Constant/ ) {
          $type = 'constant';
        } elsif ( /All gaps/ ) {
          $type = 'all_gaps';
        } elsif ( /Single character/ ) {
          $type = 'single_character';
        } elsif ( /Synonymous/ ) {
          $type = 'synonymous';
        } else {
          $type = 'default';
        }
        if ( /^\s+(\d+)\s+(\S+)\s+(\S+)\s+(\S+)\s+(\S+)\s+(\S+)\s+(\S+)\s+(\S+)\s+(\S+)/ ) {
          push @{$sites->{$type}}, [$1,$2,$3,$4,$5,$6,$7,$8,$9];
        } else {
          warn("error parsing the results: $_\n");
        }
      }
      $results->{sites} = $sites;
      close RESULTS;
    };
    if ( $@ ) {
      warn($self->{error_string});
    }
    chdir($cwd);
  }

  $self->{'results'} = $results;
  $self->{'rc'} = $rc;

  return undef;
}


sub check_job_fail_options
  {
    my $self = shift;

    if ($self->input_job->retry_count >= 2) {
      $self->dataflow_output_id($self->input_id, 2);
      $self->input_job->update_status('FAILED');

      if ($self->{'protein_tree'}) {
        $self->{'protein_tree'}->release_tree;
        $self->{'protein_tree'} = undef;
      }
      throw("Sitewise_dNdS job failed >=3 times: try something else and FAIL it");
    }
  }


sub run_gblocks
  {
    my $self = shift;
    my $gmin = shift;
    my $aln  = shift;

    printf("Sitewise_dNdS::run_gblocks\n") if($self->debug);

    throw("Sitewise_dNdS : error getting Peptide SimpleAlign") unless (defined($aln));

    my $aln_length = $aln->length;
    my $tree_id = $self->{'protein_tree'}->node_id;
    my $tmpdir = $self->worker_temp_directory;
    my $filename = "$tmpdir". "$tree_id.fasta";
    my $tmpfile = Bio::AlignIO->new
      (-file => ">$filename",
       -format => 'fasta');
    $tmpfile->write_aln($aln);
    $tmpfile->close;
    my $min_leaves_gblocks = int(($self->{'protein_tree'}->num_leaves+1) * $gmin + 0.5);
    my $cmd = "echo -e \"o\n$filename\nt\nb\n2\n$min_leaves_gblocks\n5\n5\ng\nm\nq\n\" | /software/ensembl/compara/bin/Gblocks 2>/dev/null 1>/dev/null";
    $DB::single=1;1;#??
    my $ret = system("$cmd");
    open FLANKS, "$filename-gb.htm" or die "$!\n";
    my $segments_string;
    while (<FLANKS>) {
      chomp $_;
      next unless ($_ =~ /Flanks/);
      $segments_string = $_;
      last;
    }
    close FLANKS;
    $segments_string =~ s/Flanks\: //g;
    $segments_string =~ s/\s+$//g;

    $self->{flanks} = $segments_string;
    $self->{'protein_tree'}->store_tag('Gblocks_flanks', $segments_string);
  }


sub store_sitewise_dNdS
{
  my $self = shift;

  printf("Sitewise_dNdS::store_sitewise_dNdS\n") if($self->debug);

  my $runtime = time()*1000-$self->{starttime};
  $self->{'protein_tree'}->store_tag('Sitewise_dNdS_runtime_msec', $runtime);

  my $results = $self->{'results'};
  my $aa_aln = $self->{'protein_tree'}->get_SimpleAlign;
  my @gap_col_matrix = @{$aa_aln->gap_col_matrix};
  $self->{memberDBA} = $self->{'comparaDBA'}->get_MemberAdaptor;
  my $root_id = $self->{'protein_tree'}->node_id;

  # We store a tag with the subroot_id so that we can do easy mapping
  # from subtree to root
  my $subroot_id = $self->{'protein_tree'}->subroot->node_id;
  $self->{'protein_tree'}->store_tag('Sitewise_dNdS_subroot_id', $subroot_id);
  my $threshold_on_branch_ds = $self->{'saturated'};

  my $sth;
  foreach my $type (keys %{$results->{sites}}) {
    # next if ($type =~ /all_gaps/);
    foreach my $position (@{$results->{sites}{$type}}) {
      # Site  Neutral  Optimal   Omega    lower    upper LRT_Stat    Pval     Adj.Pval    Q-value Result Note
      # 1     4.77     3.44   0.0000   0.0000   1.4655   2.6626 1.0273e-01 8.6803e-01 1.7835e-02        Constant;
      # 0     1        2      3        4        5        6      7          8          9
      my ($site, $neutral, $optimal, $omega, $lower, $upper, $lrt_stat, $pval, $adj_pval, $q_value) = @$position;
      my $nseq_ngaps = 0; foreach my $val (values %{$gap_col_matrix[$site-1]}) {$nseq_ngaps++ unless (1 == $val)};
      my $optimalc; if (0 != $nseq_ngaps) {$optimalc = $optimal / $nseq_ngaps;} else {$optimalc = $optimal;}
      $sth = $self->{'comparaDBA'}->dbc->prepare
        ("INSERT INTO sitewise_aln 
                           (aln_position,
                            node_id,
                            tree_node_id,
                            omega,
                            omega_lower,
                            omega_upper,
                            optimal,
                            ncod,
                            threshold_on_branch_ds,
                            type) VALUES (?,?,?,?,?,?,?,?,?,?)");
      $sth->execute($site,
                    $root_id,
                    $subroot_id,
                    $omega,
                    $lower,
                    $upper,
                    $optimalc,
                    $nseq_ngaps,
                    $threshold_on_branch_ds,
                    $type);
# This stuff is disabled right now
#       my $stored_id = $sth->{'mysql_insertid'};
#       if ($type !~ /default/) {
#         foreach my $seq ($aln->each_seq) {
#           next unless ($seq->display_id =~ /ENSP0/ || $seq->display_id =~ /ENSMUSP0/); # only store human and mouse
#           my $seq_location;
#           eval { $seq_location = $seq->location_from_column($site);};
#           if ($@) {
#             # gaps before the first nucleotide, skip
#             next;
#           }
#           my $location_type;
#           eval { $location_type = $seq_location->location_type;};
#           if ($@) {
#             # gaps before the first nucleotide, skip
#             next;
#           }
#           if ($seq_location->location_type eq 'EXACT') {
#             my $member = $self->{memberDBA}->fetch_by_source_stable_id("ENSEMBLPEP",$seq->display_id);
#             my $member_id = $member->dbID;
#             my $member_position = $seq_location->start;
#             my $aa = $seq->subseq($seq_location->start,$seq_location->end);
#             my $sth = $self->{'comparaDBA'}->dbc->prepare
#               ("INSERT INTO sitewise_member 
#                            (sitewise_id,
#                             member_id,
#                             member_position) VALUES (?,?,?)");
#             $sth->execute($stored_id,
#                           $member_id,
#                           $member_position);
#           }
#         }
#       }
    }
  }
  $sth->finish();

  return undef;
}

1;

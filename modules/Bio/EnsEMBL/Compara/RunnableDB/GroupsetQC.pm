#
# You may distribute this module under the same terms as perl itself
#
# POD documentation - main docs before the code

=pod 

=head1 NAME

Bio::EnsEMBL::Compara::RunnableDB::GroupsetQC

=cut

=head1 SYNOPSIS

my $db           = Bio::EnsEMBL::Compara::DBAdaptor->new($locator);
my $sillytemplate = Bio::EnsEMBL::Compara::RunnableDB::GroupsetQC->new
  (
   -db         => $db,
   -input_id   => $input_id,
   -analysis   => $analysis
  );
$sillytemplate->fetch_input(); #reads from DB
$sillytemplate->run();
$sillytemplate->output();
$sillytemplate->write_output(); #writes to DB

=cut


=head1 DESCRIPTION

This Analysis will take the sequences from a cluster, the cm from
nc_profile and run a profiled alignment, storing the results as
cigar_lines for each sequence.

=cut


=head1 CONTACT

  Contact Albert Vilella on module implementation/design detail: avilella@ebi.ac.uk
  Contact Ewan Birney on EnsEMBL in general: birney@sanger.ac.uk

=cut


=head1 APPENDIX

The rest of the documentation details each of the object methods. 
Internal methods are usually preceded with a _

=cut


package Bio::EnsEMBL::Compara::RunnableDB::GroupsetQC;

use strict;
use Getopt::Long;
use Time::HiRes qw(time gettimeofday tv_interval);

use Bio::EnsEMBL::Hive::URLFactory;               # reuse_db
use Bio::EnsEMBL::Hive;

use base ('Bio::EnsEMBL::Compara::RunnableDB::BaseRunnable');

sub strict_hash_format { # allow this Runnable to parse parameters in its own way (don't complain)
    return 0;
}

=head2 fetch_input

    Title   :   fetch_input
    Usage   :   $self->fetch_input
    Function:   Fetches input data from the database
    Returns :   none
    Args    :   none

=cut


sub fetch_input {
  my( $self) = @_;

  # $self->{'clusterset_id'} = 1;

  # Get the needed adaptors here
  $self->{proteintreeDBA} = $self->compara_dba->get_ProteinTreeAdaptor;
  $self->{memberDBA} = $self->compara_dba->get_MemberAdaptor;

  $self->get_params($self->parameters);
  $self->get_params($self->input_id);

  $self->{unmap_tolerance} = 0.2 unless(defined($self->{unmap_tolerance}));

# For long parameters, look at analysis_data
  if($self->{blast_template_analysis_data_id}) {
    my $analysis_data_id = $self->{blast_template_analysis_data_id};
    my $analysis_data_params = $self->db->get_AnalysisDataAdaptor->fetch_by_dbID($analysis_data_id);
    $self->get_params($analysis_data_params);
  }

  foreach my $reusable_gdb (@{$self->{reuse_gdb}}) {
    $self->{reusable_gdb}{$reusable_gdb} = 1;
  }

  $self->{groupset_node} = $self->{proteintreeDBA}->fetch_all_roots->[0];
  $self->throw("[GroupsetQC] Couldnt find clusterset node") unless (defined($self->{groupset_node}));

  unless (defined($self->{groupset_tag})) {
    $self->{groupset_tag} = $self->input_job->dbID;
  }

  return 1;
}


sub get_params {
  my $self         = shift;
  my $param_string = shift;

  return unless($param_string);
  print("parsing parameter string : ",$param_string,"\n") if($self->debug);

  my $params = eval($param_string);


  return if ($params eq '1');

  foreach my $key (qw[gdb reuse_db reuse_gdb groupset_tag cluster_dir unmap_tolerance blast_template_analysis_data_id]) {
    my $value = $params->{$key};
    $self->{$key} = $value if defined $value;
  }

  if($self->debug) {
    foreach my $key (keys %$params) {
      print("  $key : ", $params->{$key}, "\n");
    }
  }

  return;
}


=head2 run

    Title   :   run
    Usage   :   $self->run
    Function:   runs something
    Returns :   none
    Args    :   none

=cut

sub run {
  my $self = shift;

  $self->run_groupset_qc;
}


=head2 write_output

    Title   :   write_output
    Usage   :   $self->write_output
    Function:   stores something
    Returns :   none
    Args    :   none

=cut


sub write_output {
  my $self = shift;

}


##########################################
#
# internal methods
#
##########################################

sub run_groupset_qc {
  my $self = shift;

  if (defined($self->{gdb})) {
    $self->per_genome_mapping_stats($self->{gdb});
  } else {
    # Fetching the previous version of the pipeline
    $self->{'comparaDBA_reuse'} = Bio::EnsEMBL::Hive::URLFactory->fetch($self->{reuse_db} . ';type=compara');
    $self->throw("[GroupsetQC] Couldnt connect to comparaDBA reuse") unless (defined($self->{'comparaDBA_reuse'}));

    my $xtb_filename = $self->join_one_pair;

    my $xtb_copy_filename = $self->{cluster_dir} . "/" . "groupset_qc.xtb";
    my $cpcmd = "cp $xtb_filename $xtb_copy_filename";
    unless(system($cpcmd) == 0) {
      warn "failed to copy $xtb_filename to $xtb_copy_filename\n";
    }

    my $map_filename = $self->cluster_mapping($xtb_filename);

    my $map_copy_filename = $self->{cluster_dir} . "/" . "groupset_qc.map";
    $cpcmd = "cp $map_filename $map_copy_filename";
    unless(system($cpcmd) == 0) {
      warn "failed to copy $map_filename to $map_copy_filename\n";
    }

    $self->quantify_mapping($map_filename);
  }

  return 1;
}

sub fetch_groupset {
  my $self = shift;
  my $comparaDBA = shift;
  my $starttime = time();

  my $default_noname = 'NoName';
  my $dataset;

  my $sql = "SELECT ptm.root_id, m2.stable_id FROM protein_tree_member ptm, member m1, member m2 where ptm.member_id=m1.member_id and m1.gene_member_id=m2.member_id";

  my $sth = $comparaDBA->dbc->prepare($sql);
  $sth->execute();

  printf("%1.3f secs to fetch entries\n", (time()-$starttime)) if ($self->debug);

  my $counter = 0;

  while(my($cluster_id, $member)=$sth->fetchrow()) {
    # print STDERR "ID=$cluster_id NAME=$cluster_name MEM=$member\n" if ($self->debug);
    my $cluster_name;
    if (defined($cluster_id)) {
      $cluster_name = 'Node_' . $cluster_id;
    } else {
      $cluster_name = $default_noname; # we need some name here however bogus (for formatting purposes)
    }

    if ($member) {
      $dataset->{membership}{$member} = $cluster_id;
      $dataset->{clustername}{$cluster_id} = $cluster_name;
    } else {
      $self->throw("Missing member for $cluster_id\n");
    }

    if ($self->debug && ($counter++ % 50000 == 0)) { printf("%10d loaded\n", $counter); }
  }

  return $dataset;
}

sub join_one_pair {
  my $self = shift;

  my $reuse_dbname = 
    $self->{comparaDBA_reuse}->dbc->host . 
    "." . $self->{comparaDBA_reuse}->dbc->port . 
    "." . $self->{comparaDBA_reuse}->dbc->dbname;
  my $this_dbname = 
    $self->{comparaDBA}->dbc->host . 
    "." . $self->{comparaDBA}->dbc->port . 
    "." . $self->{comparaDBA}->dbc->dbname;

  print STDERR "Fetching groupset for $reuse_dbname\n" if ($self->debug);
  my $from_dataset = $self->fetch_groupset($self->{comparaDBA_reuse});
  my $from_membership = $from_dataset->{membership};
  my $from_clustername= $from_dataset->{clustername};

  print STDERR "Fetching groupset for $this_dbname\n" if ($self->debug);
  my $to_dataset   = $self->fetch_groupset($self->compara_dba);
  my $to_membership = $to_dataset->{membership};
  my $to_clustername= $to_dataset->{clustername};

  my %direct     = ();
  my %reverse    = ();
  my %from_size  = ();
  my %to_size    = ();
  my %xto_size   = ();
  my %xfrom_size = ();

  my $total_count  = 0;
  my $common_count = 0;

  while(my ($from_member, $from_family) = each %$from_membership) {
    if(my $to_family = $to_membership->{$from_member}) {
      $direct{$from_family}{$to_family}++;
      $reverse{$to_family}{$from_family}++;
      $from_size{$from_family}++;
      $to_size{$to_family}++;
      $common_count++;
    } else { # strictly disappeared members (disappearing either with or without the families)
      $xfrom_size{$from_family}++;
    }
    $total_count++;
  }
  while(my ($to_member, $to_family) = each %$to_membership) {
    if(not exists $from_membership->{$to_member}) { # strictly new members (going either into existing or new family)
      $xto_size{$to_family}++;
      $total_count++;
    }
  }

  print STDERR "Total number of keys:  $total_count\n" if ($self->debug);
  print STDERR "Number of common keys: $common_count\n" if ($self->debug);

  my $xtb_filename = $self->worker_temp_directory . $reuse_dbname . "-" . $this_dbname. '.xtb';
  open(OUT, ">$xtb_filename") or die "$!\n";
  foreach my $from_id (sort {$a <=> $b} keys %direct) {
    my $from_name = $from_clustername->{$from_id};
    my $subhash = $direct{$from_id};

    foreach my $to_id (sort { $subhash->{$b} <=> $subhash->{$a} } keys %$subhash) {
      my $to_name = $to_clustername->{$to_id};
      my $cnt = $direct{$from_id}{$to_id};

      print OUT join("\t", $from_id, $from_name, $from_size{$from_id}, $to_id, $to_name, $to_size{$to_id}, $cnt)."\n";
    }
  }

  foreach my $to_id (sort {$a <=> $b} keys %xto_size) { # iterate through families that contain new members
    next if($reverse{$to_id}); # skip the ones that also have old members (i.e. iterate only through strictly-new families)
    my $to_name = $to_clustername->{$to_id};

    print OUT join("\t", 0, '-', 0, $to_id, $to_name, $xto_size{$to_id}, $xto_size{$to_id})."\n";
  }
  foreach my $from_id (sort {$a <=> $b} keys %xfrom_size) { # iterate through families that lost some members
    next if($direct{$from_id}); # skip the families that retained some members (i.e. iterate only through strictly-disappearing families)
    my $from_name = $from_clustername->{$from_id};

    print OUT join("\t", $from_id, $from_name, $xfrom_size{$from_id}, 0, '-', 0, $xfrom_size{$from_id})."\n";
  }
  close OUT;

  return $xtb_filename;
}

sub cluster_mapping {
  my $self = shift;
  my $link_filename = shift;

  my $reuse_dbname = 
    $self->{comparaDBA_reuse}->dbc->host . 
    "." . $self->{comparaDBA_reuse}->dbc->port . 
    "." . $self->{comparaDBA_reuse}->dbc->dbname;
  my $this_dbname = 
    $self->{comparaDBA}->dbc->host . 
    "." . $self->{comparaDBA}->dbc->port . 
    "." . $self->{comparaDBA}->dbc->dbname;

  my $premap = ''; # premap will always be empty here
  my $threshold = 0.67;

  my $maj_label =  $threshold ? sprintf("Major_%d", int($threshold*100) ) : 'Majority';
  my @labels = ('Exact', 'Exact_o', $maj_label, $maj_label.'_o', 'NextBest', 'NextBest_o', 'NewName', 'NewName_o', 'NewFam', 'NewFam_o');

  my $default_version = 1;
  my $prefix = 'ENSGT';
  my $to_rel = 2;
  my $stid_counter = 0;

  my $revcontrib;
  my $from2size;
  my $to2size;
  my $xfrom2size;
  my $xto2size;
  my $from2name;
  my $to2name;

  open(LINKFILE, $link_filename) || die "Cannot open '$link_filename' file $@";
  while (my ($from_id, $from_name, $from_size, $to_id, $to_name, $to_size, $contrib) = split(/\s/,<LINKFILE>)) {

    next unless($contrib=~/^\d+$/); # skip the header line if present

    if($from_size and $to_size) { # Shared
      $from2name->{$from_id}          = $premap ? ($premap->{$from_id} || die "Premap does not contain mapping for '$from_name' (id=$from_id)") : $from_name;
      $to2name->{$to_id}              = $to_name;

      $revcontrib->{$to_id}{$from_id} = $contrib;
      $from2size->{$from_id}          = $from_size;
      $to2size->{$to_id}              = $to_size;
    } elsif($to_size) { # Newborn
      $to2name->{$to_id}              = $to_name;

      $xto2size->{$to_id}             = $to_size;
    } elsif($from_size) { # Disappearing
      $from2name->{$from_id}          = $premap ? ($premap->{$from_id} || die "Premap does not contain mapping for '$from_name' (id=$from_id)") : $from_name;

      $xfrom2size->{$from_id}         = $from_size;
    }
  }
  close LINKFILE;

  # Now we run through the hashes
  my %matchtype_counter = ();
  my %from_taken        = (); # indicates the 'from' name has been taken 
  my %postmap           = (); # the goal of this subroutine is to map between the '$to' and '$given_name'-s

  my $map_filename = $self->worker_temp_directory . $reuse_dbname . "-" . $this_dbname. '.map';
  open MAP, ">$map_filename" or die "$!\n";

 TOPAIR: foreach my $topair (sort { $b->[1] <=> $a->[1] } map { [$_,$to2size->{$_}] } keys %$to2size ) {
    my ($to_id, $to_size) = @$topair;

    my $subhash = $revcontrib->{$to_id};

    my $td_counts  = 0;
    my $matchtype  = '';
    my $matchscore = 0;
    my $given_name = ''; # serves both as logical flag and the actual name

  FROMPAIR: foreach my $frompair (sort { $b->[1] <=> $a->[1] } map { [$_,$subhash->{$_}] } keys %$subhash ) {
      my ($from_id, $contrib) = @$frompair;
      my $from_size = $from2size->{$from_id};

      my $from_name = $from2name->{$from_id};
      if (!defined $from_taken{$from_name}) { # means the '$from' name is still unused, so we can reuse it now

        if ($contrib==$from_size and $contrib==$to_size) {
          $matchtype  = 'Exact';
        } elsif ($threshold>0) { # either the majority rule is applicable or we don't bother looking at other possibilities (as they are even smaller)
          if ($contrib/$from_size>=$threshold and $contrib/$to_size>=$threshold) {
            $matchtype  = $maj_label;
          }             # otherwise we have an implicit 'NewName' case
        } else {                # non-threshold mode
          $matchtype = $td_counts ? 'NextBest' : $maj_label;
        }

        if ($matchtype) {
          if ($matchtype eq 'Exact') {
            # $from_name =~ /^(\w+)(?:\.(\d+))?/;
            # $given_name = $1.'.'. (defined($2) ? $2 : $default_version ); # same version (but we may want to make it more obvious)
            $given_name = $from_name;
          } else {
            $from_name =~ /^(\w+)(?:\.(\d+))?/;
            $given_name = $1.'.'. ((defined($2) ? $2 : $default_version)+1); # change the version if the match is not exact (or set it if previously unset)
          }
          $from_taken{$from_name} = 1;
          $matchscore = int(100*$contrib/$to_size);
        }
        last FROMPAIR;

      }                         # if name not taken

      $td_counts++; # counts all attempts, not only the ones where the '$from' name was unused

    }                           # FROMPAIR

    # the following two lines work either if we arrive here from 'last FROMPAIR' after implicit 'NewName'
    # or by exhausting all FROMPAIRS (beacause they were all taken)
    $matchtype  ||= 'NewName';
    $given_name ||= sprintf("%s%04d%010d.%d",$prefix, $to_rel, ++$stid_counter, $default_version);

    print MAP (join("\t", $to_id, $to2name->{$to_id}, $given_name, $matchscore)."\n");
    $postmap{$to_id} = $given_name;

    if ($to_size == 1) {
      $matchtype .= '_o';
    }
    $matchtype_counter{$matchtype}++;
  }                             # TOPAIR

  while (my ($to_id, $to_size) = each %$xto2size) {
    my $given_name = sprintf("%s%04d%010d.%d",$prefix, $to_rel, ++$stid_counter, $default_version);
    print MAP join("\t", $to_id, $to2name->{$to_id}, $given_name, 0)."\n";
    $postmap{$to_id} = $given_name;

    my $matchtype = ($to_size == 1) ? 'NewFam_o' : 'NewFam';
    $matchtype_counter{$matchtype}++;
  }
  close MAP;

  return $map_filename;
}

sub quantify_mapping {
  my $self = shift;
  my $map_filename = shift;

  open MAP, "$map_filename" or die "$!";
  my $tag_count = 0;
  while (<MAP>) {
    my ($cluster_id, $from_cluster_name, $to_cluster_name, $contribution) = split(" ",$_);
    if ($to_cluster_name =~ /ENSGT/) {
      $self->{mapping_stats}{novel}{$cluster_id} = 1;
    } else {
      $to_cluster_name =~ /\_(\d+)/;
      my $reuse_node_id = $1;
      $self->{mapping_stats}{mapped}{$cluster_id} = $contribution;
      $self->{mapping_stats}{mapped_tagging}{$cluster_id} = $reuse_node_id;
    }
    if ($self->debug && ($tag_count++ % 100 == 0)) { print STDERR "[$tag_count] mapped clusters\n"; }
  }
  close MAP;

  $self->{treeDBA_reuse} = $self->{comparaDBA_reuse}->get_ProteinTreeAdaptor;
  foreach my $mapped_cluster_id (keys %{$self->{mapping_stats}{mapped_tagging}}) {
    my $reuse_node_id = $self->{mapping_stats}{mapped_tagging}{$mapped_cluster_id};
    next unless (defined($reuse_node_id));
    my $reuse_node = $self->{treeDBA_reuse}->fetch_node_by_node_id($reuse_node_id);
    next unless (defined($reuse_node));
    my $reuse_aln_runtime_value = $reuse_node->get_tagvalue('aln_runtime');
    $reuse_node->release_tree;
    next if ($reuse_aln_runtime_value eq '');
    my $this_node = $self->{proteintreeDBA}->fetch_node_by_node_id($mapped_cluster_id);
    next unless (defined($this_node));
    $this_node->store_tag('reuse_node_id',$reuse_node_id);
    $this_node->store_tag('reuse_aln_runtime',$reuse_aln_runtime_value);
    my $contribution = $self->{mapping_stats}{mapped}{$mapped_cluster_id};
    next unless (defined($contribution));
    $this_node->store_tag('reuse_contribution',$contribution);
    $this_node->release_tree;
  }


  my $num_novel_clusters = scalar keys %{$self->{mapping_stats}{novel}};
  my $num_mapped_clusters = scalar keys %{$self->{mapping_stats}{mapped}};

  my $sum_contrib;
  foreach my $mapped_cluster_id (keys %{$self->{mapping_stats}{mapped}}) {
    $sum_contrib += $self->{mapping_stats}{mapped}{$mapped_cluster_id};
  }
  my $average_mapped_contribution = $sum_contrib / $num_mapped_clusters;

  my $proportion_novel_clusters = $num_novel_clusters/($num_novel_clusters+$num_mapped_clusters);

  print STDERR "# Proportion novel clusters = $proportion_novel_clusters [$num_novel_clusters $num_mapped_clusters]\n";
  print STDERR "# Average contribution mapped clusters = $average_mapped_contribution\n";

  $self->{groupset_node}->store_tag('sid_map_novel_cls' . '_' . $self->{groupset_tag},$num_novel_clusters);
  $self->{groupset_node}->store_tag('sid_map_mapped_cls' . '_' . $self->{groupset_tag},$num_mapped_clusters);
  $self->{groupset_node}->store_tag('sid_map_summary_contrib' . '_' . $self->{groupset_tag},$sum_contrib);
  $self->{groupset_node}->store_tag('sid_map_average_contrib' . '_' . $self->{groupset_tag},$average_mapped_contribution);
  $self->{groupset_node}->store_tag('sid_prop_novel_cls' . '_' . $self->{groupset_tag},$proportion_novel_clusters);

  my $unmap_tolerance = $self->{unmap_tolerance};
  print STDERR "# Unmap tolerance parameter set to $unmap_tolerance\n";
  if ($proportion_novel_clusters > $unmap_tolerance) {
    $self->input_job->transient_error(0);
    die "Quality Check FAILED: Proportion of novel clusters $proportion_novel_clusters > $unmap_tolerance\n";
  }

  return;
}

sub per_genome_mapping_stats {
  my $self = shift;

  my $gdb_id = shift;

  print STDERR "per_genome_mapping_stats\n" if ($self->debug);

  my $this_orphans  = $self->fetch_gdb_orphan_genes($self->compara_dba,$gdb_id);
  my $total_orphans_num   = scalar keys (%$this_orphans);
  $self->{groupset_node}->store_tag("$gdb_id".'_total_orphans_num' . '_' . $self->{groupset_tag},$total_orphans_num);
  my $total_num_genes = scalar @{$self->{memberDBA}->fetch_all_by_source_genome_db_id('ENSEMBLGENE',$gdb_id)};
  my $proportion_orphan_genes = $total_orphans_num/$total_num_genes;
  $self->{groupset_node}->store_tag("$gdb_id".'_prop_orphans' . '_' . $self->{groupset_tag},$proportion_orphan_genes);
  return 1 unless (defined($self->{reusable_gdb}{$gdb_id}));

  $self->{'comparaDBA_reuse'} = Bio::EnsEMBL::Hive::URLFactory->fetch($self->{reuse_db} . ';type=compara');
  $self->throw("[GroupsetQC] Couldnt connect to comparaDBA reuse") unless (defined($self->{'comparaDBA_reuse'}));
  my $reuse_orphans = $self->fetch_gdb_orphan_genes($self->{comparaDBA_reuse},$gdb_id);
  my $common_orphans; my $new_orphans; my $old_orphans;
  foreach my $this_orphan_id (keys %$this_orphans) {
    $common_orphans->{$this_orphan_id} = 1  if ($reuse_orphans->{$this_orphan_id});
    $new_orphans->{$this_orphan_id} = 1 unless ($reuse_orphans->{$this_orphan_id});
  }
  my $common_orphans_num = scalar keys (%$common_orphans);
  my $new_orphans_num    = scalar keys (%$new_orphans);


  $self->{groupset_node}->store_tag("$gdb_id".'_common_orphans_num' . '_' . $self->{groupset_tag}, $common_orphans_num);
  $self->{groupset_node}->store_tag("$gdb_id".'_new_orphans_num' . '_' . $self->{groupset_tag}, $new_orphans_num);

  return 1;
}

sub fetch_gdb_orphan_genes {
  my $self = shift;

  my $comparaDBA = shift;
  my $gdb_id = shift;
  my $starttime = time();

  my $dbname = 
    $comparaDBA->dbc->host . 
    "." . $comparaDBA->dbc->port . 
    "." . $comparaDBA->dbc->dbname;

  my $dataset;

  print STDERR "fetching orphan genes [$dbname $gdb_id]\n" if ($self->debug);
  my $sql = "SELECT m3.stable_id from member m2, member m3, subset_member sm where m3.member_id=m2.gene_member_id and m2.source_name='ENSEMBLPEP' and sm.member_id=m2.member_id and sm.member_id in (SELECT m1.member_id from member m1 left join protein_tree_member ptm on m1.member_id=ptm.member_id where ptm.member_id IS NULL and m1.genome_db_id=$gdb_id)";

  my $sth = $comparaDBA->dbc->prepare($sql);
  $sth->execute();

  printf("%1.3f secs to fetch orphan genes [$dbname $gdb_id]\n", (time()-$starttime)) if ($self->debug);

  my $counter = 0;

  while(my ($member) = $sth->fetchrow()) {
    # print STDERR "ID=$cluster_id NAME=$cluster_name MEM=$member\n" if ($self->debug);
    $dataset->{$member} = 1;
    if ($self->debug && ($counter++ % 100 == 0)) { printf("%10d orphan genes [$gdb_id]\n", $counter); }
  }

  return $dataset;
}

1;

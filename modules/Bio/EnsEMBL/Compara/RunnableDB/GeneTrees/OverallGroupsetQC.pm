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


=head1 CONTACT

  Please email comments or questions to the public Ensembl
  developers list at <http://lists.ensembl.org/mailman/listinfo/dev>.

  Questions may also be sent to the Ensembl help desk at
  <http://www.ensembl.org/Help/Contact>.

=head1 NAME

Bio::EnsEMBL::Compara::RunnableDB::GeneTrees::OverallGroupsetQC

=head1 DESCRIPTION

This RunnableDB compares the clusters of this compara database to another one's

=head1 AUTHORSHIP

Ensembl Team. Individual contributions can be found in the GIT log.

=head1 APPENDIX

The rest of the documentation details each of the object methods.
Internal methods are usually preceded with an underscore (_)

=cut

package Bio::EnsEMBL::Compara::RunnableDB::GeneTrees::OverallGroupsetQC;

use strict;
use warnings;

use Time::HiRes qw(time gettimeofday tv_interval);

use base ('Bio::EnsEMBL::Compara::RunnableDB::BaseRunnable');


sub param_defaults {
    return {
        'unmap_tolerance'       => 0.2,
    };
}


=head2 fetch_input

    Title   :   fetch_input
    Usage   :   $self->fetch_input
    Function:   Fetches input data from the database
    Returns :   none
    Args    :   none

=cut

sub fetch_input {
    my $self = shift @_;

    $self->complete_early('No reuse_db, cannot compare the clusters') unless $self->param('reuse_db');
    $self->param('groupset_tree', $self->compara_dba->get_GeneTreeAdaptor->fetch_all(-tree_type => 'clusterset', -clusterset_id => 'default')->[0]) or die "Could not fetch groupset tree";

}


=head2 run

    Title   :   run
    Usage   :   $self->run
    Function:   runs something
    Returns :   none
    Args    :   none

=cut

sub run {
    my $self = shift @_;

    $self->overall_groupset_qc();
}



##########################################
#
# internal methods
#
##########################################

sub generate_dbname {
    my ($self, $given_compara_dba) = @_;

    return join('.',
        $given_compara_dba->dbc->host,
        $given_compara_dba->dbc->port,
        $given_compara_dba->dbc->dbname
    );
}


sub overall_groupset_qc {
    my $self     = shift @_;

    my $reuse_compara_dba = $self->get_cached_compara_dba('reuse_db');    # may die if bad parameters

    my $xtb_filename = $self->join_one_pair( $reuse_compara_dba, $self->compara_dba );

    my $xtb_copy_filename = $self->param('cluster_dir') . "/" . "groupset_qc.xtb";
    my $cpcmd = ['cp', $xtb_filename, $xtb_copy_filename];
    $self->run_command($cpcmd, { die_on_failure => 1 });

    my $map_filename = $self->cluster_mapping($xtb_filename, $reuse_compara_dba, $self->compara_dba);

    my $map_copy_filename = $self->param('cluster_dir') . "/" . "groupset_qc.map";
    $cpcmd = ['cp', $map_filename, $map_copy_filename];
    $self->run_command($cpcmd, { die_on_failure => 1 });

    $self->quantify_mapping($map_filename, $reuse_compara_dba);
}



# ---------------------------------------------------------------------------------------------------------------
#       The following 3 subroutines have been re-written using proper classes in Bio::EnsEMBL::Compara::StableId,
#       We should be using those instead of copy-pasting.
#       Also see Bio::EnsEMBL::Compara::RunnableDB::StableIdMapper on proper manupulating those objects.
# ---------------------------------------------------------------------------------------------------------------


sub fetch_groupset {        # see Bio::EnsEMBL::Compara::StableId::Adaptor::load_compara_ncs
  my $self = shift;
  my $given_compara_dba = shift;

  my $starttime = time();

  my $default_noname = 'NoName';
  my $dataset;

  my $sql = "SELECT gtn.root_id, m2.stable_id FROM gene_tree_node gtn JOIN seq_member m1 USING (seq_member_id) JOIN gene_member m2 USING (gene_member_id)";

  my $sth = $given_compara_dba->dbc->prepare($sql);
  $sth->execute();

  printf("%1.3f secs to fetch entries\n", (time()-$starttime)) if ($self->debug);

  my $counter = 0;

  while(my($cluster_id, $member_stable_id)=$sth->fetchrow()) {
    # print STDERR "ID=$cluster_id NAME=$cluster_name MEM=$member_stable_id\n" if ($self->debug);
    my $cluster_name;
    if (defined($cluster_id)) {
      $cluster_name = 'Node_' . $cluster_id;
    } else {
      $cluster_name = $default_noname; # we need some name here however bogus (for formatting purposes)
    }

    if ($member_stable_id) {
      $dataset->{membership}{$member_stable_id} = $cluster_id;
      $dataset->{clustername}{$cluster_id} = $cluster_name;
    } else {
      $self->throw("Missing stable_id for $cluster_id\n");
    }

    if ($self->debug && ($counter++ % 50000 == 0)) { printf("%10d loaded\n", $counter); }
  }

  return $dataset;
}


sub join_one_pair {         # see Bio::EnsEMBL::Compara::StableId::NamedClusterSetLink::compute_stats
  my ($self, $from_dba, $to_dba) = @_;

  my $from_dbname       = $self->generate_dbname( $from_dba );
  print STDERR "Fetching groupset for $from_dbname\n" if ($self->debug);
  my $from_dataset      = $self->fetch_groupset( $from_dba );
  my $from_membership   = $from_dataset->{membership};
  my $from_clustername  = $from_dataset->{clustername};

  my $to_dbname     = $self->generate_dbname( $to_dba );
  print STDERR "Fetching groupset for $to_dbname\n" if ($self->debug);
  my $to_dataset    = $self->fetch_groupset( $to_dba );
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

  my $xtb_filename = $self->worker_temp_directory . "/" . $from_dbname . "-" . $to_dbname. '.xtb';
  open(OUT, ">$xtb_filename") or die "Could not open '$xtb_filename' for writing : $!";
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


sub cluster_mapping {       # see Bio::EnsEMBL::Compara::StableId::NamedClusterSetLink::maximum_name_reuse
  my ($self, $link_filename, $from_dba, $to_dba) = @_;

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

  my $from_dbname   = $self->generate_dbname( $from_dba );
  my $to_dbname     = $self->generate_dbname( $to_dba );

  my $map_filename = $self->worker_temp_directory . "/" . $from_dbname . "-" . $to_dbname. '.map';
  open(MAP, ">$map_filename") or die "Could not open '$map_filename' for writing : $!";

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
  my ($self, $map_filename, $reuse_compara_dba) = @_;

  my %mapping_stats = ();

  open(MAP, "$map_filename") or die "Could not open '$map_filename' for reading : $!";
  my $tag_count = 0;
  while (<MAP>) {
    my ($cluster_id, $from_cluster_name, $to_cluster_name, $contribution) = split(" ",$_);
    if ($to_cluster_name =~ /ENSGT/) {
      $mapping_stats{novel}{$cluster_id} = 1;
    } else {
      $to_cluster_name =~ /\_(\d+)/;
      my $reuse_node_id = $1;
      $mapping_stats{mapped}{$cluster_id} = $contribution;
      $mapping_stats{mapped_tagging}{$cluster_id} = $reuse_node_id;
    }
    if ($self->debug && ($tag_count++ % 100 == 0)) { print STDERR "[$tag_count] mapped clusters\n"; }
  }
  close MAP;

  my $current_gene_tree_adaptor = $self->compara_dba->get_GeneTreeAdaptor;
  my $reuse_gene_tree_adaptor = $reuse_compara_dba->get_GeneTreeAdaptor;
  foreach my $mapped_cluster_id (keys %{$mapping_stats{mapped_tagging}}) {
    my $reuse_node_id = $mapping_stats{mapped_tagging}{$mapped_cluster_id};
    next unless (defined($reuse_node_id));
    my $reuse_node = $reuse_gene_tree_adaptor->fetch_by_dbID($reuse_node_id);
    next unless (defined($reuse_node));
    next unless $reuse_node->has_tag('aln_runtime');
    my $reuse_aln_runtime_value = $reuse_node->get_all_values_for_tag('aln_runtime')->[0];  # FIXME it seems that there are multiple occurrences of the tag for some trees, so we can't use get_value_for_tag
    my $this_node = $current_gene_tree_adaptor->fetch_by_dbID($mapped_cluster_id);
    next unless (defined($this_node));
    $this_node->store_tag('reuse_node_id',$reuse_node_id);
    $this_node->store_tag('reuse_aln_runtime',$reuse_aln_runtime_value);
    my $contribution = $mapping_stats{mapped}{$mapped_cluster_id};
    next unless (defined($contribution));
    $this_node->store_tag('reuse_contribution',$contribution);
  }

  my $num_novel_clusters = scalar keys %{$mapping_stats{novel}};
  my $num_mapped_clusters = scalar keys %{$mapping_stats{mapped}};

  my $sum_contrib;
  foreach my $mapped_cluster_id (keys %{$mapping_stats{mapped}}) {
    $sum_contrib += $mapping_stats{mapped}{$mapped_cluster_id};
  }
  if ($num_mapped_clusters == 0) {
    $self->warning('No mapped clusters');
    return;
  }

  my $average_mapped_contribution = $sum_contrib / $num_mapped_clusters;

  my $proportion_novel_clusters = $num_novel_clusters/($num_novel_clusters+$num_mapped_clusters);

  print STDERR "# Proportion novel clusters = $proportion_novel_clusters [$num_novel_clusters $num_mapped_clusters]\n";
  print STDERR "# Average contribution mapped clusters = $average_mapped_contribution\n";

  my $groupset_tree = $self->param('groupset_tree');

  $groupset_tree->store_tag('sid_map_novel_cls', $num_novel_clusters);
  $groupset_tree->store_tag('sid_map_mapped_cls', $num_mapped_clusters);
  $groupset_tree->store_tag('sid_map_summary_contrib', $sum_contrib);
  $groupset_tree->store_tag('sid_map_average_contrib', $average_mapped_contribution);
  $groupset_tree->store_tag('sid_prop_novel_cls', $proportion_novel_clusters);

  my $unmap_tolerance = $self->param('unmap_tolerance');
  print STDERR "# Unmap tolerance parameter set to $unmap_tolerance\n";
  if ($proportion_novel_clusters > $unmap_tolerance) {
    $self->input_job->transient_error(0);
    die "Quality Check FAILED: Proportion of novel clusters $proportion_novel_clusters > $unmap_tolerance\n";
  }

  return;
}


1;

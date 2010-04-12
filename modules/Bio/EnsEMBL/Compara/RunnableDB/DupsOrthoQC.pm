#
# You may distribute this module under the same terms as perl itself
#
# POD documentation - main docs before the code

=pod 

=head1 NAME

Bio::EnsEMBL::Compara::RunnableDB::DupsOrthoQC

=cut

=head1 SYNOPSIS

my $db           = Bio::EnsEMBL::Compara::DBAdaptor->new($locator);
my $dupsorthoqc = Bio::EnsEMBL::Compara::RunnableDB::DupsOrthoQC->new
  (
   -db         => $db,
   -input_id   => $input_id,
   -analysis   => $analysis
  );
$dupsorthoqc->fetch_input(); #reads from DB
$dupsorthoqc->run();
$dupsorthoqc->output();
$dupsorthoqc->write_output(); #writes to DB

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


package Bio::EnsEMBL::Compara::RunnableDB::DupsOrthoQC;

use strict;
use Getopt::Long;
use Time::HiRes qw(time gettimeofday tv_interval);

use Bio::EnsEMBL::Compara::DBSQL::DBAdaptor;
use Bio::EnsEMBL::Hive;
our @ISA = qw(Bio::EnsEMBL::Hive::Process);


=head2 fetch_input

    Title   :   fetch_input
    Usage   :   $self->fetch_input
    Function:   Fetches input data from the database
    Returns :   none
    Args    :   none

=cut


sub fetch_input {
  my( $self) = @_;

  $self->{'clusterset_id'} = 1;

  #create a Compara::DBAdaptor which shares the same DBI handle
  #with the Pipeline::DBAdaptor that is based into this runnable
  $self->{'comparaDBA'} = Bio::EnsEMBL::Compara::DBSQL::DBAdaptor->new
    (
     -DBCONN=>$self->db->dbc
    );

  # Get the needed adaptors here
  $self->{treeDBA}  = $self->{'comparaDBA'}->get_ProteinTreeAdaptor;
  $self->{streeDBA} = $self->{'comparaDBA'}->get_SuperProteinTreeAdaptor;

  $self->get_params($self->parameters);
  $self->get_params($self->input_id);

# # For long parameters, look at analysis_data
#   if($self->{analysis_data_id}) {
#     my $analysis_data_id = $self->{analysis_data_id};
#     my $analysis_data_params = $self->db->get_AnalysisDataAdaptor->fetch_by_dbID($analysis_data_id);
#     $self->get_params($analysis_data_params);
#   }

  return 1;
}


sub get_params {
  my $self         = shift;
  my $param_string = shift;

  return unless($param_string);
  print("parsing parameter string : ",$param_string,"\n") if($self->debug);

  my $params = eval($param_string);
  return unless($params);

  if($self->debug) {
    foreach my $key (keys %$params) {
      print("  $key : ", $params->{$key}, "\n");
    }
  }

  foreach my $key (qw[mlss type param1 param2 param3 analysis_data_id]) {
    my $value = $params->{$key};
    $self->{$key} = $value if defined $value;
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

  my $sql = "select h.tree_node_id, h.homology_id, hm1.member_id,hm2.member_id,h.method_link_species_set_id from homology_member hm1, homology_member hm2, homology h where h.homology_id=hm1.homology_id and hm1.homology_id=hm2.homology_id and h.method_link_species_set_id=?";
  $self->run_dupsorthoqc($sql);
  my $sql = "select h.tree_node_id, h.method_link_species_set_id,hm.member_id from homology h, homology_member hm where h.method_link_species_set_id=? and h.homology_id=hm.homology_id group by hm.member_id having count(*)>1 and group_concat(h.description) ='ortholog_one2one'";
  $self->run_dupsorthologyqc($sql);
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

sub run_dupsorthoqc {
  my $self = shift;
  my $sql  = shift;

  # This is a bit silly, but the mysql server behaves much better if
  # the queries have a little offset
  my $secs = int(rand(10)); `sleep $secs`;

  my $sth = $self->{comparaDBA}->dbc->prepare($sql);
  $sth->execute($self->{mlss});
  my $same_tree_duplicates;
  my $diff_tree_duplicates;
  while (my $aref = $sth->fetchrow_arrayref) {
    my ($tree_node_id, $homology_id, $member_id1, $member_id2,$mlss_id) = @$aref;
    next if ($member_id1 == $member_id2);
    my $tmp; if ($member_id1>$member_id2) 
      {$tmp = $member_id1; $member_id1 = $member_id2; $member_id2 = $tmp;}

    my $member_pair = $member_id1 . "_" . $member_id2;
    if (defined ($self->{$member_pair}{$mlss_id})) {
      # There is a duplicate
      if (defined($self->{$member_pair}{$mlss_id}{$tree_node_id})) {
        # (a) is it in the same tree?
        if ($homology_id == $self->{$member_pair}{$mlss_id}{$tree_node_id}) {
          next;
        } else {
          # There is a duplicate
          $DB::single=1;1;
        }
        $same_tree_duplicates->{$tree_node_id} = $member_pair;
      } else {
        $diff_tree_duplicates->{$tree_node_id} = $member_pair;
      }
    }
    $self->{$member_pair}{$mlss_id}{$tree_node_id} = $homology_id;
  }
  if (defined($same_tree_duplicates)) {
    $DB::single=1;1;
    $self->store_duportho_tags($same_tree_duplicates);
  }
  if (defined($diff_tree_duplicates)) {
    $DB::single=1;1;
    $self->store_duportho_tags($diff_tree_duplicates);
  }

  $sth->finish;

  return 1;
}

# This is the fast query, where we do the grouping on the Perl side
# and the mysql server only gives the full-blown table
sub store_duportho_tags {
  my $self = shift;
  my $hash = shift;

  my $mlss_id = $self->{mlss};
  foreach my $tree_node_id (keys %{$hash}) {
    my $member_pair = $hash->{$tree_node_id};
    print STDERR "ERROR: some homology duplicates in method_link_species_set_id=$mlss_id , [$member_pair]\n";
    my $tree = $self->{treeDBA}->fetch_node_by_node_id($tree_node_id);
    if (defined($tree)) {
      my $tag = $self->{mlss}.":".'DupsOrthoQC';
      my $value= $member_pair;
      $tree->store_tag($tag,$value);
    } else {
      my $supertree = $self->{streeDBA}->fetch_node_by_node_id($tree_node_id);
      if (defined($supertree)) {
        my $tag = $self->{mlss}.":".'DupsOrthoQC';
        my $value= $member_pair;
        $supertree->store_tag($tag,$value);
      }
    }
  }
  return 1;
}

# This is the long query, where we don't do anything clever on the
# Perl side and it's the mysql server that does all the work
sub run_dupsorthologyqc {
  my $self = shift;
  my $sql  = shift;

  # This is almost silly, but the mysql server behaves much better if
  # the queries have a certain offset
  my $secs = int(rand(10));
  `sleep $secs`;

  my $sth = $self->{comparaDBA}->dbc->prepare($sql);
  $sth->execute($self->{mlss});
  while (my $aref = $sth->fetchrow_arrayref) {
    my ($tree_node_id, $member_id1, $member_id2,$mlss_id) = @$aref;
    print STDERR "ERROR: some homology duplicates in method_link_species_set_id=$mlss_id tree_node_id=$tree_node_id [$member_id1 $member_id2]\n";
    my $tree = $self->{treeDBA}->fetch_node_by_node_id($tree_node_id);
    if (defined($tree)) {
      my $tag = $self->{mlss}.":".'DupsOrthoQC';
      my $value= $member_id1."_".$member_id2;
      $tree->store_tag($tag,$value);
    } else {
      my $supertree = $self->{streeDBA}->fetch_node_by_node_id($tree_node_id);
      if (defined($supertree)) {
        my $tag = $self->{mlss}.":".'DupsOrthoQC';
        my $value= $member_id1."_".$member_id2;
        $supertree->store_tag($tag,$value);
      }
    }
  }
  $sth->finish;

  return 1;
}

1;

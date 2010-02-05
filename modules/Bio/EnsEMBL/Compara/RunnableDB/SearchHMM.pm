#
# You may distribute this module under the same terms as perl itself
#
# POD documentation - main docs before the code

=pod 

=head1 NAME

Bio::EnsEMBL::Compara::RunnableDB::SearchHMM

=cut

=head1 SYNOPSIS

my $db           = Bio::EnsEMBL::Compara::DBAdaptor->new($locator);
my $search_hmm = Bio::EnsEMBL::Compara::RunnableDB::SearchHMM->new
  (
   -db         => $db,
   -input_id   => $input_id,
   -analysis   => $analysis
  );
$search_hmm->fetch_input(); #reads from DB
$search_hmm->run();
$search_hmm->output();
$search_hmm->write_output(); #writes to DB

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


package Bio::EnsEMBL::Compara::RunnableDB::SearchHMM;

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
  $self->{max_evalue} = 0.05;

  #create a Compara::DBAdaptor which shares the same DBI handle
  #with the Pipeline::DBAdaptor that is based into this runnable
  $self->{'comparaDBA'} = Bio::EnsEMBL::Compara::DBSQL::DBAdaptor->new
    (
     -DBCONN=>$self->db->dbc
    );

  # Get the needed adaptors here
  $self->{treeDBA} = $self->{'comparaDBA'}->get_ProteinTreeAdaptor;

  $self->get_params($self->parameters);
  $self->get_params($self->input_id);

# # For long parameters, look at analysis_data
#   if($self->{analysis_data_id}) {
#     my $analysis_data_id = $self->{analysis_data_id};
#     my $analysis_data_params = $self->db->get_AnalysisDataAdaptor->fetch_by_dbID($analysis_data_id);
#     $self->get_params($analysis_data_params);
#   }

  if(defined($self->{protein_tree_id})) {
    $self->{tree} = 
         $self->{treeDBA}->fetch_node_by_node_id($self->{protein_tree_id});
    printf("  protein_tree_id : %d\n", $self->{protein_tree_id}) if ($self->debug);
  }

  # Fetch hmm_profile
  $self->fetch_hmmprofile;

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

  foreach my $key (qw[qtaxon_id protein_tree_id type cdna fastafile analysis_data_id]) {
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

  $self->run_search_hmm;
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

  $self->search_hmm_store_hits;
}


##########################################
#
# internal methods
#
##########################################


sub fetch_hmmprofile {
  my $self = shift;

  my $hmm_type = $self->{type} || 'aa';
  my $node_id = $self->{tree}->node_id;
  print STDERR "type = $hmm_type\n" if ($self->debug);

  my $query = "SELECT hmmprofile FROM protein_tree_hmmprofile WHERE type=\"$hmm_type\" AND node_id=$node_id";
  print STDERR "$query\n" if ($self->debug);
  my $sth = $self->{comparaDBA}->dbc->prepare($query);
  $sth->execute;
  my $result = $sth->fetchrow_hashref;
  $self->{hmmprofile} = $result->{hmmprofile} if (defined($result->{hmmprofile}));
  $sth->finish;

  return 1;
}

sub run_search_hmm {
  my $self = shift;

  my $node_id = $self->{tree}->node_id;
  my $type = $self->{type};
  my $hmmprofile = $self->{hmmprofile};
  my $fastafile = $self->{fastafile};

  my $tempfilename = $self->worker_temp_directory . $node_id . "." . $type . ".hmm";
  open FILE, ">$tempfilename" or die "$!";
  print FILE $hmmprofile;
  close FILE;
  delete $self->{hmmprofile};

  my $search_hmm_executable = $self->analysis->program_file;
  unless (-e $search_hmm_executable) {
    $search_hmm_executable = "/nfs/acari/avilella/src/hmmer3/latest/hmmer-3.0b3/src/hmmsearch";
  }

  my $fh;
  eval { open($fh, "$search_hmm_executable $tempfilename $fastafile |") || die $!; };
  if ($@) {
    warn("problem with search_hmm $@ $!");
    return;
  }

  $self->{'comparaDBA'}->dbc->disconnect_when_inactive(1);
  my $starttime = time();

  while (<$fh>) {
    if (/^Scores for complete sequences/) {
      $_ = <$fh>;
      <$fh>;
      <$fh>; # /------- ------ -----    ------- ------ -----   ---- --  --------       -----------/
      while (<$fh>) {
        last if (/no hits above thresholds/);
        last if (/^\s*$/);
        $_ =~ /\s+(\S+)\s+(\S+)\s+\S+\s+\S+\s+\S+\s+\S+\s+\S+\s+\S+\s+(\S+)/;
        my $evalue = $1;
        my $score = $2;
        my $id = $3;
        $score =~ /^\s*(\S+)/;
        $self->{hits}{$id}{Score} = $1;
        $evalue =~ /^\s*(\S+)/;
        $self->{hits}{$id}{Evalue} = $1;
      }
      last;
    }
  }
  close($fh);
  $self->{'comparaDBA'}->dbc->disconnect_when_inactive(0);
  print STDERR scalar (keys %{$self->{hits}}), " hits - ",(time()-$starttime)," secs...\n";

  return 1;
}

sub search_hmm_store_hits {
  my $self = shift;
  my $type = $self->{type};
  my $node_id = $self->{tree}->node_id;
  my $qtaxon_id = $self->{qtaxon_id} || 0;

  my $sth = $self->{comparaDBA}->dbc->prepare
    ("INSERT INTO hmmsearch
       (stable_id,
        node_id,
        evalue,
        score,
        type,
        qtaxon_id) VALUES (?,?,?,?,?,?)");

  my $evalue_count = 0;
  foreach my $stable_id (keys %{$self->{hits}}) {
    my $evalue = $self->{hits}{$stable_id}{Evalue};
    my $score = $self->{hits}{$stable_id}{Score};
    next unless (defined($stable_id) && $stable_id ne '');
    next unless (defined($score));
    next unless ($evalue < $self->{max_evalue});
    $evalue_count++;
    $sth->execute($stable_id,
                  $node_id,
                  $evalue,
                  $score,
                  $type,
                  $qtaxon_id);
  }
  $sth->finish();
  printf("%10d hits stored\n", $evalue_count) if(($evalue_count % 10 == 0) && 0 < $self->debug);
  return 1;
}

1;

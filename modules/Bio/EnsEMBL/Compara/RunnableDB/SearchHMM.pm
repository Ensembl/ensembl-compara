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
$search_hmm->write_output(); #writes to DB

=cut


=head1 DESCRIPTION

This Analysis will take the sequences from a cluster, the cm from
nc_profile and run a profiled alignment, storing the results as
cigar_lines for each sequence.

=cut


=head1 CONTACT

Please email comments or questions to the public Ensembl
developers list at <http://lists.ensembl.org/mailman/listinfo/dev>.

Questions may also be sent to the Ensembl help desk at
<http://www.ensembl.org/Help/Contact>.

=cut


=head1 APPENDIX

The rest of the documentation details each of the object methods. 
Internal methods are usually preceded with a _

=cut


package Bio::EnsEMBL::Compara::RunnableDB::SearchHMM;

use strict;
use Time::HiRes qw(time gettimeofday tv_interval);

use base('Bio::EnsEMBL::Compara::RunnableDB::BaseRunnable');

sub param_defaults {
    return {
            # we should not really point at personal directories... but let's temporarily keep it as is:
        'search_hmm_executable' => '/software/ensembl/compara/hmmer-3.0/binaries/hmmsearch',
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
  my( $self) = @_;

  $self->param('max_evalue', 0.05);

  if(defined($self->param('gene_tree_id'))) {
    $self->param('tree', $self->compara_dba->get_GeneTreeAdaptor->fetch_by_dbID($self->param('gene_tree_id')));
    printf("  gene_tree_id : %d\n", $self->param('gene_tree_id')) if ($self->debug);
  }

  # Fetch hmm_profile
  $self->fetch_hmmprofile;

  return 1;
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

  my $hmm_type = $self->param('type') || 'aa';
  print STDERR "type = $hmm_type\n" if ($self->debug);

  $self->param('hmmprofile', $self->param('tree')->get_value_for_tag("hmm_$hmm_type") );

  return 1;
}

sub run_search_hmm {
  my $self = shift;

  my $node_id = $self->param('tree')->root_id;
  my $type = $self->param('type');
  my $hmmprofile = $self->param('hmmprofile');
  my $fastafile = $self->param('fastafile');

  my $tempfilename = $self->worker_temp_directory . $node_id . "." . $type . ".hmm";
  open FILE, ">$tempfilename" or die "$!";
  print FILE $hmmprofile;
  close FILE;
  $self->param('hmmprofile', undef);

  my $search_hmm_executable = $self->param('search_hmm_executable');

  my $fh;
  eval { open($fh, "$search_hmm_executable $tempfilename $fastafile |") || die $!; };
  if ($@) {
    warn("problem with search_hmm $@ $!");
    return;
  }

  $self->compara_dba->dbc->disconnect_when_inactive(1);
  my $starttime = time();

  my $hits = $self->param('hits', {});

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
        $hits->{$id}{Score} = $1;
        $evalue =~ /^\s*(\S+)/;
        $hits->{$id}{Evalue} = $1;
      }
      last;
    }
  }
  close($fh);
  $self->compara_dba->dbc->disconnect_when_inactive(0);
  print STDERR scalar (keys %$hits), " hits - ",(time()-$starttime)," secs...\n";

  return 1;
}

sub search_hmm_store_hits {
  my $self = shift;
  my $type = $self->param('type');
  my $node_id = $self->param('tree')->root_id;
  my $qtaxon_id = $self->param('qtaxon_id') || 0;

  my $sth = $self->compara_dba->dbc->prepare
    ("INSERT INTO hmmsearch
       (stable_id,
        node_id,
        evalue,
        score,
        type,
        qtaxon_id) VALUES (?,?,?,?,?,?)");

  my $evalue_count = 0;
  my $hits = $self->param('hits');

  foreach my $stable_id (keys %$hits) {
    my $evalue = $hits->{$stable_id}{Evalue};
    my $score = $hits->{$stable_id}{Score};
    next unless (defined($stable_id) && $stable_id ne '');
    next unless (defined($score));
    next unless ($evalue < $self->param('max_evalue') );
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

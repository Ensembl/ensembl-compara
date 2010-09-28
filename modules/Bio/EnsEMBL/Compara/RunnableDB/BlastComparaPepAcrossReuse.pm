#
# You may distribute this module under the same terms as perl itself
#
# POD documentation - main docs before the code

=pod 

=head1 NAME

Bio::EnsEMBL::Compara::RunnableDB::BlastComparaPepAcrossReuse

=cut

=head1 SYNOPSIS

my $db      = Bio::EnsEMBL::Compara::DBAdaptor->new($locator);
my $blast = Bio::EnsEMBL::Compara::RunnableDB::BlastComparaPepAcrossReuse->new
 (
  -db      => $db,
  -input_id   => $input_id
  -analysis   => $analysis );
$blast->fetch_input(); #reads from DB
$blast->run();
$blast->output();
$blast->write_output(); #writes to DB

=cut

=head1 DESCRIPTION

This object wraps Bio::EnsEMBL::Analysis::Runnable::Blast to add
functionality to read and write to databases.
The appropriate Bio::EnsEMBL::Analysis object must be passed for
extraction of appropriate parameters. A Bio::EnsEMBL::Analysis::DBSQL::Obj is
required for databse access.

=cut

=head1 CONTACT

  Contact Albert Vilella on module implemetation/design detail: avilella@ebi.ac.uk
  Contact Ewan Birney on EnsEMBL in general: birney@sanger.ac.uk

=cut

=head1 APPENDIX

The rest of the documentation details each of the object methods. 
Internal methods are usually preceded with a _

=cut

package Bio::EnsEMBL::Compara::RunnableDB::BlastComparaPepAcrossReuse;

use strict;
use warnings;

use Bio::EnsEMBL::Utils::Exception qw(throw warning);
use Bio::EnsEMBL::Compara::DBSQL::DBAdaptor;
use Bio::EnsEMBL::Analysis::Runnable;
use Bio::EnsEMBL::Analysis::Runnable::Blast;
use Bio::EnsEMBL::Analysis::Tools::BPliteWrapper;
use Bio::EnsEMBL::Analysis::Tools::FilterBPlite;
use Bio::EnsEMBL::Hive::Process;
use Bio::EnsEMBL::Hive::URLFactory;               # Blast_reuse
use Bio::EnsEMBL::Compara::PeptideAlignFeature;   # Blast_reuse
use File::Basename;

use base ('Bio::EnsEMBL::Compara::RunnableDB::BaseRunnable');

sub strict_hash_format { # allow this Runnable to parse parameters in its own way (don't complain)
    return 0;
}

my $g_BlastComparaPep_workdir;

=head2 fetch_input

    Title   :   fetch_input
    Usage   :   $self->fetch_input
    Function:   Fetches input data for repeatmasker from the database
    Returns :   none
    Args    :   none

=cut

sub fetch_input {
  my( $self) = @_;

  $self->throw("No input_id") unless defined($self->input_id);

  ## Get the query (corresponds to the member with a member_id = input_id)
  $self->compara_dba->dbc->disconnect_when_inactive(0);
  my $member_id = $self->input_id;
  my $member = $self->compara_dba->get_MemberAdaptor->fetch_by_dbID($member_id);
  $self->throw("No member in compara for member_id = $member_id") unless defined($member);
  if ($member->bioseq->length < 10) {
    $self->input_job->incomplete(0);    # to say "the execution completed successfully, but please record the thown message"
    die "Peptide is too short for BLAST";
  }

  my $query = $member->bioseq();
  $self->throw("Unable to make bioseq for member_id = $member_id") unless defined($query);
  $self->{query} = $query;
  $self->{member} = $member;

  my $p = eval($self->analysis->parameters);
  if (defined $p->{'analysis_data_id'}) {
    my $analysis_data_id = $p->{'analysis_data_id'};
    my $ada = $self->db->get_AnalysisDataAdaptor;
    my $new_params = eval($ada->fetch_by_dbID($analysis_data_id));
    if (defined $new_params) {
      $p = $new_params;
    }
  }
  $self->{p} = $p;
  $self->{null_cigar} = $p->{null_cigar} if (defined($p->{null_cigar}));

  # 1 - Check that both the query and hit genome are reusable - ie
  # they are the same in the old version and so were added in
  # the reuse_gdb array in the configuration file
  foreach my $reusable_gdb (@{$p->{reuse_gdb}}) {
    $self->{reusable_gdb}{$reusable_gdb} = 1;
  }

  # We get the list of genome_dbs to execute, then go one by one with this member
  # Hacky, the list is from the Cluster analysis
  my $cluster_analysis;
  $cluster_analysis = $self->analysis->adaptor->fetch_by_logic_name('PAFCluster');
  $cluster_analysis = $self->analysis->adaptor->fetch_by_logic_name('HclusterPrepare') unless (defined($cluster_analysis));
  my $cluster_parameters = eval($cluster_analysis->parameters);
  if (!defined($cluster_parameters)) {
    throw ("cluster_parameters is undef in analysis_id=" . $cluster_analysis->dbID);
  }
  my @gdbs;
  foreach my $gdb_id (@{$cluster_parameters->{species_set}}) {
    my $genomeDB = $self->compara_dba->get_GenomeDBAdaptor->fetch_by_dbID($gdb_id);
    push @gdbs, $genomeDB;
  }
  print STDERR "Found ", scalar(@gdbs), " genomes to blast this member against.\n" if ($self->debug);
  $self->{cross_gdbs} = \@gdbs;
  return 1;
}


=head2 runnable

  Arg[1]     : (optional) Bio::EnsEMBL::Analysis::Runnable $runnable
  Example    : $self->runnable($runnable);
  Function   : Getter/setter for the runnable
  Returns    : Bio::EnsEMBL::Analysis::Runnable $runnable
  Exceptions : none

=cut

sub runnable {
  my $self = shift(@_);

  if (@_) {
    $self->{_runnable} = shift;
  }

  return $self->{_runnable};
}


=head2 run

  Arg[1]     : -none-
  Example    : $self->run;
  Function   : Runs the runnable set in fetch_input
  Returns    : 1 on successful completion
  Exceptions : dies if runnable throws an unexpected error

=cut

sub run {
  my $self = shift;

  my $p = $self->{p};
  my $member = $self->{member};
  my $query = $self->{query};

  my $cross_pafs;

  foreach my $gdb (@{$self->{cross_gdbs}}) {
    my $fastafile .= $gdb->name() . "_" . $gdb->assembly() . ".fasta";
    $fastafile =~ s/\s+/_/g;    # replace whitespace with '_' characters
    $fastafile =~ s/\/\//\//g;  # converts any // in path to /
    my $self_dbfile = $self->analysis->db_file;
    my ($file,$path,$type) = fileparse($self_dbfile);
    my $dbfile = "$path"."$fastafile";

    # Here we can look at a previous build and try to reuse the blast
    # results for this query peptide against this hit genome
    my $reusable_pafs = 1 if (defined($p->{reuse_db}) && defined($self->{reusable_gdb}{$gdb->dbID}) && defined(($self->{reusable_gdb}{$member->genome_db_id})));
    if (defined($reusable_pafs)) {
      # PAFs have been stored during BlastTableReuse, so this gdb is done
    } else {

      ## Define the filter from the parameters
      my ($thr, $thr_type, $options);

      if (defined $p->{'-threshold'} && defined $p->{'-threshold_type'}) {
        $thr      = $p->{-threshold};
        $thr_type = $p->{-threshold_type};
      } else {
        $thr_type = 'PVALUE';
        $thr      = 1e-10;
      }

      if (defined $p->{'options'}) {
        $options = $p->{'options'};
      } else {
        $options = '';
      }

      ## Create a parser object. This Bio::EnsEMBL::Analysis::Tools::FilterBPlite
      ## object wraps the Bio::EnsEMBL::Analysis::Tools::BPliteWrapper which in
      ## turn wraps the Bio::EnsEMBL::Analysis::Tools::BPlite (a port of Ian
      ## Korf's BPlite from bioperl 0.7 into ensembl). This parser also filter
      ## the results according to threshold_type and threshold.
      my $regex = '^(\S+)\s*';
      if ($p->{'regex'}) {
        $regex = $p->{'regex'};
      }

      my $parser = Bio::EnsEMBL::Analysis::Tools::FilterBPlite->new
        (-regex => $regex,
         -query_type => "pep",
         -input_type => "pep",
         -threshold_type => $thr_type,
         -threshold => $thr,
        );

      ## Create the runnable with the previous parser. The filter is not required
      my $runnable = Bio::EnsEMBL::Analysis::Runnable::Blast->new
        (-query     => $query,
         -database  => $dbfile,
         -program   => $self->analysis->program_file,
         -analysis  => $self->analysis,
         -options   => $options,
         -parser    => $parser,
         -filter    => undef,
        );
      $self->runnable($runnable);

      # Only run if the blasts are not being reused
      $self->compara_dba->dbc->disconnect_when_inactive(1);

      ## call runnable run method in eval block
      eval { $self->runnable->run(); };
      ## Catch errors if any
      if ($@) {
        printf(STDERR ref($self->runnable)." threw exception:\n$@$_");
        if($@ =~ /"VOID"/) {
          printf(STDERR "this is OK: member_id=%d doesn't have sufficient structure for a search\n", $self->input_id);
        } else {
          die("$@$_");
        }
      }
      $self->compara_dba->dbc->disconnect_when_inactive(0);
      #since the Blast runnable takes in analysis parameters rather than an
      #analysis object, it creates new Analysis objects internally
      #(a new one for EACH FeaturePair generated)
      #which are a shadow of the real analysis object ($self->analysis)
      #The returned FeaturePair objects thus need to be reset to the real analysis object
      foreach my $feature (@{$self->output}) {
        if($feature->isa('Bio::EnsEMBL::FeaturePair')) {
          $feature->analysis($self->analysis);
          $feature->{null_cigar} = 1 if (defined($self->{null_cigar}));
        }
        push @{$cross_pafs->{$gdb->dbID}}, $feature;
      }
    }
  }
  $self->{cross_pafs} = $cross_pafs;
  return 1;
}


sub write_output {
  my( $self) = @_;

  print STDERR "Inserting PAFs...\n" if ($self->debug);
  foreach my $gdb_id (keys %{$self->{cross_pafs}}) {
    $self->compara_dba->get_PeptideAlignFeatureAdaptor->store(@{$self->{cross_pafs}{$gdb_id}});
  }
}


sub output {
  my ($self, @args) = @_;

  throw ("Cannot call output without a runnable") if (!defined($self->runnable));

  return $self->runnable->output(@args);
}

sub global_cleanup {
  my $self = shift;
  if($g_BlastComparaPep_workdir) {
    unlink(<$g_BlastComparaPep_workdir/*>);
    rmdir($g_BlastComparaPep_workdir);
  }
  return 1;
}

1;

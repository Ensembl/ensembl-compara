#
# You may distribute this module under the same terms as perl itself
#
# POD documentation - main docs before the code

=pod 

=head1 NAME

Bio::EnsEMBL::Compara::RunnableDB::BlastComparaPepAcross

=cut

=head1 SYNOPSIS

my $db      = Bio::EnsEMBL::Compara::DBAdaptor->new($locator);
my $blast = Bio::EnsEMBL::Compara::RunnableDB::BlastComparaPepAcross->new
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

  Contact Jessica Severin on module implemetation/design detail: jessica@ebi.ac.uk
  Contact Abel Ureta-Vidal on EnsEMBL/Compara: abel@ebi.ac.uk
  Contact Ewan Birney on EnsEMBL in general: birney@sanger.ac.uk

=cut

=head1 APPENDIX

The rest of the documentation details each of the object methods. 
Internal methods are usually preceded with a _

=cut

package Bio::EnsEMBL::Compara::RunnableDB::BlastComparaPepAcross;

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
use vars qw(@ISA);

@ISA = qw(Bio::EnsEMBL::Hive::Process);

# 
# our @ISA = qw(Bio::EnsEMBL::Analysis::RunnableDB::Blast);

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

  throw("No input_id") unless defined($self->input_id);

  ## Get the query (corresponds to the member with a member_id = input_id)
  $self->{'comparaDBA'} = Bio::EnsEMBL::Compara::DBSQL::DBAdaptor->new(-DBCONN=>$self->db->dbc);
  $self->{'comparaDBA'}->dbc->disconnect_when_inactive(0);
  my $member_id = $self->input_id;
  my $member = $self->{'comparaDBA'}->get_MemberAdaptor->fetch_by_dbID($member_id);
  throw("No member in compara for member_id = $member_id") unless defined($member);
  if (10 > $member->bioseq->length) {
	$self->input_job->update_status('DONE');
	throw("BLAST : Peptide is too short for BLAST");
  }

  my $query = $member->bioseq();
  throw("Unable to make bioseq for member_id = $member_id") unless defined($query);
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

  # We get the list of genome_dbs to execute, then go one by one with this member
  # Hacky, the list is from the Cluster analysis
  my $cluster_analysis;
  $cluster_analysis = $self->analysis->adaptor->fetch_by_logic_name('PAFCluster');
  $cluster_analysis = $self->analysis->adaptor->fetch_by_logic_name('HclusterPrepare') unless (defined($cluster_analysis));
  my $cluster_parameters = eval($cluster_analysis->parameters);
  if (!defined($cluster_parameters)) {
    my $message = "cluster_parameters is undef in analysis_id=" . $cluster_analysis->dbID;
    throw ("$message");
  }
  my @gdbs;
  foreach my $gdb_id (@{$cluster_parameters->{species_set}}) {
    my $genomeDB = $self->{'comparaDBA'}->get_GenomeDBAdaptor->fetch_by_dbID($gdb_id);
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
  Returns    : 1 on succesfull completion
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
    my $reusable_pafs = $self->try_reuse_blast($p,$gdb->dbID,$member) if (defined $p->{reuse_db});
    if (defined($reusable_pafs)) {
      foreach my $reusable_paf (@$reusable_pafs) {
        push @{$cross_pafs->{$gdb->dbID}}, $reusable_paf;
      }
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
      $self->{'comparaDBA'}->dbc->disconnect_when_inactive(1);

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
      $self->{'comparaDBA'}->dbc->disconnect_when_inactive(0);
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
    $self->{'comparaDBA'}->get_PeptideAlignFeatureAdaptor->store(@{$self->{cross_pafs}{$gdb_id}});
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

##########################################
#
# internal methods
#
##########################################

# using the genome_db and longest peptides subset, create a fasta
# file which can be used as a blast database
sub dumpPeptidesToFasta
{
  my $self = shift;

  my $startTime = time();
  my $params = eval($self->analysis->parameters);
  my $genomeDB = $self->{'comparaDBA'}->get_GenomeDBAdaptor->fetch_by_dbID($params->{'genome_db_id'});
  
  # create logical path name for fastafile
  my $species = $genomeDB->name();
  $species =~ s/\s+/_/g;  # replace whitespace with '_' characters

  #create temp directory to hold fasta databases
  $g_BlastComparaPep_workdir = "/tmp/worker.$$/";
  mkdir($g_BlastComparaPep_workdir, 0777);
  
  my $fastafile = $g_BlastComparaPep_workdir.
                  $species . "_" .
                  $genomeDB->assembly() . ".fasta";
  $fastafile =~ s/\/\//\//g;  # converts any // in path to /
  return $fastafile if(-e $fastafile);
  print("fastafile = '$fastafile'\n");

  # write fasta file to local /tmp/disk
  my $subset   = $self->{'comparaDBA'}->get_SubsetAdaptor()->fetch_by_dbID($params->{'subset_id'});
  $self->{'comparaDBA'}->get_SubsetAdaptor->dumpFastaForSubset($subset, $fastafile);

  # configure the fasta file for use as a blast database file
  my $blastdb     = new Bio::EnsEMBL::Analysis::Runnable::BlastDB (
      -dbfile     => $fastafile,
      -type       => 'PROTEIN');
  $blastdb->run;
  print("registered ". $blastdb->dbname . " for ".$blastdb->dbfile . "\n");

  printf("took %d secs to dump database to local disk\n", (time() - $startTime));

  return $fastafile;
}

sub try_reuse_blast {
  my $self = shift;
  my $p = shift;
  my $gdb_id = shift;
  my $member = shift;

  # 1 - Check that both the query and hit genome are reusable - ie
  # they are the same in the old version and so were added in
  # the reuse_gdb array in the configuration file
  foreach my $reusable_gdb (@{$p->{reuse_gdb}}) {
    $self->{reusable_gdb}{$reusable_gdb} = 1;
  }
  my $hit_genome_db_id = $gdb_id;
  return undef unless (defined($self->{reusable_gdb}{$hit_genome_db_id}) 
                 && 
                 defined($self->{reusable_gdb}{$member->genome_db_id}));

  $self->{'comparaDBA_reuse'} = Bio::EnsEMBL::Hive::URLFactory->fetch($p->{reuse_db}, 'compara');
  my $paf_adaptor = $self->{'comparaDBA_reuse'}->get_PeptideAlignFeatureAdaptor;
  my $member_adaptor = $self->{'comparaDBA_reuse'}->get_MemberAdaptor;
  my $member_reuse = $member_adaptor->fetch_by_source_stable_id('ENSEMBLPEP',$member->stable_id);
  return undef unless (defined $member_reuse);
  # 2 - Check that the query member is an identical sequence in both dbs
  unless ($member_reuse->sequence eq $member->sequence) {
    print STDERR "Different query sequence for ", $member->stable_id ," when trying to reuse blast from previous build.\n" if ($self->debug);
    return undef;
  }

  my $pafs = $paf_adaptor->fetch_all_by_qmember_id_hgenome_db_id($member_reuse->member_id,$hit_genome_db_id);
  my @new_pafs;
  foreach my $paf (@$pafs) {
    my $hit_member_reuse = $paf->hit_member;
    my $hit_member = $self->{'comparaDBA'}->get_MemberAdaptor->fetch_by_source_stable_id('ENSEMBLPEP',$hit_member_reuse->stable_id);
    # 3 - Check that the hit member is an identical sequence in both dbs
    unless (defined ($hit_member)) { return undef; }
    unless ($hit_member_reuse->sequence eq $hit_member->sequence) {
          print STDERR "Different hit sequence for ", $hit_member->stable_id ," when trying to reuse blast from previous build.\n" if ($self->debug);
          return undef;
    }
    print STDERR "Reusing ", $hit_member->member_id, " ", $hit_member->stable_id, " - ", $member->member_id, " ", $member->stable_id, " (",$hit_member->genome_db_id, ":", $member->genome_db_id, ")", " from previous build.\n" if ($self->debug);

    # Now we can reuse this paf
    my $new_paf = new Bio::EnsEMBL::Compara::PeptideAlignFeature;
    $new_paf->query_genome_db_id($member->genome_db_id);
    $new_paf->query_member($member);
    $new_paf->hit_genome_db_id($hit_member->genome_db_id);
    $new_paf->hit_member($hit_member);
    $new_paf->qstart($paf->qstart);
    $new_paf->hstart($paf->hstart);
    $new_paf->qend($paf->qend);
    $new_paf->hend($paf->hend);
    $new_paf->score($paf->score);
    $new_paf->evalue($paf->evalue);
    $new_paf->cigar_line($paf->cigar_line);
    $new_paf->alignment_length($paf->alignment_length);
    $new_paf->positive_matches($paf->positive_matches);
    $new_paf->identical_matches($paf->identical_matches);
    $new_paf->perc_ident($paf->perc_ident);
    $new_paf->perc_pos($paf->perc_pos);
    $new_paf->cigar_line('') if (defined($self->{null_cigar}));
    push @new_pafs, $new_paf;
  }
  return \@new_pafs;
}

1;

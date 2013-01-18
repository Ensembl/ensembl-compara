#
# You may distribute this module under the same terms as perl itself
#
# POD documentation - main docs before the code

=pod 

=head1 NAME

Bio::EnsEMBL::Compara::RunnableDB::ProteinTrees::BlastpWithReuse

=cut

=head1 SYNOPSIS

my $db      = Bio::EnsEMBL::Compara::DBAdaptor->new($locator);
my $blast = Bio::EnsEMBL::Compara::RunnableDB::ProteinTrees::BlastpWithReuse->new
 (
  -db      => $db,
  -input_id   => $input_id
  -analysis   => $analysis );
$blast->fetch_input(); #reads from DB
$blast->run();
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

  Please email comments or questions to the public Ensembl developers list at <dev@ensembl.org>.
  Questions may also be sent to the Ensembl help desk at <helpdesk@ensembl.org>.

=cut

=head1 APPENDIX

The rest of the documentation details each of the object methods. 
Internal methods are usually preceded with a _

=cut

package Bio::EnsEMBL::Compara::RunnableDB::ProteinTrees::BlastpWithReuse;

use strict;
use warnings;

use Bio::EnsEMBL::Utils::Exception qw(throw warning);
use Bio::EnsEMBL::Analysis;
use Bio::EnsEMBL::Analysis::Runnable::Blast;
use Bio::EnsEMBL::Analysis::Tools::BPliteWrapper;
use Bio::EnsEMBL::Analysis::Tools::FilterBPlite;
use Bio::EnsEMBL::Compara::PeptideAlignFeature;   # Blast_reuse

use base ('Bio::EnsEMBL::Compara::RunnableDB::BaseRunnable');


=head2 fetch_input

    Title   :   fetch_input
    Usage   :   $self->fetch_input
    Function:   Fetches input data for repeatmasker from the database
    Returns :   none
    Args    :   none

=cut

sub fetch_input {
    my $self = shift @_;

    $self->compara_dba->dbc->disconnect_when_inactive(0);


    my $reuse_ss_id = $self->param('reuse_ss_id')
                    or die "'reuse_ss_id' is an obligatory parameter dynamically set in 'meta' table by the pipeline - please investigate";

    my $reuse_ss = $self->compara_dba()->get_SpeciesSetAdaptor->fetch_by_dbID($reuse_ss_id);    # this method cannot fail at the moment, but in future it may

    my $reuse_ss_hash = {};
       $reuse_ss_hash = { map { $_->dbID() => 1 } @{ $reuse_ss->genome_dbs() } } if $reuse_ss;
    $self->param('reuse_ss_hash', $reuse_ss_hash );


    my $member_id = $self->param('member_id')
                        or die "'member_id' is an obligatory parameter";
    my $member    = $self->compara_dba->get_SeqMemberAdaptor->fetch_by_dbID($member_id)
                        or die "Could not fetch member with member_id='$member_id'";
    my $query     = $member->bioseq()
                        or die "Could not fetch bioseq for member with member_id='$member_id'";

    if ($query->length < 10) {
        $self->input_job->incomplete(0);    # to say "the execution completed successfully, but please record the thown message"
        die "Peptide is too short for BLAST";
    }

    $self->param('member', $member);
    $self->param('query',  $query);

      # We get the list of genome_dbs to execute, then go one by one with this member

    my $mlss_id         = $self->param('mlss_id') or die "'mlss_id' is an obligatory parameter";
    my $mlss            = $self->compara_dba()->get_MethodLinkSpeciesSetAdaptor->fetch_by_dbID($mlss_id) or die "Could not fetch mlss with dbID=$mlss_id";
    my $genome_db_list  = $mlss->species_set_obj->genome_dbs;

    print STDERR "Found ", scalar(@$genome_db_list), " genomes to blast this member against.\n" if ($self->debug);
    $self->param('genome_db_list', $genome_db_list);
}


=head2 run

  Arg[1]     : -none-
  Example    : $self->run;
  Function   : Runs the runnable set in fetch_input
  Returns    : 1 on successful completion
  Exceptions : dies if runnable throws an unexpected error

=cut

sub run {
    my $self = shift @_;

    my $member_id   = $self->param('member_id');
    my $member      = $self->param('member');
    my $query       = $self->param('query');

    my $reuse_db          = $self->param('reuse_db');   # if this parameter is an empty string, there will be no reuse

    my $reuse_ss_hash     = $self->param('reuse_ss_hash');
    my $reuse_this_member = $reuse_ss_hash->{$member->genome_db_id};

    my $fasta_dir         = $self->param('fasta_dir') or die "'fasta_dir' is an obligatory parameter";

    my $wublastp_exe      = $self->param('wublastp_exe') or die "'wublastp_exe' is an obligatory parameter";
    die "Cannot execute '$wublastp_exe'" unless(-x $wublastp_exe);

    my $blast_tmp_dir     = $self->param('blast_tmp_dir');
    
    my $fake_analysis     = Bio::EnsEMBL::Analysis->new;

    my %cross_pafs = ();

  foreach my $genome_db (@{$self->param('genome_db_list')}) {
    my $fastafile = $genome_db->name() . '_' . $genome_db->assembly() . '.fasta';
    $fastafile =~ s/\s+/_/g;    # replace whitespace with '_' characters
    $fastafile =~ s/\/\//\//g;  # converts any // in path to /
    my $cross_genome_dbfile = $fasta_dir . '/' . $fastafile;   # we are always interested in the 'foreign' genome's fasta file, not the member's

        # Here we can look at a previous build and try to reuse the blast
        # results for this query peptide against this hit genome.
        # Only run if the blasts are not being reused:
    unless($reuse_db and $reuse_ss_hash->{$genome_db->dbID} and $reuse_this_member) {

          ## Define the filter from the parameters:
      my $thr_type = $self->param('-threshold_type');
      my $thr      = $self->param('-threshold');
      unless($thr_type and $thr) {
        ($thr_type, $thr) = ('PVALUE', 1e-10);
      }
      my $blast_options  = $self->param('blast_options') || '';

      ## Create a parser object. This Bio::EnsEMBL::Analysis::Tools::FilterBPlite
      ## object wraps the Bio::EnsEMBL::Analysis::Tools::BPliteWrapper which in
      ## turn wraps the Bio::EnsEMBL::Analysis::Tools::BPlite (a port of Ian
      ## Korf's BPlite from bioperl 0.7 into ensembl). This parser also filter
      ## the results according to threshold_type and threshold.

      my $regex = $self->param('regex') || '^(\S+)\s*';

      my $parser = Bio::EnsEMBL::Analysis::Tools::FilterBPlite->new(
        -regex          => $regex,
        -query_type     => 'pep',
        -input_type     => 'pep',
        -threshold_type => $thr_type,
        -threshold      => $thr,
      );

          ## Create the runnable with the previous parser. The filter is not required:
      my $runnable = Bio::EnsEMBL::Analysis::Runnable::Blast->new(
         -query     => $query,
         -database  => $cross_genome_dbfile,
         -program   => $wublastp_exe,
         -analysis  => $fake_analysis,
         -options   => $blast_options,
         -parser    => $parser,
         -filter    => undef,
         ( $blast_tmp_dir ? (-workdir => $blast_tmp_dir) : () ),
      );

      $self->compara_dba->dbc->disconnect_when_inactive(1);

      ## call runnable run method in eval block
      eval { $runnable->run(); };
      ## Catch errors if any
      if ($@) {
        print STDERR ref($runnable)." threw exception:\n$@$_";
        if($@ =~ /"VOID"/) {
          print STDERR "this is OK: member_id='$member_id' doesn't have sufficient structure for a search\n";
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
      foreach my $feature (@{$runnable->output}) {
        if($feature->isa('Bio::EnsEMBL::FeaturePair')) {
          $feature->{null_cigar} = 1 if ($self->param('null_cigar'));
        }
        push @{$cross_pafs{$genome_db->dbID}}, $feature;
      }

    } # unless it is reuse-against-reuse

  } # for each genome_db

  $self->param('cross_pafs', \%cross_pafs);
}


sub write_output {
    my $self = shift @_;

    print STDERR "Inserting PAFs...\n" if ($self->debug);

    my $cross_pafs = $self->param('cross_pafs');
    foreach my $genome_db_id (keys %$cross_pafs) {
        $self->compara_dba->get_PeptideAlignFeatureAdaptor->store(@{$cross_pafs->{$genome_db_id}});
    }
}


1;

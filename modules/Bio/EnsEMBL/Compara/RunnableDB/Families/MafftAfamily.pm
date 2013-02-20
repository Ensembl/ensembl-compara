package Bio::EnsEMBL::Compara::RunnableDB::Families::MafftAfamily;

use strict;
use Bio::EnsEMBL::Compara::DBSQL::DBAdaptor;

use base ('Bio::EnsEMBL::Compara::RunnableDB::BaseRunnable');

sub fetch_input {
    my $self = shift @_;

    my $family_id               = $self->param('family_id')   || die "'family_id' is an obligatory parameter, please set it in the input_id hashref";

    my $family = $self->compara_dba()->get_FamilyAdaptor()->fetch_by_dbID($family_id)
                || die "family $family_id could not have been fetched by the adaptor";

    $self->param('family', $family); # save it for the future

    my $aln;
    eval {$aln = $family->get_SimpleAlign};
    unless ($@) {
        if(defined(my $flush = $aln->is_flush)) { # looks like this family is already aligned
            return;
        }
    }

    # otherwise prepare the files and perform the actual mafft run:

    my $worker_temp_directory   = $self->worker_temp_directory;

    my $pep_file    = $worker_temp_directory . "family_${family_id}.pep";
    my $mafft_file  = $worker_temp_directory . "family_${family_id}.mafft";

    my $pep_counter = $family->print_sequences_to_fasta($pep_file);

    if ($pep_counter == 0) {
        unlink $pep_file;
        die "family $family_id does not seem to contain any members";

    } elsif ($pep_counter == 1) {

        unlink $pep_file;
        my $member = (grep {$_->source_name ne 'ENSEMBLGENE'} @{$family->get_all_Members})[0];
        my $cigar_line = length($member->sequence).'M';
        eval {$member->cigar_line($cigar_line) };
        if($@) {
            die "could not set the cigar_line for singleton family $family_id, because: $@ ";
        }
        # by setting this parameter we will trigger the update in write_output()
        $self->param('singleton_relation', $member);
        return;

    } elsif ($pep_counter>=20000) {
        my $mafft_args = $self->param('mafft_args') || '';
        $self->param('mafft_args', $mafft_args.' --parttree' );
    }

        # if these two parameters are set, run() will need to actually execute mafft
    $self->param('pep_file', $pep_file);
    $self->param('mafft_file', $mafft_file);

    $self->dbc->disconnect_when_inactive(1);
}

sub run {
    my $self = shift @_;

    my $family_id               = $self->param('family_id');
    my $mafft_root_dir          = $self->param('mafft_root_dir') || die "'mafft_root_dir' is an obligatory parameter";
    my $mafft_executable        = $self->param('mafft_exec')     || ( $mafft_root_dir . '/bin/mafft' );
    my $mafft_args              = $self->param('mafft_args')     || '';

    my $pep_file                = $self->param('pep_file');
    my $mafft_file              = $self->param('mafft_file');

    unless($pep_file) { # if we have no more work to do just exit gracefully
        return;
    }

    # $ENV{MAFFT_BINARIES} = $mafft_root_dir.'/bin'; # not needed (actually, in the way) for newer versions of MAFFT

    my $cmd_line = "$mafft_executable --anysymbol $mafft_args $pep_file > $mafft_file"; # helps when Uniprot sequence contains 'U' or other funny aminoacid codes
    # my $cmd_line = "$mafft_executable $mafft_args $pep_file > $mafft_file";
    if($self->debug) {
        warn "About to execute: $cmd_line\n";
    }

    if(system($cmd_line)) {
        die "running mafft on family $family_id failed, because: $! ";
    } elsif(-z $mafft_file) {
        die "running mafft on family $family_id produced zero-length output";
    }

        # the file(s) will be removed on success and should stay undeleted on failure
    unless($self->debug) {
        unlink $pep_file;
    }
}

sub write_output {
    my $self = shift @_;

    if($self->param('singleton_relation')) {

        $self->compara_dba()->get_FamilyAdaptor()->update($self->param('family'), 1);

    } elsif(my $mafft_file = $self->param('mafft_file')) {

        my $family = $self->param('family');
        $family->load_cigars_from_fasta($mafft_file);
        $family->adaptor->update($family, 1);

        unless($self->debug) {
            unlink $mafft_file;
        }
    } # otherwise we had no work to do and no files to remove
}

1;


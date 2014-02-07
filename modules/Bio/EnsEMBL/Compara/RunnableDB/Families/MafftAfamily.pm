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

package Bio::EnsEMBL::Compara::RunnableDB::Families::MafftAfamily;

use strict;
use Bio::EnsEMBL::Compara::DBSQL::DBAdaptor;

use base ('Bio::EnsEMBL::Compara::RunnableDB::BaseRunnable');

sub param_defaults {
    return {
            # --anysymbol helps when Uniprot sequence contains 'U' or other funny aminoacid codes
            # --thread 1 is supposed to prevent forking
        'mafft_cmdline_args'    => '--anysymbol --thread 1',
        'mafft_exec'            => '#mafft_root_dir#/bin/mafft',
    };
}


sub fetch_input {
    my $self = shift @_;

    my $family_id               = $self->param_required('family_id');

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

    my $pep_file    = $worker_temp_directory . "family_${family_id}.fa";
    my $mafft_file  = $worker_temp_directory . "family_${family_id}.mafft";

    my $pep_counter = $family->print_sequences_to_file($pep_file);

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
        my $mafft_cmdline_args = $self->param('mafft_cmdline_args') || '';
        $self->param('mafft_cmdline_args', $mafft_cmdline_args.' --parttree' );
    }

        # if these two parameters are set, run() will need to actually execute mafft
    $self->param('pep_file', $pep_file);
    $self->param('mafft_file', $mafft_file);

    $self->dbc->disconnect_when_inactive(1);
}

sub run {
    my $self = shift @_;

    my $family_id               = $self->param('family_id');
    my $mafft_root_dir          = $self->param_required('mafft_root_dir');
    my $mafft_executable        = $self->param_required('mafft_exec');
    my $mafft_cmdline_args      = $self->param('mafft_cmdline_args') || '';
    my $pep_file                = $self->param('pep_file') or return;   # if we have no more work to do just exit gracefully
    my $mafft_file              = $self->param('mafft_file');

    my $cmd_line = "$mafft_executable $mafft_cmdline_args $pep_file > $mafft_file";

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
        $family->load_cigars_from_file($mafft_file, -format => 'fasta');
        $family->adaptor->update($family, 1);

        unless($self->debug) {
            unlink $mafft_file;
        }
    } # otherwise we had no work to do and no files to remove
}

1;



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

=cut

=head1 NAME

Bio::EnsEMBL::Compara::RunnableDB::ComparaHMM::HmmOverlap

=head1 SYNOPSIS

This runnable is used to:
    1 - Run hmmsearch on all TF globals against the newly downloaded PANTHER profiles
    2 - If there are any hits, the whole family should be replaced by the Panther family 
    3 - We should keep track of the mappings on a new table 

=head1 DESCRIPTION

This Analysis/RunnableDB is designed find an overlap between TreeFam and PANTHER HMM profiles. Whenever there is an overlap, PATHER will have priority.

=cut

package Bio::EnsEMBL::Compara::RunnableDB::ComparaHMM::HmmOverlap;

use strict;
use warnings;

use Data::Dumper;

use base ('Bio::EnsEMBL::Hive::Process');
use base ( 'Bio::EnsEMBL::Compara::RunnableDB::BaseRunnable', 'Bio::EnsEMBL::Compara::StableId::Adaptor' );

sub param_defaults {
    return {
        'hmmer_cutoff' => 1e-23,
        'panther_hmm_lib' => '#panther_hmm_library_basedir#',
    };
}

sub fetch_input {
    my $self = shift @_;
    $self->param_required('panther_hmm_lib');
    $self->param_required('hmmer_home');
    $self->param_required('panther_hmm_library_basedir');
}

sub run {
    my $self = shift @_;

    #Run hmmserach (hmmer_3)
    $self->_run_HMM_search;
}

sub write_output {
    my $self = shift;
    $self->_store_mapping;
}

##########################################
#
# internal methods
#
##########################################

sub _run_HMM_search {
    my ($self) = @_;

    my $hmmLibrary   = $self->param('panther_hmm_lib') . "/" . $self->param('library_name');
    my $hmmer_home   = $self->param('hmmer_home');
    my $hmmer_cutoff = $self->param('hmmer_cutoff');                                           ## Not used for now!!

    my $worker_temp_directory = $self->worker_temp_directory;
    my $only_TF               = $worker_temp_directory . "/treefam_profiles.fasta";

    my $cmd = $hmmer_home . "/hmmsearch --cpu 1 -E $hmmer_cutoff --noali --tblout $worker_temp_directory/treefam_hmm_search.out " . $hmmLibrary . " " . $self->param('chunk_name');

    my $cmd_out = $self->run_command($cmd);

    my %hmm_annot;

    # Detection of failures
    if ( $cmd_out->exit_code ) {
        $self->throw( sprintf( "error running pantherScore [%s]: %d\n%s", $cmd_out->cmd, $cmd_out->exit_code, $cmd_out->err ) );
    }
    if ( $cmd_out->err =~ /^Missing sequence for (.*)$/ ) {
        $self->throw( sprintf( "pantherScore detected a missing sequence for the member %s. Full log is:\n%s", $1, $cmd_out->err ) );
    }

    #Parsing outputs
    open my $hmm_fh, "$worker_temp_directory/treefam_hmm_search.out" || die "Could not open file: $worker_temp_directory/treefam_hmm_search.out";
    while (<$hmm_fh>) {

        #get rid of the header lines
        next if $_ =~ /^#/;

        #Only split the initial 6 wanted positions, $accession1-2 are not used.
        my ( $seq_id, $accession1, $hmm_id, $accession2, $eval ) = split /\s+/, $_, 6;

        #if hash exists we need to compare the already existing value, so that we only store the best e-value
        if ( exists( $hmm_annot{$seq_id} ) ) {
            if ( $eval < $hmm_annot{$seq_id}{'eval'} ) {
                $hmm_annot{$seq_id}{'eval'}   = $eval;
                $hmm_annot{$seq_id}{'hmm_id'} = $hmm_id;
            }
        }
        else {
            #storing evalues for the firt time
            $hmm_annot{$seq_id}{'eval'}   = $eval;
            $hmm_annot{$seq_id}{'hmm_id'} = $hmm_id;
        }

    } ## end while (<$hmm_fh>)
    close($hmm_fh);

    $self->param( 'hmm_annot', \%hmm_annot );

} ## end sub _run_HMM_search

sub _store_mapping {
    my ($self) = @_;

    my $prev_rel_db  = $self->param('prev_rel_db');
    my $curr_release = $self->param('release') || $self->compara_dba->get_MetaContainer->get_schema_version;
    my $dbc          = $self->compara_dba->dbc;
    my $timestamp    = time();
    my $type         = "hmm";
    my $prefix       = "TF";

    my $mapping_session_id;

    my $ms_sth = $dbc->prepare("SELECT mapping_session_id FROM mapping_session");
    $ms_sth->execute();
    my ($existing_mapping_session_id) = $ms_sth->fetchrow_array();
    $ms_sth->finish();

    if ( !defined $existing_mapping_session_id ) {
        if ($prev_rel_db) {

            my $prev_rel_dba = $self->get_cached_compara_dba('prev_rel_db');
            my $prev_release = $self->param('prev_release') || $prev_rel_dba->get_MetaContainer->get_schema_version;

            my $adaptor  = Bio::EnsEMBL::Compara::StableId::Adaptor->new();
            my $from_ncs = $adaptor->fetch_ncs( $prev_release, $type, $prev_rel_dba->dbc() );
            my $to_ncs   = $adaptor->fetch_ncs( $curr_release, $type, $self->compara_dba->dbc() );
            my $ncsl     = Bio::EnsEMBL::Compara::StableId::NamedClusterSetLink->new( -FROM => $from_ncs, -TO => $to_ncs );

            $mapping_session_id = $self->get_mapping_session_id( $ncsl, $timestamp, $dbc );

            my $ms_sth = $dbc->prepare("INSERT INTO mapping_session(mapping_session_id, type, rel_from, rel_to, prefix, when_mapped ) VALUES (?, ?, ?, ?, ?, FROM_UNIXTIME(?))");
            $ms_sth->execute( $mapping_session_id, $type, $ncsl->from->release(), $ncsl->to->release(), $prefix, $timestamp );
            $ms_sth->finish();

        }
        else {

            $mapping_session_id = 1;

            my $ms_sth = $dbc->prepare("INSERT INTO mapping_session(mapping_session_id, type, rel_to, prefix, when_mapped) VALUES (?, ?, ?, ?, FROM_UNIXTIME(?))");
            $ms_sth->execute( $mapping_session_id, $type, $curr_release, $prefix, $timestamp );
            $ms_sth->finish();
        }
    } ## end if ( !defined $existing_mapping_session_id)
    else{
        $mapping_session_id = $existing_mapping_session_id;
    }

    foreach my $hmm_from ( keys %{ $self->param('hmm_annot') } ) {

        my $hmm_to       = $self->param('hmm_annot')->{$hmm_from}{'hmm_id'};
        my $ver_from     = 9;
        my $ver_to       = 11;
        my $contribution = 100;

        my $sth = $dbc->prepare("INSERT IGNORE INTO stable_id_history(mapping_session_id, stable_id_from, version_from, stable_id_to, version_to, contribution) VALUES (?, ?, ?, ?, ?, ?)");
        $sth->execute( $mapping_session_id, $hmm_from, $ver_from, $hmm_to, $ver_to, $contribution );
        $sth->finish();
    }

} ## end sub _store_mapping

1;

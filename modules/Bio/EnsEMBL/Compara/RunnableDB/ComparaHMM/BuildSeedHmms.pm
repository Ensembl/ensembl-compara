
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

Bio::EnsEMBL::Compara::RunnableDB::ComparaHMM::BuildSeedHmms

=head1 SYNOPSIS

This runnable is used to:
    1 - Fetch all TF and PANTHER ids.
    2 - Build a map of all the TF ids and their PANTHER replacements and extract all the non replaced TF families
    3 - Fetch, compose and build hmm3 profiles for them. Subsequently ensembling a library with all the non-overlapped TF and all the PANTHER profiles. 
    4 - Run hmmpress.

=head1 DESCRIPTION

This Analysis/RunnableDB is designed to build a the Ensembl seed HMM library.

=cut

package Bio::EnsEMBL::Compara::RunnableDB::ComparaHMM::BuildSeedHmms;

use strict;
use warnings;

use Data::Dumper;
use Bio::SeqIO;

use base ('Bio::EnsEMBL::Hive::Process');
use base ( 'Bio::EnsEMBL::Compara::RunnableDB::BaseRunnable', 'Bio::EnsEMBL::Compara::StableId::Adaptor' );

sub param_defaults {
    return {
                'treefam_hmm_lib' => '#treefam_hmm_library_basedir#',
                'panther_hmm_lib' => '#panther_hmm_library_basedir#',
                'hmmfetch_exe'    => '#hmmer_home#/hmmfetch',
                'hmmpress_exe'    => '#hmmer_home#/hmmpress',
           };
}

sub fetch_input {
    my $self = shift @_;
    $self->param_required('treefam_hmm_lib');
    $self->param_required('panther_hmm_lib');
    $self->param_required('hmmer_home');
    $self->param_required('panther_hmm_library_basedir');
    $self->param_required('panther_hmm_library_name');
    $self->param_required('seed_hmm_library_basedir');
    $self->param_required('seed_hmm_library_name');
}

sub run {
    my $self = shift @_;

    $self->_fetch_all_tf_ids;
    $self->_build_tf_panther_map;
    $self->_fetch_and_compose;
    $self->_run_hmmpress;
}

##########################################
#
# internal methods
#
##########################################

sub _fetch_all_tf_ids {
    my ($self) = @_;

    my $tf_globals       = $self->param('treefam_hmm_lib') . "/globals/con.Fasta";
    my $treefam_lib_file = $self->param('treefam_only_hmm_lib') . "/treefam.hmm3";
    my $panther_lib_file = $self->param('panther_hmm_lib') . "/" . $self->param('panther_hmm_library_name');
    $self->param( 'treefam_lib_file', $treefam_lib_file );
    $self->param( 'panther_lib_file', $panther_lib_file );

    my %all_tf_sequences;

    #Its faster to get the names from the globals than the hmm3 profiles.
    my $in_file = Bio::SeqIO->new( -file => $tf_globals, '-format' => 'Fasta' );
    while ( my $seq = $in_file->next_seq() ) {
        if ( $seq->id =~ /^TF/ ) {
            $all_tf_sequences{ $seq->id } = $seq->seq;
        }
    }
    $self->param( 'all_tf_sequences', \%all_tf_sequences );

    #Get PANTHER family names
    my @panther_ids_list = `grep "^NAME  PTH" $panther_lib_file | cut -d " " -f 3 `;
    $self->param( 'all_panther_ids_list', \@panther_ids_list );
}

sub _build_tf_panther_map {
    my ($self) = @_;
    my $dbc = $self->compara_dba->dbc;
    my %map_replaced_tf_panther;
    my %new_library_ids;

    #1 - select stable_id_from, stable_id_to from stable_id_history.
    my $sih_sth = $dbc->prepare("SELECT stable_id_from, stable_id_to FROM stable_id_history;");

    $sih_sth->execute();
    while ( my $res = $sih_sth->fetchrow_arrayref ) {
        $map_replaced_tf_panther{ $res->[0] } = $res->[1];
    }
    $sih_sth->finish;

    #Add all TF ids, and for those with overlap, replace with the PANTHER
    foreach my $tf_family ( keys( %{ $self->param('all_tf_sequences') } ) ) {
        if ( $map_replaced_tf_panther{$tf_family} ) {
            $new_library_ids{ $map_replaced_tf_panther{$tf_family} } = 1;

            #TF family was replaced
        }
        else {
            #TF was not replaced
            $new_library_ids{$tf_family} = 1;
        }
    }

    #Add all PANTHER ids
    foreach my $panther_family ( @{ $self->param('all_panther_ids_list') } ) {
        chomp($panther_family);
        $new_library_ids{$panther_family} = 1;
    }

    $self->param( 'new_library_ids', \%new_library_ids );
} ## end sub _build_tf_panther_map

sub _fetch_and_compose {
    my ($self) = @_;

    my $worker_temp_directory = $self->worker_temp_directory;
    my $seed_hmm_file         = $self->param('seed_hmm_library_basedir') . '/' . $self->param('seed_hmm_library_name');

    unlink glob("$seed_hmm_file*");

    foreach my $id ( sort keys %{ $self->param('new_library_ids') } ) {
        my $tmp_hmm_file = "$worker_temp_directory/$id.hmm";

        if ( $id =~ /^PTHR/ ) {

            #hmmfetch /hps/nobackup/production/ensembl/compara_ensembl/hmm_panther_11/panther_11_1.hmm3 PTHR32044.curated.30.pir > i
            my $cmd_hmm     = $self->param('hmmfetch_exe') . ' ' . $self->param('panther_lib_file') . "  $id > $tmp_hmm_file";
            my $cmd_hmm_out = $self->run_command( $cmd_hmm, { die_on_failure => 1 } );
            unless ( ( -e $tmp_hmm_file ) and ( -s $tmp_hmm_file ) ) {

                # The file is not there / empty ... MEMLIMIT going on ? Let's have
                # a break and give LSF the chance to kill us
                sleep 3;
            }
        }
        elsif ( $id =~ /^TF/ ) {

            #hmmfetch /hps/nobackup/production/ensembl/compara_ensembl/treefam_hmms/hmmer_v3/treefam.hmm3 TF313821 > i
            my $cmd_hmm     = $self->param('hmmfetch_exe') . ' ' . $self->param('treefam_lib_file') . "  $id > $tmp_hmm_file";
            my $cmd_hmm_out = $self->run_command( $cmd_hmm, { die_on_failure => 1 } );
            unless ( ( -e $tmp_hmm_file ) and ( -s $tmp_hmm_file ) ) {

                # The file is not there / empty ... MEMLIMIT going on ? Let's have
                # a break and give LSF the chance to kill us
                sleep 3;
            }
        }

        my $cmd_cat = "cat $tmp_hmm_file >> $seed_hmm_file";
        my $cmd_cat_out = $self->run_command( $cmd_cat, { die_on_failure => 1 } );
        unlink $tmp_hmm_file;

    } ## end foreach my $id ( sort keys ...)

} ## end sub _fetch_and_compose

sub _run_hmmpress {
    my ($self) = @_;

    my $seed_hmm_file     = $self->param('seed_hmm_library_basedir') . '/' . $self->param('seed_hmm_library_name');
    my $seed_hmm_file_h3f = $self->param('seed_hmm_library_basedir') . '/' . $self->param('seed_hmm_library_name') . ".h3f";
    my $seed_hmm_file_h3i = $self->param('seed_hmm_library_basedir') . '/' . $self->param('seed_hmm_library_name') . ".h3i";
    my $seed_hmm_file_h3m = $self->param('seed_hmm_library_basedir') . '/' . $self->param('seed_hmm_library_name') . ".h3m";
    my $seed_hmm_file_h3p = $self->param('seed_hmm_library_basedir') . '/' . $self->param('seed_hmm_library_name') . ".h3p";

    my $cmd_hmm = $self->param('hmmpress_exe') . ' ' . $seed_hmm_file;
    my $cmd_hmm_out = $self->run_command( $cmd_hmm, { die_on_failure => 1 } );

    #All the files (.h3f, .h3i, .h3m & .h3p) should be present.
    unless ( 
            ( -e $seed_hmm_file ) and ( -s $seed_hmm_file )     and
            ( -e $seed_hmm_file_h3f ) and ( -s $seed_hmm_file_h3f ) and
            ( -e $seed_hmm_file_h3i ) and ( -s $seed_hmm_file_h3i ) and
            ( -e $seed_hmm_file_h3m ) and ( -s $seed_hmm_file_h3m ) and
            ( -e $seed_hmm_file_h3p ) and ( -s $seed_hmm_file_h3p )
           ) {

        # The file is not there / empty ... MEMLIMIT going on ? Let's have
        # a break and give LSF the chance to kill us
        sleep 3;
    }
} ## end sub _run_hmmpress

1;

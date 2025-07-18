=head1 LICENSE

See the NOTICE file distributed with this work for additional information
regarding copyright ownership.

Licensed under the Apache License, Version 2.0 (the "License");
you may not use this file except in compliance with the License.
You may obtain a copy of the License at

     http://www.apache.org/licenses/LICENSE-2.0

Unless required by applicable law or agreed to in writing, software
distributed under the License is distributed on an "AS IS" BASIS,
WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
See the License for the specific language governing permissions and
limitations under the License.

=head1 NAME

Bio::EnsEMBL::Compara::RunnableDB::FTPDumps::CheckFTPSkeleton

=cut

package Bio::EnsEMBL::Compara::RunnableDB::FTPDumps::CheckFTPSkeleton;

use strict;
use warnings;

use File::Spec::Functions qw(catdir);

use base ('Bio::EnsEMBL::Compara::RunnableDB::BaseRunnable');


sub param_defaults {
    my ($self) = @_;
    return {
        %{$self->SUPER::param_defaults},
        ftp_locations => {
            LASTZ_NET => ['maf/ensembl-compara/pairwise_alignments'],
            EPO => ['emf/ensembl-compara/multiple_alignments', 'maf/ensembl-compara/multiple_alignments'],
            EPO_EXTENDED => ['emf/ensembl-compara/multiple_alignments', 'maf/ensembl-compara/multiple_alignments'],
            PECAN => ['emf/ensembl-compara/multiple_alignments', 'maf/ensembl-compara/multiple_alignments'],
            GERP_CONSTRAINED_ELEMENT => ['bed/ensembl-compara'],
            GERP_CONSERVATION_SCORE  => ['compara/conservation_scores'],
        },
        copy_ancestral_alleles => 0,
    }
}


sub fetch_input {
    my $self = shift;

    my %ftp_locations = %{ $self->param_required('ftp_locations') };

    my %rel_base_dirs;
    foreach my $method_type ( keys %ftp_locations ) {
        my $method_base_dirs = $self->_mlss_base_dirs($method_type);
        foreach my $method_base_dir (@{$method_base_dirs}) {
            $rel_base_dirs{$method_base_dir} = 1;
        }
    }

    if ($self->param_required('copy_ancestral_alleles')) {
        my $anc_out_base_dir = $self->param_required('anc_output_basedir');
        $rel_base_dirs{$anc_out_base_dir} = 1;
    }

    $self->param('base_dirs', [sort keys %rel_base_dirs]);
}


sub run {
    my $self = shift;

    my $dump_dir = $self->param_required('dump_dir');

    foreach my $base_dir_rel_path ( @{ $self->param('base_dirs') } ) {
        my $base_dir_full_path = catdir($dump_dir, $base_dir_rel_path);
        unless ( -e $base_dir_full_path && -d $base_dir_full_path ) {
            $self->die_no_retry("cannot find FTP base directory '$base_dir_full_path'");
        }
    }
}


sub _mlss_base_dirs {
    my ($self, $method_type) = @_;

    my $mlss_adaptor = $self->compara_dba->get_MethodLinkSpeciesSetAdaptor;
    my @mlsses = map { $mlss_adaptor->fetch_by_dbID($_) } @{ $self->param_required('mlss_ids') };

    my $method_base_dirs = [];
    if (grep { $_->method->type eq $method_type } @mlsses) {
        my $base_dirs_by_method_type = $self->param_is_defined('ftp_locations') ? $self->param('ftp_locations') : [];
        $method_base_dirs = $base_dirs_by_method_type->{$method_type};
    }

    return $method_base_dirs;
}


1;

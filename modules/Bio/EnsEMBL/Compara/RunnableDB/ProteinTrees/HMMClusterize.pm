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

Bio::EnsEMBL::Compara::RunnableDB::ProteinTrees::HMMClusterize

=cut

=head1 SYNOPSIS

Blah

=cut

=head1 DESCRIPTION

Blah

=cut

=head1 CONTACT

  Please email comments or questions to the public Ensembl developers list at <http://lists.ensembl.org/mailman/listinfo/dev>.

  Questions may also be sent to the Ensembl help desk at <http://www.ensembl.org/Help/Contact>.

=cut

=head1 APPENDIX

The rest of the documentation details each of the object methods.
Internal methods are usually preceded with a _

=cut

package Bio::EnsEMBL::Compara::RunnableDB::ProteinTrees::HMMClusterize;

use strict;
use Time::HiRes qw(time gettimeofday tv_interval);
use Bio::EnsEMBL::Compara::RunnableDB::GeneTrees::StoreClusters;
use Data::Dumper;

use base ('Bio::EnsEMBL::Compara::RunnableDB::GeneTrees::StoreClusters');

sub param_defaults {
    return {
            'sort_clusters'         => 1,
            'immediate_dataflow'    => 1,
            'member_type'           => 'protein',
    };
}

sub fetch_input {
    my $self = shift @_;

    $self->param_required('cluster_dir');
}


sub run {
    my $self = shift @_;
    $self->load_hmmer_classifications();
    $self->load_extra_tags($self->param('extra_tags_file')) if $self->param('extra_tags_file');
}


sub write_output {
    my $self = shift @_;
    $self->store_clusterset('default', $self->param('allclusters'));
}

##########################################
#
# internal methods
#
##########################################

sub load_hmmer_classifications {
    my ($self) = @_;
    my $cluster_dir = $self->param('cluster_dir');
    my $division    = $self->param('division'),

    my %allclusters = ();
    $self->param('allclusters', \%allclusters);
    for my $hmmer_clas_file (<$cluster_dir/*>) {
        print STDERR "Reading classifications from $hmmer_clas_file\n";
        open my $hmmer_clas_fh, "<", $hmmer_clas_file or die $!;
        while (<$hmmer_clas_fh>) {
            chomp;
            my ($seq_member_id, $hmm_id, $eval) = split /\t/;
            next if ($hmm_id =~ /\:SF/); ## Avoid panther sub-families e.g. PTHR11353:SF75
            $allclusters{$hmm_id}{members}{$seq_member_id} = 1; ## Avoid duplicates
#            push @{$allclusters{$hmm_id}{members}}, $seq_id;
        }
    }

    for my $model_name (keys %allclusters) {
        ## we filter out clusters singleton clusters
        if (scalar keys %{$allclusters{$model_name}{members}} == 1) {
            delete $allclusters{$model_name};
        } else {
            print STDERR Dumper $allclusters{$model_name};
            # We have to transform the hash into an array-ref
            $allclusters{$model_name}{members} = [keys %{$allclusters{$model_name}{members}}];
            # If it is not a singleton, we add the name of the model to store in the db
            $allclusters{$model_name}{model_name} = $model_name;
            $allclusters{$model_name}{division} = $division if $division;
        }
    }
}

sub load_extra_tags {
    my ($self, $filename) = @_;
    my $allclusters = $self->param('allclusters');

    open my $file_tags, "<", $filename or die $!;
    while (<$file_tags>) {
        chomp;
        my ($model_name, $tag, $value) = split /\t/;
        $allclusters->{$model_name}{$tag} = $value if exists $allclusters->{$model_name};
    }
    close($file_tags);
}

1;

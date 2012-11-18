#
# You may distribute this module under the same terms as perl itself
#
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

  Please email comments or questions to the public Ensembl developers list at <dev@ensembl.org>.

  Questions may also be sent to the Ensembl help desk at <helpdesk@ensembl.org>.

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

    $self->throw('cluster_dir is an obligatory parameter') unless (defined $self->param('cluster_dir'));
}


sub run {
    my $self = shift @_;
    $self->load_hmmer_classifications();
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


    my %allclusters = ();
    $self->param('allclusters', \%allclusters);
    for my $hmmer_clas_file (<$cluster_dir/*>) {
        print STDERR "Reading classifications from $hmmer_clas_file\n";
        open my $hmmer_clas_fh, "<", $hmmer_clas_file or die $!;
        while (<$hmmer_clas_fh>) {
            chomp;
            my ($member_id, $hmm_id, $eval) = split /\t/;
            $allclusters{$hmm_id}{members}{$member_id} = 1; ## Avoid duplicates
#            push @{$allclusters{$hmm_id}{members}}, $seq_id;
        }
    }

    for my $model_name (keys %allclusters) {
        ## we filter out clusters singleton clusters
        if (scalar keys %{$allclusters{$model_name}{members}} == 1) {
            delete $allclusters{$model_name};
        } else {
            # If it is not a singleton, we add the name of the model to store in the db
            print STDERR Dumper $allclusters{$model_name};
            my @members = keys %{$allclusters{$model_name}{members}};
            delete $allclusters{$model_name}{members};
            @{$allclusters{$model_name}{members}} = @members;
            $allclusters{$model_name}{model_name} = $model_name;
        }
    }
}

1;

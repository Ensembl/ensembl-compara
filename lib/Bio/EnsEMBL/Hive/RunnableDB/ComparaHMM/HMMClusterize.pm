#
# You may distribute this module under the same terms as perl itself
#
# POD documentation - main docs before the code

=pod 

=head1 NAME

Bio::EnsEMBL::Hive::RunnableDB::ComparaHMM::HMMClusterize;
#Bio::EnsEMBL::Compara::RunnableDB::ProteinTrees::HMMClusterize

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

package Bio::EnsEMBL::Hive::RunnableDB::ComparaHMM::HMMClusterize;
#package Bio::EnsEMBL::Compara::RunnableDB::ProteinTrees::HMMClusterize;

use strict;
use Time::HiRes qw(time gettimeofday tv_interval);
use Bio::EnsEMBL::Compara::RunnableDB::GeneTrees::StoreClusters;
use Data::Dumper;

use base ('Bio::EnsEMBL::Compara::RunnableDB::GeneTrees::StoreClusters');

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

    #$self->store_and_dataflow_clusterset('default', $self->param('allclusters'));
    # CK: Add additional parameter to tag the tree using methods generated
    #$self->store_clusterset('default', $self->param('allclusters'),'ExtHMM');
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
   
    opendir(DIR, $cluster_dir) or die "Error openining dir '$cluster_dir' : $!";
    my @cluster_subdir = readdir DIR;

    foreach my $cluster_subdir (@cluster_subdir){
    	
	next unless $cluster_subdir =~/^cluster/;
      	my $dir = $cluster_dir.'/'.$cluster_subdir;
      	
	opendir(DIR_2, $dir) or die "Error openining dir '$dir' : $!";

      	while ((my $hmmer_clas_file = readdir (DIR_2))) {

        	next unless $hmmer_clas_file =~/hmmres$/;
        	print STDERR "Reading classifications from $hmmer_clas_file\n" if($self->debug);
		$hmmer_clas_file = $dir.'/'.$hmmer_clas_file;

        	open my $hmmer_clas_fh, "<", $hmmer_clas_file or die $!;

        	while (<$hmmer_clas_fh>) {
            		chomp;
            		my ($member_id, $hmm_id, $eval) = split /\t/;
			#push @{$allclusters{$hmm_id}{members}}, $member_id;
            		$allclusters{$hmm_id}{members}{$member_id} = 1; 
       	 	}	
    	}
    close DIR_2;
    }	
   close DIR;

    for my $model_name (keys %allclusters) {
        ## we filter out clusters singleton clusters
        if (scalar keys %{$allclusters{$model_name}{members}} == 1) {
         #if (scalar @{$allclusters{$model_name}{members}} == 1) {
            delete $allclusters{$model_name};
        } else {
	    print STDERR "MODEL NAME is:$model_name\n";	
            # If it is not a singleton, we add the name of the model to store in the db
            print STDERR Dumper $allclusters{$model_name} if ($self->debug);
            my @members = keys %{$allclusters{$model_name}{members}};
            delete $allclusters{$model_name}{members};
            @{$allclusters{$model_name}{members}} = @members;
#            $allclusters{$model_name}{model_name} = $model_name;
        }
   }
}

1;

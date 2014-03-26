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

Bio::EnsEMBL::Compara::RunnableDB::ComparaHMM::HMMClusterize;

=cut

=head1 CONTACT

Please email comments or questions to the public Ensembl
developers list at <http://lists.ensembl.org/mailman/listinfo/dev>.

Questions may also be sent to the Ensembl help desk at
<http://www.ensembl.org/Help/Contact>.

=cut

=head1 APPENDIX

The rest of the documentation details each of the object methods.
Internal methods are usually preceded with a _

=cut

package Bio::EnsEMBL::Compara::RunnableDB::ComparaHMM::HMMClusterize;

use strict;
use Time::HiRes qw(time gettimeofday tv_interval);
use Bio::EnsEMBL::Compara::RunnableDB::GeneTrees::StoreClusters;
use Data::Dumper;
use base ('Bio::EnsEMBL::Compara::RunnableDB::GeneTrees::StoreClusters');

sub fetch_input {
    my $self = shift @_;

}

sub run {
    my $self = shift @_;

    $self->load_hmmer_classifications();
}


sub write_output {
    my $self = shift @_;
    
    $self->store_clusterset('default', $self->param('allclusters'));
    #$self->store_clusterset('default', $self->param('allclusters'),'ExtHMM');
}

########################
# internal methods
########################
sub load_hmmer_classifications {
    my ($self) = @_;

    my %allclusters = ();
    $self->param('allclusters', \%allclusters);

    # Get statement handler to query all hmm classifications from 'hmm_annot' table
    my $sth  = $self->compara_dba->get_PantherAnnotAdaptor->fetch_all_hmm_annot();
    $sth->execute();

    while (my $res = $sth->fetchrow_arrayref){
        $allclusters{$res->[1]}{members}{$res->[0]} = 1;
    }

    for my $model_name (keys %allclusters) {
        # filter out clusters singleton clusters
        if (scalar keys %{$allclusters{$model_name}{members}} == 1) {
            delete $allclusters{$model_name};
        } else {
            print STDERR "MODEL NAME is:$model_name\n";
            # If it is not a singleton, we add the name of the model to store in the db
            print STDERR Dumper $allclusters{$model_name} if ($self->debug);
            my @members = keys %{$allclusters{$model_name}{members}};
            delete $allclusters{$model_name}{members};
            @{$allclusters{$model_name}{members}} = @members;
        }
    }
}

sub load_hmmer_classifications_2 {
    my ($self) = @_;

    my $cluster_dir = $self->param('cluster_dir');
    $self->throw('cluster_dir is an obligatory parameter') unless (defined $self->param('cluster_dir'));

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
            		$allclusters{$hmm_id}{members}{$member_id} = 1; 
       	 	}	
    	}
    close DIR_2;
    }	
   close DIR;

    for my $model_name (keys %allclusters) {
        ## filter out clusters singleton clusters
        if (scalar keys %{$allclusters{$model_name}{members}} == 1) {
            delete $allclusters{$model_name};
        } else {
	    print STDERR "MODEL NAME is:$model_name\n";	
            # If it is not a singleton, we add the name of the model to store in the db
            print STDERR Dumper $allclusters{$model_name} if ($self->debug);
            my @members = keys %{$allclusters{$model_name}{members}};
            delete $allclusters{$model_name}{members};
            @{$allclusters{$model_name}{members}} = @members;
        }
   }
}

1;

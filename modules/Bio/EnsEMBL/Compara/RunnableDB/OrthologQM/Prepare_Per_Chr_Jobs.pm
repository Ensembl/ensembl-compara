=pod

=head1 NAME
	
	Bio::EnsEMBL::Compara::RunnableDB::OrthologQM::Prepare_Per_Chr_Jobs

=head1 SYNOPSIS

=head1 DESCRIPTION
  Takes as input an hash of reference and non reference species DBIDs and  dnafrag DBIDs as keys and the list of homolog DBIDs as values. 
  Unpacks the hash into seperate hashes each containing a single dnafrag DBID as the key to a list of ordered homologs.

    Example run

  standaloneJob.pl Bio::EnsEMBL::Compara::RunnableDB::OrthologQM::Prepare_Per_Chr_Jobs

=cut

package Bio::EnsEMBL::Compara::RunnableDB::OrthologQM::Prepare_Per_Chr_Jobs;

use strict;
use warnings;
use Data::Dumper;

use base ('Bio::EnsEMBL::Compara::RunnableDB::BaseRunnable');

use Bio::EnsEMBL::Registry;


=head2 param_defaults

    Description : Implements param_defaults() interface method of Bio::EnsEMBL::Hive::Process that defines module defaults for parameters. Lowest level parameters

=cut

sub param_defaults {
	return {
        'ref_species_dbid' => 4,
        'non_ref_species_dbid' => 31,
		'ortholog_info_hashref'	=>	{ '36648' => {
                       '260211' => '542843',
                       '71665' => '712010',
                       '70220' => '712010',
                       '245564' => '1881391',
                       '287636' => '1303681',
                       '70569' => '712010',
                       '357304' => '2012219',
                       '70250' => '712010',
                       '245625' => '1873902'
                       }
                        
                    },

	};
}


=head2 fetch_input

    Description : Implements fetch_input() interface method of Bio::EnsEMBL::Hive::Process that is used to read in parameters and load data.
    Here I need to retrieve the ortholog hash that was data flowed here by Prepare_Othologs.pm 

=cut

sub fetch_input {
#	my $self = shift @_;

#	my $ortholog_hashref = $self->param('ortholog_info_hashref');
}

sub run {
	my $self = shift;

	my $ortholog_hashref = $self->param('ortholog_info_hashref');
#	print " -------------------------------------------------------------Bio::EnsEMBL::Compara::RunnableDB::OrthologQM::Prepare_Per_Chr_Jobs \n\n\n";
#	print Dumper($ortholog_hashref);
	while (my ($ref_dnafragID, $chr_orth_hashref) = each(%$ortholog_hashref)){

		my @orth_sorted; # will contain the orthologs ordered by the dnafrag start position
    		#sorting the orthologs by dnafrag start position
        foreach my $name (sort { int($chr_orth_hashref->{$a}) <=> int($chr_orth_hashref->{$b}) or $a cmp $b } keys %$chr_orth_hashref ) {
    
#            	printf "%-8s %s \n", $name, $orth_hashref->{$name};
            push @orth_sorted, $name;

        }

        my $chr_job = {};
        $chr_job->{$ref_dnafragID} = \@orth_sorted;
#        print Dumper($chr_job);
#        $self->param( 'chr_job', {'chr_job' => $chr_job} );
        $self->dataflow_output_id( {'chr_job' => $chr_job, 'ref_species_dbid' => $self->param('ref_species_dbid'), 'non_ref_species_dbid' => $self->param('non_ref_species_dbid')}, 2 );

		
	}
}

1;



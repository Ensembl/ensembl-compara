=pod

=head1 NAME
	
	Bio::EnsEMBL::Compara::RunnableDB::OrthologQM::Comparison_job_arrays

=head1 SYNOPSIS

=head1 DESCRIPTION
	Takes as input an hash of reference and non reference species DBIDs and one other key. The key is a dnafrag dbid and the values are a list of homology DBIDs ordered by their dnafrag start positions
	Proceeds to take each homolog along with a maximum of 2 neighbouring homologs each to its left and to its rights on the list.
	Used this as inputs for the next job

	Example run

	standaloneJob.pl Bio::EnsEMBL::Compara::RunnableDB::OrthologQM::Comparison_job_arrays
=cut

package Bio::EnsEMBL::Compara::RunnableDB::OrthologQM::Comparison_job_arrays;

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
	    'mlss_ID'=>'100021',
		'ref_species_dbid' =>155,
        'non_ref_species_dbid' => 31,
		'chr_job'	=>	{ '14026395' => [
                          '14803',
                          '14469',
                          '46043'
                        ]
                        },

	};
}


=head2 fetch_input

    Description : Implements fetch_input() interface method of Bio::EnsEMBL::Hive::Process that is used to read in parameters and load data.
    Here I need to retrieve the ordered chromosome ortholog hash that was data flowed here by Prepare_Per_Chr_Jobs.pm 

=cut

sub fetch_input {
#	my $self = shift;
#	$self->param('mlss_ID', $self->param_required('mlss_ID'));
#	my $chr_job = $self->param_required('ortholog_info_hashref');
#	print "##############################\n\n";
#	print Dumper($chr_job);
#	print "##############################\n\n";
#	$self->param('chr_job')
}


sub run {
	my $self = shift;
	my $chr_orth_hashref = $self->param('chr_job');
#	print " -------------------------------------------------------------Bio::EnsEMBL::Compara::RunnableDB::OrthologQM::Comparison_job_arrays \n\n\n";
#	print Dumper($chr_orth_hashref);
	while (my ($ref_chr_dnafragID, $ordered_orth_arrayref) = each(%$chr_orth_hashref) ) {
		my @ordered_orth_array = @$ordered_orth_arrayref;
#		print $#ordered_orth_array , "\n\n";
		foreach my $index (0 .. $#ordered_orth_array ) {
			my $comparion_arrayref = {};
			my ($left1, $left2, $right1, $right2, $query) = (undef,undef,undef,undef);
			
			if ($index == 1){
				$left1 = $ordered_orth_array[0];
			}
			if ($index != 1 and $index != 0){

				$left1 = $ordered_orth_array[$index - 1];
				$left2 = $ordered_orth_array[$index - 2];	
			}
			if ($index == $#ordered_orth_array -1) {
				$right1 = $ordered_orth_array[$index + 1];
			}
			if ($index != $#ordered_orth_array and $index != $#ordered_orth_array -1) {
				$right1 = $ordered_orth_array[$index + 1];
				$right2 = $ordered_orth_array[$index + 2];

			}
			$query = $ordered_orth_array[$index];
#			$ref_chr_dnafragID = $ref_chr_dnafragID;
#			print $left1, " left1 ", $left2, " left2 ", $query, " query ", $right1, " right1 ", $right2, " right2 ", $ref_chr_dnafragID, " ref_chr_dnafragID\n\n" ;
#			$self->param('comparison', {'comparison' => $comparion_arrayref});
			$self->dataflow_output_id( {'left1' => $left1,
										'left2' => $left2,
										'query' => $query,
										'right1' => $right1,
										'right2' => $right2,
										'ref_chr_dnafragID' => $ref_chr_dnafragID,
										'ref_species_dbid' => $self->param('ref_species_dbid'),
										'non_ref_species_dbid' => $self->param('non_ref_species_dbid'),
										'mlss_ID' => $self->param('mlss_ID')}, 2 );

		}
	}
}

1;

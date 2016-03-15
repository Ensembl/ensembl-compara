=pod
=head1 LICENSE

Copyright [1999-2016] Wellcome Trust Sanger Institute and the EMBL-European Bioinformatics Institute

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
    my $self = shift @_;
	return {
        %{ $self->SUPER::param_defaults() },
#	'mlss_ID'=>'100021',
#        'ref_species_dbid' => 155,
#        'non_ref_species_dbid' => 31,
#		'ortholog_info_hashref'	=>	{     '1045569' => {
#                         '46043' => '83505425',
#                         '14469' => '83531457',
#                         '14803' => '83531457',
#                         '14646' => '83531457',
#                         '46120' => '83505425'
#                       }
#                       },

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
	print "Bio::EnsEMBL::Compara::RunnableDB::OrthologQM::Prepare_Per_Chr_Jobs ---------------------------------------------START \n\n" if ( $self->debug );
#	print  $self->param('mlss_ID'), "\n";
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
        print Dumper($chr_job) if ( $self->debug );
#        $self->param( 'chr_job', {'chr_job' => $chr_job} );
        $self->dataflow_output_id( {'chr_job' => $chr_job, 'ref_species_dbid' => $self->param('ref_species_dbid'), 'non_ref_species_dbid' => $self->param('non_ref_species_dbid'), 'mlss_ID' => $self->param('mlss_ID')}, 2 );

		
	}
}

1;



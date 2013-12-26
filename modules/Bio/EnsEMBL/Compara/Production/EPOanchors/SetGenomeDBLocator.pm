=head1 LICENSE

Copyright [1999-2013] Wellcome Trust Sanger Institute and the EMBL-European Bioinformatics Institute

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
=head1 NAME

Bio::EnsEMBL::Compara::Production::EPOanchors::SetGenomeDBLocator

=head1 SYNOPSIS

$exonate_anchors->fetch_input();
$exonate_anchors->write_output(); writes to database

=head1 DESCRIPTION

module to set the locator field in the genome_db table given a set of species and
a locator string(s) for the core dbs of those species

=head1 AUTHOR - compara

This modules is part of the Ensembl project http://www.ensembl.org

Email compara@ebi.ac.uk

=head1 CONTACT

This modules is part of the EnsEMBL project (http://www.ensembl.org)

Questions can be posted to the ensembl-dev mailing list:
dev@ensembl.org


=head1 APPENDIX

The rest of the documentation details each of the object methods. 
Internal methods are usually preceded with a _

=cut
#
package Bio::EnsEMBL::Compara::Production::EPOanchors::SetGenomeDBLocator;

use strict;
use Data::Dumper;
use Bio::EnsEMBL::Registry;

use base ('Bio::EnsEMBL::Compara::RunnableDB::BaseRunnable');


sub fetch_input {
	my ($self) = @_;
	my $sth;
	if($self->param('dont_change_if_locator')) {
		$sth = $self->dbc->prepare("SELECT * FROM genome_db where locator IS NULL OR locator=\"\"");
	} else {
		$sth = $self->dbc->prepare("SELECT * FROM genome_db");
	}
	$sth->execute();
	my @genome_db_ids;
	my %db_names;
        my $genome_dbs = $sth->fetchall_hashref('name');
	foreach my $core_db_url(@{ $self->param('core_db_urls') }){
		Bio::EnsEMBL::Registry->load_registry_from_url( $core_db_url );
		my($user,$host,$port) = $core_db_url=~/mysql:\/\/(\w+)@([\w\.\-]+):(\d+)/ or die "no user/host/port for core dbs\n";
		foreach my $db_adaptor( @{ Bio::EnsEMBL::Registry->get_all_DBAdaptors } ){
			my $dbname = $db_adaptor->dbc->dbname;
			next if(exists($db_names{ $dbname }));
			$db_names{ $dbname }++;
			next unless $dbname=~/_core_/;
			my ($species_name)=$dbname=~/(\w+)_core_/; 
			if(exists($genome_dbs->{$species_name})){
				$genome_dbs->{$species_name}->{'locator'} = "Bio::EnsEMBL::DBSQL::DBAdaptor/host=" . 
				$host . ";port=" . $port . ";user=" . $user . ";dbname=" . $dbname . ";species=" . 
				$species_name . ";disconnect_when_inactive=1";
				push(@genome_db_ids, { genome_db_id => $genome_dbs->{$species_name}->{'genome_db_id'}, species_set_id => $self->param('species_set_id') }); 
			}
		}
	}	 
	my @genome_dbs = values( %$genome_dbs );
	$self->param('genome_dbs', \@genome_dbs);
	$self->param('genome_db_ids', \@genome_db_ids);
}

sub write_output {
	my ($self) = @_;
	return unless $self->param('genome_dbs');
	$self->dataflow_output_id( $self->param('genome_dbs'), 2);
	$self->dataflow_output_id( $self->param('genome_db_ids'), 3);
}

1;


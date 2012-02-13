#ensembl module for bio::ensembl::compara::production::epoanchors::setgenomedblocator
# you may distribute this module under the same terms as perl itself
#
# POD documentation - main docs before the code
=head1 NAME

Bio::EnsEMBL::Compara::Production::EPOanchors::HMMerAnchors 

=head1 SYNOPSIS

$exonate_anchors->fetch_input();
$exonate_anchors->run();
$exonate_anchors->write_output(); writes to database

=head1 DESCRIPTION

Given a database with anchor sequences and a target genome. This modules exonerates 
the anchors against the target genome. The required information (anchor batch size,
target genome file, exonerate parameters are provided by the analysis, analysis_job 
and analysis_data tables  

=head1 AUTHOR - Stephen Fitzgerald

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
	my $sth = $self->dbc->prepare("SELECT * FROM genome_db");
	$sth->execute();
        my $genome_dbs = $sth->fetchall_hashref('name');
	Bio::EnsEMBL::Registry->load_registry_from_url( $self->param('core_db_url') );
	my($user,$host,$port) = $self->param('core_db_url')=~/mysql:\/\/(\w+)@([\w\.\-]+):(\d+)/ or die "no user/host/port for core dbs\n";
	foreach my $db_adaptor( @{ Bio::EnsEMBL::Registry->get_all_DBAdaptors } ){
		my $dbname = $db_adaptor->dbc->dbname;
		next unless $dbname=~/_core_/;
		my ($species_name)=$dbname=~/(\w+)_core_/; 
		if(exists($genome_dbs->{$species_name})){
			$genome_dbs->{$species_name}->{'locator'} = "Bio::EnsEMBL::DBSQL::DBAdaptor/host=" . 
			$host . ";port=" . $port . ";user=" . $user . ";dbname=" . $dbname . ";species=" . 
			$species_name . ";disconnect_when_inactive=1";
		}
	} 
	my @genome_dbs = values( %$genome_dbs );
	$self->param('genome_dbs', \@genome_dbs);
}

sub write_output {
	my ($self) = @_;
	return unless $self->param('genome_dbs');
	$self->dataflow_output_id( $self->param('genome_dbs'), 2);
}

1;


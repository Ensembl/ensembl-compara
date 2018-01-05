=head1 LICENSE

Copyright [1999-2015] Wellcome Trust Sanger Institute and the EMBL-European Bioinformatics Institute
Copyright [2016-2018] EMBL-European Bioinformatics Institute

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

package Bio::EnsEMBL::Compara::Production::EPOanchors::HMMer::LoadConsEles;

use strict;
use warnings;
use Data::Dumper;
use Bio::EnsEMBL::Registry;
use Bio::EnsEMBL::Utils::Exception qw(throw);

use base ('Bio::EnsEMBL::Compara::RunnableDB::BaseRunnable');

sub fetch_input {
	my ($self) = @_;
	my $self_dba = new Bio::EnsEMBL::Compara::DBSQL::DBAdaptor( 
				-host => $self->dbc->host, 
				-pass => $self->dbc->password, 
				-port => $self->dbc->port, 
				-user => $self->dbc->username,
				-dbname => $self->dbc->dbname);
	$self->param('self_dba', $self_dba);
}

sub run {
	my ($self) = @_;
	my $hcs = $self->param_required("high_coverage_species");
	my %HiCvSp;
	foreach my$hcs(@$hcs){
		$HiCvSp{$hcs}++;
	}
	my $compara_dba = $self->compara_dba();
	my $ce_adaptor = $compara_dba->get_adaptor("ConstrainedElement");
	my $mlss_adaptor = $compara_dba->get_adaptor("MethodLinkSpeciesSet");
	my $dnafrag_adaptor = $compara_dba->get_adaptor("DnaFrag");
	my $gab_adaptor = $compara_dba->get_adaptor("GenomicAlignBlock");
	my $genome_db_adaptor = $compara_dba->get_adaptor("GenomeDB");
	my $alignments_mlss = $mlss_adaptor->fetch_by_dbID( $self->param('mlssid_of_alignments') );
	my ($from_ce_id, $to_ce_id) = @{ $self->param('ce_ids') };
	my $self_gab_adaptor = $self->param('self_dba')->get_adaptor("GenomicAlignBlock");
	foreach my $ce_id($from_ce_id..$to_ce_id){
		my $ce = $ce_adaptor->fetch_by_dbID($ce_id);
		next unless($ce);
		my ($high_cover_species, $its_a_repeat);
		for(my$i=0;$i<@{ $ce->alignment_segments };$i++){
			if(exists($HiCvSp{ $ce->alignment_segments->[$i]->[4] })){
				$high_cover_species = $i;
				last;
			}
		}	
		my ($dnafrag_id,$dnafrag_start,$dnafrag_end)= @{ $ce->alignment_segments->[$high_cover_species] };
		my $dnafrag = $dnafrag_adaptor->fetch_by_dbID($dnafrag_id);
		my $gabs = $gab_adaptor->fetch_all_by_MethodLinkSpeciesSet_DnaFrag(
				$alignments_mlss,$dnafrag,$dnafrag_start,$dnafrag_end, 0, 0, 1);
		foreach my $gab(@$gabs){
			$gab->dbID($ce_id);
			eval { $self_gab_adaptor->store($gab) };
			warn $@ if $@;
		}
	}
}

1;


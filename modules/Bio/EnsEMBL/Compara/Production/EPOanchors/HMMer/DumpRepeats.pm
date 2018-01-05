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

package Bio::EnsEMBL::Compara::Production::EPOanchors::HMMer::DumpRepeats;

use strict;
use warnings;
use Data::Dumper;
use Bio::EnsEMBL::Registry;

use base ('Bio::EnsEMBL::Compara::RunnableDB::BaseRunnable');


sub fetch_input {
	my ($self) = @_;
	Bio::EnsEMBL::Registry->load_registry_from_url( $self->param('core_db_url') );
}

sub write_output {
	my ($self) = @_;
	my $dump_file = $self->param('dump_file'); 
	my($species, $assembly) = ($self->param('species'), $self->param('assembly'));
	my $dump_dir = $self->param('repeat_dump_dir') . "/" . $species;
	mkdir( $dump_dir ) or warn $!;
	my $slice_adaptor = Bio::EnsEMBL::Registry->get_adaptor($species, "core", "Slice");
	my $dump_file = $dump_dir . '/' . $assembly . ".repeats";
	return if (-e $dump_file && ! -z $dump_file);
	open(IN, ">$dump_file") or die $!;
	my $rfa = Bio::EnsEMBL::Registry->get_adaptor($species, "core", "RepeatFeature");	
	my $compara_dba = $self->compara_dba();
	my $dnafrag_adaptor = $compara_dba->get_adaptor("DnaFrag");
	foreach my $slice( @{ $slice_adaptor->fetch_all("toplevel") } ){
		my $dnafrag = $dnafrag_adaptor->fetch_by_Slice($slice);
		foreach my $repeat( @{ $rfa->fetch_all_by_Slice($slice) } ){
			print IN join("\t", $dnafrag->dbID, $repeat->start, $repeat->end), "\n";
		}
	}
	close(IN);
}

1;

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

package Bio::EnsEMBL::Compara::Production::EPOanchors::HMMer::FindRepeatGabs;

use strict;
use warnings;
use Data::Dumper;
use Bio::EnsEMBL::Registry;

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
	my $self_dba = $self->param('self_dba');
	my $ga_dnafrag_sth = $self_dba->dbc->prepare('SELECT DISTINCT(ga.dnafrag_id) FROM genomic_align ga INNER JOIN dnafrag df ON ' .
				'ga.dnafrag_id = df.dnafrag_id WHERE df.genome_db_id = ?');
	$ga_dnafrag_sth->execute( $self->param('dbID') );
	my $comp_files = join('/', $self->param('repeat_dump_dir'), $self->param('species'), $self->param('assembly'));
	my $repeats_file = $comp_files . ".repeats";	
	foreach my $dnafrag_id (@{ $ga_dnafrag_sth->fetchall_arrayref }){
		$dnafrag_id = $dnafrag_id->[0];
		my $sth = $self_dba->dbc->prepare('SELECT dnafrag_id, dnafrag_start, dnafrag_end, genomic_align_block_id FROM genomic_align ' .
					'WHERE dnafrag_id = ? ORDER BY dnafrag_id, dnafrag_start');
		$sth->execute($dnafrag_id);
		my $gab_file = $comp_files . ".gabs.$dnafrag_id";
		open(IN, ">$gab_file") or die $!;
		foreach my $gab(@{ $sth->fetchall_arrayref }){
			print join("\t", @$gab), "\n";
			print IN join("\t", @$gab), "\n";
		}
		close(IN);
		my $subset_rep_file = $comp_files . ".reps.$dnafrag_id";
		my $subset_repeats_cmd = "grep \"^$dnafrag_id\" $repeats_file > $subset_rep_file";
		$self->run_command($subset_repeats_cmd);
		my $sth2 = $self_dba->dbc->prepare('UPDATE genomic_align_block SET score = -10000 WHERE genomic_align_block_id = ?');
		my $cmd = $self->param('find_overlaps') . " $subset_rep_file $gab_file --filter | cut -f4 | sort | uniq";
		my $filter_fh;
		open( $filter_fh, "$cmd |" ) or throw("Error opening find_overlaps command: $? $!");
		while(my $hit_gab = <$filter_fh>){
			$sth2->execute($hit_gab);
		}
	
		unlink($gab_file);
		unlink($subset_rep_file);
	}
}

1;


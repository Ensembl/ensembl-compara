#!/usr/bin/env perl
# Copyright [1999-2015] Wellcome Trust Sanger Institute and the EMBL-European Bioinformatics Institute
# Copyright [2016-2017] EMBL-European Bioinformatics Institute
# 
# Licensed under the Apache License, Version 2.0 (the "License");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at
# 
#      http://www.apache.org/licenses/LICENSE-2.0
# 
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.


use strict;
use warnings;
use Data::Dumper;
use Bio::EnsEMBL::Compara::DBSQL::DBAdaptor;

sub print_out {
	die  "argv[0] => db_url, argv[1] => \'genome_db_id1,genome_db_id2,...\', argv[2] => dump_dir, argv[3] => 1:undef\neg. perl dump_genomes2fasta.pl mysql://ensro\@compara3:3306/sf5_compara12way_63 [3] /data/blastdb/Ensembl/compara12way63 1\n";

	
}

print_out unless ($ARGV[0] and $ARGV[1] and $ARGV[2]); 

my $compara_dba = Bio::EnsEMBL::Compara::DBSQL::DBAdaptor->new( -url => $ARGV[0] );

my $genome_db_id_list = [split(',', $ARGV[1])];

my $genome_db_adaptor = $compara_dba->get_genomeDBAdaptor;
my $dnafrag_adaptor = $compara_dba->get_DnaFragAdaptor;


foreach my $genome_db_id( @$genome_db_id_list ){
	my $genome_db = $genome_db_adaptor->fetch_by_dbID( $genome_db_id );
	$genome_db->db_adaptor->dbc->disconnect_when_inactive(0);
	my $dump_dir = $ARGV[2] . "/" . $genome_db->name;
	mkdir($dump_dir) or die;
	open(IN, ">$dump_dir/genome_seq") or die "cant open $dump_dir\n";
	foreach my $ref_dnafrag( @{ $dnafrag_adaptor->fetch_all_by_GenomeDB_region($genome_db, undef, undef, 1) } ){
                if ($ARGV[3]) {
                    if ($ARGV[3] =~ /^-(.*)$/) {
                        next if $ref_dnafrag->cellular_component eq $1;
                    } else {
                        next if $ref_dnafrag->cellular_component ne $ARGV[3];
                    }
                }
		my $header = ">" . join(":", $ref_dnafrag->coord_system_name, $genome_db->assembly, 
			$ref_dnafrag->name, 1, $ref_dnafrag->length, 1); 
		print IN $header, "\n";
		print IN $ref_dnafrag->slice->seq, "\n";
	}
	close(IN);
}


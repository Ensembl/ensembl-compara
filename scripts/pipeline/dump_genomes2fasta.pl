
use strict;
use Data::Dumper;
use Bio::EnsEMBL::Compara::DBSQL::DBAdaptor;

sub print_out {
	die  "argv[0] => db_url, argv[1] => \'[ genome_db_id list ref ]\', argv[2] => dump_dir, argv[3] => 1:undef\neg. perl dump_genomes2fasta.pl mysql://ensro\@compara3:3306/sf5_compara12way_63 [3] /data/blastdb/Ensembl/compara12way63 1\n";

	
}

print_out unless ($ARGV[0] and $ARGV[1] and $ARGV[2]); 

my $compara_dba = Bio::EnsEMBL::Compara::DBSQL::DBAdaptor->new( -url => $ARGV[0] );

my $genome_db_id_list = eval $ARGV[1];

print_out  unless ref($genome_db_id_list) eq "ARRAY";

my $genome_db_adaptor = $compara_dba->get_genomeDBAdaptor;
my $dnafrag_adaptor = $compara_dba->get_DnaFragAdaptor;


foreach my $genome_db_id( @$genome_db_id_list ){
	my $genome_db = $genome_db_adaptor->fetch_by_dbID( $genome_db_id );
	$genome_db->db_adaptor->dbc->disconnect_when_inactive(0);
	my $dump_dir = $ARGV[2] . "/" . $genome_db->name;
	mkdir($dump_dir) or die;
	open(IN, ">$dump_dir/genome_seq") or die "cant open $dump_dir\n";
	foreach my $ref_dnafrag( @{ $dnafrag_adaptor->fetch_all_by_GenomeDB_region($genome_db) } ){
		next unless $ref_dnafrag->is_reference;
		next if ($ref_dnafrag->name=~/MT.*/i and $ARGV[3]);
		my $header = ">" . join(":", $ref_dnafrag->coord_system_name, $genome_db->assembly, 
			$ref_dnafrag->name, 1, $ref_dnafrag->length, 1); 
		print IN $header, "\n";
		print IN $ref_dnafrag->slice->seq, "\n";
	}
	close(IN);
}


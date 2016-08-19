use strict;
use warnings;
use DBI;

# use Bio::EnsEMBL::Registry;
use Bio::EnsEMBL::Compara::DBSQL::DBAdaptor;
use Getopt::Long;

my ( $help, $url, $mlss_id );
GetOptions(
    "help"      => \$help,
    "url=s"     => \$url,
    "mlss_id=i" => \$mlss_id,
);

if ( $help || !$url ){
	print "Usage: epo_stats.pl -url <url_to_epo_db> [-mlss_id <ID> (optional)]"
}

my $dba = Bio::EnsEMBL::Compara::DBSQL::DBAdaptor->go_figure_compara_dba( $url );

my $gdb_a = $dba->get_GenomeDBAdaptor;
my $gdbs  = $gdb_a->fetch_all();

my $mlss_a = $dba->get_MethodLinkSpeciesSetAdaptor;
my $mlss   = $mlss_a->fetch_all_by_method_link_type('EPO');

my @cols = (
	'species_name'. ' 'x13, 'mlss_id', 'genome_len', 'genome_cov(bp)', 
	'g_cov(%)', 'coding_exon_len', 'coding_exon_cov(bp)', 'e_cov(%)'
);

print join("\t", @cols) . "\n";

for my $m ( @$mlss ){
	for my $g ( @$gdbs ) {
		next if ( $g->name eq 'ancestral_sequences' );
		my $this_genomedb_id = $g->dbID;
		my $coding_exon_bp_coverage = $m->get_tagvalue("coding_exon_coverage_$this_genomedb_id");
		my $coding_exon_length      = $m->get_tagvalue("coding_exon_length_$this_genomedb_id");
		my $genome_bp_coverage      = $m->get_tagvalue("genome_coverage_$this_genomedb_id");
		my $genome_length           = $m->get_tagvalue("genome_length_$this_genomedb_id");

		my $genome_cov_perc = sprintf("%.3f", ($genome_bp_coverage/$genome_length) * 100);
		my $exon_cov_perc   = sprintf("%.3f", ($coding_exon_bp_coverage/$coding_exon_length) * 100);

		print join("\t", _pad_name($g->name), $m->dbID, _commify($genome_length), _commify($genome_bp_coverage), $genome_cov_perc, _commify($coding_exon_length), _commify($coding_exon_bp_coverage), $exon_cov_perc);
		print "\n";
	}
}

sub _commify {
    my $text = reverse $_[0];
    $text =~ s/(\d\d\d)(?=\d)(?!\d*\.)/$1,/g;
    return scalar reverse $text
}

sub _pad_name {
	my $name = shift;

	my $padded_len = 25;
	my $pad_needed = $padded_len - length($name);
	my $pad = ' ' x $pad_needed;

	return "$name$pad";
}
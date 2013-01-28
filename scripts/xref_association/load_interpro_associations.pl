#!/bin/env perl
use warnings;
use strict;
use Getopt::Long qw(:config pass_through);
use Bio::EnsEMBL::Registry;
use Bio::EnsEMBL::Utils::Exception qw(throw);
use Bio::EnsEMBL::Compara::DBSQL::XrefAssociationAdaptor;

my ( $reg_conf, $help, $compara_name, $species );

GetOptions( 'help'               => \$help,
			'compara|c=s'        => \$compara_name,
			'species|s=s'        => \$species,
			'reg_conf|regfile=s' => \$reg_conf, );

if ( $help or !$reg_conf or !$compara_name ) {
	pod2usage(1);
}

Bio::EnsEMBL::Registry->load_all($reg_conf);
Bio::EnsEMBL::Registry->set_disconnect_when_inactive(1);

# get compara database
my ($compara) =
  grep { $_->dbc()->dbname() eq $compara_name }
  @{ Bio::EnsEMBL::Registry->get_all_DBAdaptors( -GROUP => 'compara' ) };

my $adaptor =
  Bio::EnsEMBL::Compara::DBSQL::XrefAssociationAdaptor->new($compara);
my $db_name      = 'Interpro';
my $interpro_sql = q/select distinct g.stable_id,i.interpro_ac
from interpro i
join protein_feature pf on (pf.hit_name=i.id)
join translation t using (translation_id)
join transcript tc using (transcript_id)
join gene g using (gene_id) 
join seq_region s on (g.seq_region_id=s.seq_region_id) 
join coord_system c using (coord_system_id)  
where c.species_id=?/;

my @genome_dbs =
  grep { $_->name() ne 'ancestral_sequences' }
  @{ $compara->get_GenomeDBAdaptor()->fetch_all() };
if ( defined $species ) {
	@genome_dbs = grep { $_->name() eq $species } @genome_dbs;
}
for my $genome_db (@genome_dbs) {
	my $dba = $genome_db->db_adaptor();
	print "Processing " . $dba->species() . "\n";
	$adaptor->store_member_associations(
		$dba, $db_name,
		sub {
			my ( $compara, $core, $db_name ) = @_;
			my $member_acc_hash;

			$core->dbc()->sql_helper()->execute_no_return(
				-SQL      => $interpro_sql,
				-CALLBACK => sub {
					my @row = @{ shift @_ };
					push @{ $member_acc_hash->{ $row[0] } }, $row[1];
					return;
				},
				-PARAMS => [ $core->species_id() ] );
			return $member_acc_hash;
		} );
}

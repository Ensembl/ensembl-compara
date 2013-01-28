#!/bin/env perl
use warnings;
use strict;
use Getopt::Long qw(:config pass_through);
use Bio::EnsEMBL::Registry;
use Bio::EnsEMBL::Utils::Exception qw(throw);
use Bio::EnsEMBL::Compara::DBSQL::XrefAssociationAdaptor;

my ( $reg_conf, $division, $help, $compara_name, $db_name, $species, $summary );

GetOptions( 'help'               => \$help,
			'compara|c=s'        => \$compara_name,
			'db_name|n=s'        => \$db_name,
			'species|s=s'        => \$species,
			'reg_conf|regfile=s' => \$reg_conf, );

if ( $help or !$reg_conf or !$compara_name or !$db_name ) {
	pod2usage(1);
}

Bio::EnsEMBL::Registry->load_all($reg_conf);
#Bio::EnsEMBL::Registry->set_disconnect_when_inactive(1);

# get compara database
my ($compara) =
  grep { $_->dbc()->dbname() eq $compara_name }
  @{ Bio::EnsEMBL::Registry->get_all_DBAdaptors( -GROUP => 'compara' ) };

my $adaptor =
  Bio::EnsEMBL::Compara::DBSQL::XrefAssociationAdaptor->new($compara);
my $gdb = $compara->get_GenomeDBAdaptor(); 
my @genome_dbs =  grep {$_->name() ne 'ancestral_sequences'} @{$gdb->fetch_all()};
if(defined $species) {
    @genome_dbs = grep {$_->name() eq $species} @genome_dbs;
}
for my $genome_db (@genome_dbs) {
	my $dba = $genome_db->db_adaptor();
	if(defined $dba) {
		print "Processing " . $dba->species() . "\n";
		$adaptor->store_member_associations( $dba, $db_name );
	}
}

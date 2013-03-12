#ensembl module for bio::ensembl::compara::production::epoanchors::updategenomedblocator
# you may distribute this module under the same terms as perl itself
#
# POD documentation - main docs before the code
=head1 NAME

Bio::EnsEMBL::Compara::Production::EPOanchors::UpdateGenomeDBLocator

=head1 SYNOPSIS

$exonate_anchors->fetch_input();
$exonate_anchors->write_output(); writes to database

=head1 DESCRIPTION

module to set the locator field in the genome_db table given a species and
a locator string for the core db of the species

=head1 AUTHOR - compara

This modules is part of the Ensembl project http://www.ensembl.org

Email dev@ensembl.org

=head1 CONTACT

This modules is part of the EnsEMBL project (http://www.ensembl.org)

Questions can be posted to the ensembl-dev mailing list:
dev@ensembl.org


=head1 APPENDIX

The rest of the documentation details each of the object methods. 
Internal methods are usually preceded with a _

=cut
#
package Bio::EnsEMBL::Compara::Production::EPOanchors::UpdateGenomeDBLocator;

use strict;
use Data::Dumper;
use Bio::EnsEMBL::Registry;
use Bio::EnsEMBL::Compara::DBSQL::DBAdaptor;

use base ('Bio::EnsEMBL::Compara::RunnableDB::BaseRunnable');


sub fetch_input {
 my ($self) = @_;
 my $species_name = $self->param('name');

# load the species db into the registry
 if($species_name eq "ancestral_sequences"){
  my $species_dba = Bio::EnsEMBL::DBSQL::DBAdaptor->new( %{ $self->param('ancestral_db') } );
  Bio::EnsEMBL::Registry->add_DBAdaptor( "$species_name", "core", $species_dba);
 } elsif(my $species_url = $self->param('additional_core_db_urls')->{"$species_name"}){
  $species_url .= "?group=core&species=$species_name";
  Bio::EnsEMBL::Registry->load_registry_from_url( "$species_url" );
 } else {
  Bio::EnsEMBL::Registry->load_registry_from_multiple_dbs( @{ $self->param('main_core_dbs') });
 }
 
# get the species dba from the registry
 my $dba = Bio::EnsEMBL::Registry->get_DBAdaptor("$species_name", "core");
 my ($user, $host, $port, $dbname, $pass) = ($dba->dbc->username, $dba->dbc->host, $dba->dbc->port, $dba->dbc->dbname, $dba->dbc->password);
 $pass = ";pass=".$pass if $pass; # if its "ancestral_sequences"
 my $locator_string = "Bio::EnsEMBL::DBSQL::DBAdaptor/host=";
 $locator_string .= $host.";port=".$port.";user=".$user.$pass.";dbname=".$dbname.";species=".$species_name.";disconnect_when_inactive=1";

 $self->param('locator_string', $locator_string);
}

sub write_output {
 my ($self) = @_;
 return unless $self->param('locator_string');
 my $gdb_a = $self->compara_dba->get_adaptor("GenomeDB");

# store the locator in the db
 foreach my $genome_db (@{ $gdb_a->fetch_all }){
  if($genome_db->name eq $self->param('name')) {
   $genome_db->locator( $self->param('locator_string') );
   $gdb_a->store($genome_db);
  } 
 }
}

1;


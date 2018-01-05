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

Email http://lists.ensembl.org/mailman/listinfo/dev

=head1 CONTACT

This modules is part of the EnsEMBL project (http://www.ensembl.org)

Questions can be posted to the ensembl-dev mailing list:
http://lists.ensembl.org/mailman/listinfo/dev


=head1 APPENDIX

The rest of the documentation details each of the object methods. 
Internal methods are usually preceded with a _

=cut

package Bio::EnsEMBL::Compara::Production::EPOanchors::UpdateGenomeDBLocator;

use strict;
use warnings;
use Data::Dumper;
use Bio::EnsEMBL::Registry;
use Bio::EnsEMBL::Compara::DBSQL::DBAdaptor;
use Bio::EnsEMBL::Compara::Utils::CoreDBAdaptor;
use Bio::EnsEMBL::Utils::Exception qw(throw);

use base ('Bio::EnsEMBL::Compara::RunnableDB::BaseRunnable');


sub fetch_input {
 my ($self) = @_;

 my $genome_db_id = $self->param_required('genome_db_id');
 $self->param('genome_db_adaptor', $self->compara_dba->get_GenomeDBAdaptor);
 my $genome_db = $self->param('genome_db_adaptor')->fetch_by_dbID($genome_db_id);
 $self->param('genome_db', $genome_db);
 my $species_name = $genome_db->name;

# load the species db into the registry
 if($species_name eq "ancestral_sequences" && not $self->param('no_ancestral_sequences')){
  my $species_dba = Bio::EnsEMBL::DBSQL::DBAdaptor->new( %{ $self->param('ancestral_db') } );
  throw('no ancestral_db found') unless $species_dba;
  Bio::EnsEMBL::Registry->add_DBAdaptor( "$species_name", "core", $species_dba);
 } elsif($self->param('additional_core_db_urls') && exists($self->param('additional_core_db_urls')->{"$species_name"})){
   my $species_url = $self->param('additional_core_db_urls')->{"$species_name"};
   $species_url .= "?group=core&species=$species_name";
   if(Bio::EnsEMBL::Registry->get_alias("$species_name")){ # need to remove if species already added from main_core_dbs 
    Bio::EnsEMBL::Registry->remove_DBAdaptor("$species_name", "core");
   }
   Bio::EnsEMBL::Registry->load_registry_from_url( "$species_url" );
  } else {
  Bio::EnsEMBL::Registry->load_registry_from_multiple_dbs(@{ $self->param('main_core_dbs') });
 }
# get the species dba from the registry
 my $dba = Bio::EnsEMBL::Registry->get_DBAdaptor("$species_name", "core");
 $genome_db->locator( $dba->locator );
}

sub write_output {
 my ($self) = @_;

 $self->param('genome_db_adaptor')->store( $self->param('genome_db') );
}

1;

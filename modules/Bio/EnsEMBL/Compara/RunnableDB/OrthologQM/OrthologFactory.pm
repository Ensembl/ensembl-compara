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


=head1 CONTACT

  Please email comments or questions to the public Ensembl
  developers list at <http://lists.ensembl.org/mailman/listinfo/dev>.

  Questions may also be sent to the Ensembl help desk at
  <http://www.ensembl.org/Help/Contact>.

=head1 NAME

Bio::EnsEMBL::Compara::RunnableDB::OrthologQM::OrthologFactory

=head1 DESCRIPTION

	Takes as input the mlss id of the lastz pairwise alignment. 
	Grabs all the homologs 
	from the homologs, only keeps the orthologs
	exports two hashes where the values are the list of orthologs and the keys are the dnafrag DBIDs. one each hash the other species is used as the reference species.

    Example run

  standaloneJob.pl Bio::EnsEMBL::Compara::RunnableDB::OrthologQM::OrthologFactory -goc_mlss_id <goc_mlss id> -compara_db <>

=cut

package Bio::EnsEMBL::Compara::RunnableDB::OrthologQM::OrthologFactory;

use strict;
use warnings;
use Data::Dumper;

use base ('Bio::EnsEMBL::Compara::RunnableDB::BaseRunnable');


=head2 fetch_input

	Description: pull orthologs for species 1 and 2 from EnsEMBL and save as param

=cut

sub fetch_input {
	my $self = shift;
#	$self->debug(4);
	print " Bio::EnsEMBL::Compara::RunnableDB::OrthologQM::Prepare_Orthologs ----------------------------- START\n\n\n" if ( $self->debug );
	print "mlss_id is ------------------  ", $self->param_required('goc_mlss_id'), " ------------- \n\n" if ( $self->debug );
	print Dumper($self->compara_dba) if ( $self->debug );

	my $species1_dbid;
	my $species2_dbid;
	my $mlss = $self->compara_dba->get_MethodLinkSpeciesSetAdaptor->fetch_by_dbID($self->param_required('goc_mlss_id'));
	my $speciesSet_obj= $mlss->species_set();
	my $speciesSet = $speciesSet_obj->genome_dbs();
	
	if ($speciesSet) {
		$species1_dbid = $speciesSet->[0]->dbID();
		$species2_dbid = $speciesSet->[1]->dbID();
	}

        $self->disconnect_from_hive_database;
	my $homologs = $self->compara_dba->get_HomologyAdaptor->fetch_all_by_MethodLinkSpeciesSet($mlss);
	print "This is the returned homologs \n " if ( $self->debug >4);
	print Dumper($homologs) if ( $self->debug >4); 
	my $sms = Bio::EnsEMBL::Compara::Utils::Preloader::expand_Homologies($self->compara_dba->get_AlignedMemberAdaptor, $homologs);
	Bio::EnsEMBL::Compara::Utils::Preloader::load_all_GeneMembers($self->compara_dba->get_GeneMemberAdaptor, $sms);
	$self->param('ref_species_dbid', $species1_dbid);
	$self->param('non_ref_species_dbid', $species2_dbid);
	$self->param( 'ortholog_objects', $homologs );
}

=head2 run

	Description: parse Bio::EnsEMBL::Compara::Homology objects to get start and end positions
	of genes

=cut

sub run {
	my $self = shift;

        $self->disconnect_from_hive_database;

	my $ref_ortholog_info_hashref;
	my $non_ref_ortholog_info_hashref;
	my $c = 0;
	my $ref_species_dbid = $self->param('ref_species_dbid');
	my $non_ref_species_dbid = $self->param('non_ref_species_dbid');
	foreach my $ortholog ( @{ $self->param('ortholog_objects') } ) {
		my $ortholog_dbID = $ortholog->dbID();
		my $ref_gene_member = $ortholog->get_all_GeneMembers($ref_species_dbid)->[0];
		print $ref_gene_member->dbID() , "\n\n" if ( $self->debug >3 );
		die "this homolog  : $ortholog_dbID , appears to not have a gene member for this genome_db_id : $ref_species_dbid \n" unless defined $ref_gene_member;
		my $non_ref_gene_member = $ortholog->get_all_GeneMembers($non_ref_species_dbid)->[0];
		print $non_ref_gene_member->dbID() , "\n\n" if ( $self->debug >3 );
		die "this homolog  : $ortholog_dbID , appears to not have a gene member for this genome_db_id : $non_ref_species_dbid \n" unless defined $non_ref_gene_member;

		if ($ref_gene_member->biotype_group eq 'coding') {
			$ref_ortholog_info_hashref->{$ref_gene_member->dnafrag_id()}{$ortholog->dbID()} = $ref_gene_member->dnafrag_start();
		}

		if ($non_ref_gene_member->biotype_group eq 'coding') {
			$non_ref_ortholog_info_hashref->{$non_ref_gene_member->dnafrag_id()}{$ortholog->dbID()} = $non_ref_gene_member->dnafrag_start();
			$c++;
		}
		
#		last if $c >= 10;
	}

	print " \n remove chromosome or scaffolds with only 1 gene--------------------------START\n\n" if ( $self->debug );
	for my $dnaf_id (keys %$ref_ortholog_info_hashref) {
		if (scalar keys %{$ref_ortholog_info_hashref->{$dnaf_id}} == 1) {

			print Dumper($ref_ortholog_info_hashref->{$dnaf_id}) if ( $self->debug >3 );
			print "\n", $dnaf_id, "\n\n" if ( $self->debug >3 );
			delete $ref_ortholog_info_hashref->{$dnaf_id};
		} 
	}

	for my $nr_dnaf_id (keys %$non_ref_ortholog_info_hashref) {
		if (scalar keys %{$non_ref_ortholog_info_hashref->{$nr_dnaf_id}} == 1) {

			print Dumper($non_ref_ortholog_info_hashref->{$nr_dnaf_id}) if ( $self->debug >3 );
			print "\n", $nr_dnaf_id, "\n\n" if ( $self->debug >3 );
			delete $non_ref_ortholog_info_hashref->{$nr_dnaf_id};
		} 
	}

	print " \n remove chromosome or scaffolds with only 1 gene--------------------------DONE\n\n" if ( $self->debug );
	print $self->param('ref_species_dbid'), "  -------------------------------------------------------------ref_ortholog_info_hashref\n" if ( $self->debug );
	print Dumper($ref_ortholog_info_hashref) if ( $self->debug );

	print $self->param('non_ref_species_dbid'), "  -------------------------------------------------------------non_ref_ortholog_info_hashref\n" if ( $self->debug );
	print Dumper($non_ref_ortholog_info_hashref) if ( $self->debug >3 );

        $self->param('ref_ortholog_info_hashref', $ref_ortholog_info_hashref);
        $self->param('non_ref_ortholog_info_hashref', $non_ref_ortholog_info_hashref);
}


sub write_output {
    my $self = shift;

    $self->dataflow_output_id( {'ortholog_info_hashref' => $self->param('ref_ortholog_info_hashref'), 'ref_species_dbid' => $self->param('ref_species_dbid'), 'non_ref_species_dbid' => $self->param('non_ref_species_dbid')} , 2 );
    $self->dataflow_output_id( {'ortholog_info_hashref' => $self->param('non_ref_ortholog_info_hashref'), 'ref_species_dbid' => $self->param('non_ref_species_dbid'), 'non_ref_species_dbid' => $self->param('ref_species_dbid') } , 2 );
    #$self->dataflow_output_id( {'goc_mlss_id' => $self->param('goc_mlss_id')} , 1);
}

1;


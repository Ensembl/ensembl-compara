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

=pod 

=head1 NAME

Bio::EnsEMBL::Compara::RunnableDB::PairAligner::SetInternalIds

=head1 DESCRIPTION

This module makes the internal ids unique by setting auto_increment to start at method_link_species_set_id * 10**10. This will do this on the following tables: genomic_align_block, genomic_align, genomic_align_group, genomic_align_tree

=head1 CONTACT

Post questions to the Ensembl development list: http://lists.ensembl.org/mailman/listinfo/dev


=head1 APPENDIX

The rest of the documentation details each of the object methods. 
Internal methods are usually preceded with a _

=cut

package Bio::EnsEMBL::Compara::RunnableDB::PairAligner::SetInternalIds;

use strict;
use warnings;

use Bio::EnsEMBL::Utils::Exception qw(throw);

use base ('Bio::EnsEMBL::Compara::RunnableDB::BaseRunnable');

=head2 fetch_input

    Title   :   fetch_input
    Usage   :   $self->fetch_input
    Function:   Fetches input data for gerp from the database
    Returns :   none
    Args    :   none

=cut

sub fetch_input {
  my( $self) = @_;

}

=head2 run

    Title   :   run
    Usage   :   $self->run
    Function:   Run gerp
    Returns :   none
    Args    :   none

=cut

sub run {
    my $self = shift;

    return if ($self->param('skip'));

    $self->setInternalIds();
    

}

=head2 write_output

    Title   :   write_output
    Usage   :   $self->write_output
    Function:   Write results to the database
    Returns :   1
    Args    :   none

=cut

sub write_output {
    my ($self) = @_;

    return 1;
}

#Makes the internal ids unique
sub setInternalIds {
    my $self = shift;
    
    my $dba = $self->compara_dba;
    my $mlss_id;

    if (defined $self->param('method_link_species_set_id')) {
	$mlss_id = $self->param('method_link_species_set_id');
    } elsif ($self->param('method_link_type') && $self->param('genome_db_ids')) {
	my $mlssa = $dba->get_MethodLinkSpeciesSetAdaptor;
	my $mlss = $mlssa->fetch_by_method_link_type_genome_db_ids($self->param('method_link_type'), $self->param('genome_db_ids'));
	if (!defined $mlss) {
	    print "Unable to find method_link_species_set object of " . $self->param('method_link_type') . " for genome_dbs " . $self->param('genome_db_ids') . ". Unable to set internal ids.\n";
	    return;
	}

	$mlss_id = $mlss->dbID;
    } else {
	throw ("Must define either method_link_species_set_id or method_link_type and genome_db_ids");
    }
    
    if (!defined $mlss_id) {
	throw ("Unable to find method_link_species_set_id");
    }

    my $gdbs = $dba->get_GenomeDBAdaptor->fetch_all();
    if (scalar(@$gdbs) > 2) {
        $self->warning('The AUTO_INCREMENT method does not work for collections. IDs will be restored later by "set_internal_ids_collection".');
        return;
    }

    my $table_names;
    if (defined $self->param('tables')) {
	$table_names = $self->param('tables');
    } else {
	#default values
	$table_names->[0] = "genomic_align_block";
	$table_names->[1] = "genomic_align";
	$table_names->[2] = "genomic_align_tree";
    }

    #Set AUTO_INCREMENT to start at the {mlss_id} * 10**10 + 1
    my $index = ($mlss_id * 10**10) + 1;

    foreach my $table (@$table_names) {
	my $sql = "ALTER TABLE $table AUTO_INCREMENT=$index";
	my $sth = $dba->dbc->prepare($sql);
	$sth->execute();
	$sth->finish;
    }
}

1;

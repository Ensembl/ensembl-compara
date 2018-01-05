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

Bio::EnsEMBL::Compara::RunnableDB::SpeciesTree::GroupSpecies

=head1 SYNOPSIS

Splits species into groups, depending on the NCBI taxonomy

=head1 DESCRIPTION
 

=cut

package Bio::EnsEMBL::Compara::RunnableDB::SpeciesTree::GroupSpecies;

use strict;
use warnings;
use base ('Bio::EnsEMBL::Compara::RunnableDB::BaseRunnable');
use Data::Dumper;

$Data::Dumper::Maxdepth = 3;

sub param_defaults {
    my $self = shift;
    return {
        %{$self->SUPER::param_defaults},
        'min_group_size'              => 4,

        # when using group_on_taxonomy, guide trees are generated to stitch the groups back together
        'species_per_group_per_guide' => 4, # how many species from each group should be included?
        'num_guide_trees'             => 10, # how many guide trees to generate
    };
}

sub fetch_input {
	my $self = shift;

	my $collection = $self->param('collection');
	my $species_set_id = $self->param('species_set_id');

	die "Need either collection or species_set_id to be defined!" unless ( $collection || $species_set_id );

	my $dba = $self->compara_dba;
	my $gdb_adaptor = $dba->get_GenomeDBAdaptor;
	my $ss_adaptor = $dba->get_SpeciesSetAdaptor;
	
	my $species_set;
	if ( $collection ) {
		$species_set = $ss_adaptor->fetch_collection_by_name($collection);
	} elsif ( $species_set_id ) {
		$species_set = $ss_adaptor->fetch_by_dbID($species_set_id);
		$self->param('collection', $species_set->name); # set this for file naming later
	}
	my @genome_dbs = @{ $species_set->genome_dbs };

	my @gdb_id_list = map { $_->dbID } @genome_dbs;
	push( @gdb_id_list, @{ $self->param('outgroup_gdbs') } ) if $self->param('outgroup_gdbs');
	@gdb_id_list = sort {$a <=> $b} @gdb_id_list; 
	$self->param( 'dataflow_groups', [{ genome_db_ids => \@gdb_id_list, collection => $self->param('collection')}] );
}

sub _print_gdb_list {
	my ($gdbs, $tag) = @_;

	print "\n\n------- $tag -------\n";
	foreach my $g ( @$gdbs ) {
		print "\t- " . $g->name . " (" . $g->dbID . ")\n";
	}
}

sub print_groups {
	my ( $self, $groups, $tag ) = @_;
	$tag ||= '';

	print "\n\n============ printing groups $tag ==============\n";
	foreach my $k ( keys %$groups ) {
		print "$k => [\n\t";
		print join(", ", map {$_->name . '(' . $_->dbID . ')'} @{ $groups->{$k} });
		print "\n],\n";
	}
	print "=================================================\n";
}

sub write_output {
	my $self = shift;

	my @groups = @{ $self->param_required('dataflow_groups') };
	my $collection = $self->param_required('collection');

	my $num_groups = scalar @groups;
	my $c = 1;
	foreach my $group_set ( @groups ) {
		print "* " . $group_set->{'collection'} . " : " . join(",", @{$group_set->{'genome_db_ids'}}) . "\n" if $self->debug;
		$self->dataflow_output_id( $group_set, 1 );
		$c++;
	}
}

1;
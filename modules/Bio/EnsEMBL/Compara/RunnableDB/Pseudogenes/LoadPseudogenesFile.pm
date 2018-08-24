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
Bio::EnsEMBL::Compara::RunnableDB::ImportAltAlleGroupAsHomologies
=head1 AUTHORSHIP
Ensembl Team. Individual contributions can be found in the GIT log.
=cut

package LoadPseudogenesFile;

use strict;
use warnings;

use Data::Dumper;
use Bio::EnsEMBL::Compara::GeneTree;
use Bio::EnsEMBL::Compara::Homology;
use Bio::EnsEMBL::Compara::Utils::CopyData qw(:row_copy);

use base ('Bio::EnsEMBL::Compara::RunnableDB::BaseRunnable');

## Defines the default parameters for the Job
sub param_defaults 
{
    return 
	{
		'path' => undef,
		'pseudogene_column' => 0,
		'functionnal_gene_column' => 1,
		'delimiter' => ' ',
		'db_conn' => undef,
		'debug' => 0,
    };
}

## This subroutine is called before run in order to check that all the parameters are correct
sub fetch_input {
    my $self = shift @_;

	#Dies if required parameters are not passed in input, or if the file cannont be read
	$self->param_required('path');
	die "No file with such name" unless (-e $self->param('path'));
	die "Cannot read the file" unless (-r $self->param('path'));

	my $db_conn = new Bio::EnsEMBL::Compara::DBSQL::DBAdaptor(-url => $self->param('db_conn')) or die "Could not connect to Master DB";

    # Adaptors in the current Compara DB
	$self->param('master_gene_tree_adaptor', $db_conn->get_GeneTreeAdaptor);
	$self->param('gene_tree_adaptor', $self->compara_dba->get_GeneTreeAdaptor);
	$self->param('gene_member_adaptor', $db_conn->get_GeneMemberAdaptor);
}

sub run 
{
    my $self = shift @_;

	print("Fetching Adaptor... ");
	my $gene_member_adaptor = $self->param('gene_member_adaptor');
	my $master_gene_tree_adaptor = $self->param('master_gene_tree_adaptor');
	my $gene_tree_adaptor = $self->param('gene_tree_adaptor');
	print("Done\n");

	my $db_conn = $self->param('db_conn');


	my %tree_hash;
	my %gene_hash;
	my $tree;
	my @genes;
	my $pseudogene_stable_id;
	my $parent_stable_id;
	my $functionnal_gene;
	my $pseudogene;

	my $execs = 0;
	my $missing_trees = 0;
	open( my $fd, '<', $self->param('path'));	

	## For each member line of the parametrer file
    while(defined(my $line = <$fd>))
	{
		chomp($line);
		## Fecthing informations fr om the file
		@genes = split($self->param('delimiter'), $line);
	 	$pseudogene_stable_id = $genes[$self->param('pseudogene_column')];
		$parent_stable_id = $genes[$self->param('functionnal_gene_column')];

		## Fecthing genes from stable IDs
		$functionnal_gene = $gene_member_adaptor->fetch_by_stable_id($parent_stable_id);
		$pseudogene = $gene_member_adaptor->fetch_by_stable_id($parent_stable_id);

		print "Could not find pseudogene. $pseudogene_stable_id " if(!defined($pseudogene));
		print "Could not find parent Gene $parent_stable_id" if(!defined($functionnal_gene));

		## Skip unless both the pseudogene and the parent gene are in the database and the pseudogene and the parent gene are different	
		next unless defined($pseudogene) && defined($functionnal_gene) && $pseudogene_stable_id ne $parent_stable_id;

		## Checking if the two members have changed, in order to save a MLSS fetching
		## Fetching the root of the tree in the Master db
		$tree = $master_gene_tree_adaptor->fetch_default_for_Member($functionnal_gene);

		if(!defined($tree))
		{
			print "Could not tree find containing Gene $parent_stable_id\n" if($self->param('debug'));
			$missing_trees ++;			
			next unless defined($tree);
		}
		my $root_id = $tree->root_id;
		my $tree_stable_id = $tree->stable_id;
		if (!(exists($tree_hash{$tree_stable_id})))
		{
			my @array = ();
			$tree_hash{$tree_stable_id}= \@array;
		}
		if (!(exists($gene_hash{$pseudogene_stable_id})))
		{
			my @array = ();
			$gene_hash{$pseudogene_stable_id}= \@array;
		}
		push $tree_hash{$tree_stable_id}, "$pseudogene_stable_id $parent_stable_id";
		push $gene_hash{$pseudogene_stable_id}, $tree_stable_id unless grep({$_ eq $tree_stable_id} @{$gene_hash{$pseudogene_stable_id}});
		$tree->release_tree();
    }

	print "A Total of ", $missing_trees, " homologies have been discarded because no parent tree exists";

	foreach my $key(keys %gene_hash)
	{
		if(scalar @{$gene_hash{$key}} == 1)
		{
		
		}
		else
		{
			print($key, " can be placed in ", scalar @{$gene_hash{$key}}, " differents trees.\n");
		}
	}

	foreach my $key(keys %tree_hash)
	{
		my $master_tree = $master_gene_tree_adaptor->fetch_by_stable_id($key);
		next unless defined($master_tree);
		my $root_id = $master_tree->root_id;

		$tree = $gene_tree_adaptor->fetch_by_stable_id($key);
		$tree = $tree->alternative_trees->{'copy'} if defined($tree);
		## If the tree exists in the database and the copy tree exists in the database :
		$self->dataflow_output_id({'protein_tree_stable_id' => $key, 'homologies' => $tree_hash{$key}, 
					'copy_tree' => !defined($tree), 'gene_tree_id' => $root_id}, 2);
		$tree->release_tree() if defined($tree);
		$master_tree->release_tree();
	}
}

1;

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

Bio::EnsEMBL::Compara::RunnableDB::SpeciesTree::GraftSubtrees

=head1 SYNOPSIS

Given a set of trees, graft subtrees together

=head1 DESCRIPTION

	

=cut

package Bio::EnsEMBL::Compara::RunnableDB::SpeciesTree::GraftSubtrees;

use strict;
use warnings;
use Bio::EnsEMBL::Compara::Graph::NewickParser;
use File::Basename;
# use Statistics::Basic qw(mean);
use List::Util qw( min );

use Data::Dumper;

use base ('Bio::EnsEMBL::Compara::RunnableDB::BaseRunnable');

sub fetch_input {
	my $self = shift;

}

sub run {
	my $self = shift;

	my %trees = %{ $self->param('trees')}; # assuming { group_id => { tree => newick_string, outgroup => outgroup_id } }

	my $root_tree = $trees{root}->{tree};
	my $final_tree = $root_tree;

	print "original tree: $final_tree\n" if $self->debug;

	while ( $final_tree =~ /mrg_([0-9]+)/ ) {
		my $merged_group_key = $1;
		last unless $merged_group_key;

		my $tree_to_merge = $trees{$merged_group_key}->{tree};

		# reroot the tree and then remove the outgroup
		my $outgroup_name = $trees{$merged_group_key}->{outgroup};
		print "\n---------------------------------------------------------\n\n" if $self->debug;
		print "parsing group $merged_group_key [[ $tree_to_merge ]]\n" if $self->debug;
		
		print "    rerooting on $outgroup_name\n" if $self->debug;
		my $rooted_newick = $self->_root_newick_on_outgroup($tree_to_merge, $outgroup_name);
		print "    rooted: $rooted_newick\n" if $self->debug;
		my $pruned_rooted_newick = $self->_prune_outgroup_from_newick($rooted_newick, $outgroup_name);
		print "    pruned: $pruned_rooted_newick\n" if $self->debug;

		# graft subtree into full tree
		# $final_tree =~ s/mrg_$merged_group_key:$branch_len_to_group/$pruned_rooted_newick:$adjusted_brlen/;
		$final_tree =~ s/mrg_$merged_group_key/$pruned_rooted_newick/;
		print "    final : $final_tree\n\n" if $self->debug;
	}

	# do final reroot on overall outgroup
	my $overall_outgroup = $self->param('outgroup_genome_db_id');
	$final_tree = $self->_root_newick_on_outgroup( $final_tree, "gdb$overall_outgroup" ) if defined $overall_outgroup;

	print "ultimate tree (?) : $final_tree\n\n";

	$self->param('final_tree', $final_tree);
}

sub write_output {
	my $self = shift;

	my $final_tree = $self->param('final_tree');
	my $outfile = $self->param('output_file');

	if ( $outfile ) {
		$self->_spurt($outfile, $final_tree);
		$self->input_job->autoflow(0);
		$self->complete_early("Final tree written to $outfile");
	} else {
		$self->dataflow_output_id( { 
			tree => $final_tree, 
			mash_dist_file => $self->param('mash_dist_file') 
		}, 1 );
	}
}

sub _root_newick_on_outgroup {
	my ( $self, $newick, $outgroup ) = @_;

	open( my $tree_fh, '<', \$newick );
	my $treeio_in = Bio::TreeIO->new(-format => 'newick', -fh => $tree_fh);
	my $unroot_tree = $treeio_in->next_tree;
	my $outgroup_node = $unroot_tree->find_node($outgroup);
	die "Cannot find outgroup '$outgroup' in tree:\n\t$newick\n" unless defined $outgroup_node;

	# first reroot on outgroup
	my $root_tree = $unroot_tree;
	$root_tree->reroot($outgroup_node);


	my $final_nwk = $self->_fix_bioperl_rooting( $self->_get_newick_from_tree($root_tree) );

	return $final_nwk;
}

sub _min_branch_length_to_root {
	my ($self, $newick) = @_;

	open( my $tree_fh, '<', \$newick );
	my $treeio_in = Bio::TreeIO->new(-format => 'newick', -fh => $tree_fh);
	my $tree = $treeio_in->next_tree;

	# get mean distance from first node to tip
	my @distances = map { $_->depth } $tree->get_leaf_nodes;
	# my @distances;
	# foreach my $leaf_node ( $root_tree->get_leaf_nodes ) {
	# 	push(@distances, $leaf_node->depth);
	# }
	my $min_brlen = min @distances;
	print "\tmin of [" . join(', ', @distances) . "] = $min_brlen\n";

	return $min_brlen;
}

sub _get_newick_from_tree {
	my ( $self, $tree ) = @_;

	my $nwk;
	open( my $nwk_fh, '>', \$nwk );
	my $treeio_out = Bio::TreeIO->new(-format => 'newick', -fh => $nwk_fh);
	$treeio_out->write_tree($tree);	

	return $nwk;
}

sub _fix_bioperl_rooting {
	my ($self, $newick) = @_;
	chomp $newick;
	# bioperl does not root trees in a way that is readable by other softwares (e.g. figtree)
	# it appears that figtree assigns half of the original branch length of the outgroup to the newly bifurated branches

	# regexes are acting very oddly on this $newick string - split the info off manually...
	my @parts = split(':', $newick);
	my $og_info = pop @parts;
	my $newick_no_og = join(':', @parts);

	$og_info =~ s/;$//;
	my ( $og_brlen, $og_name ) = split(/\)/, $og_info);

	my $split_brlen = $og_brlen/2;
	return "$newick_no_og:$split_brlen,$og_name:$split_brlen);";
}

# assumes tree is rooted on outgroup
sub _prune_outgroup_from_newick {
	my ( $self, $rooted_nwk, $outgroup ) = @_;

	# $newick =~ s/^\(\(/(/;
	# $newick =~ s/\)[a-zA-Z\d\.:,]+\);$/)/;

	#((chinchilla_lanigera:0.094862,(rattus_norvegicus:0.063643,(mus_musculus:0.020907,mus_caroli:0.020813):0.039388):0.054782):0.094868)nomascus_leucogenys;
	# idea is to capture everything between the second '(' and its closing bracket i.e second last ')'

	# find second occurrance of '('
	my $first_brace_index  = index($rooted_nwk, '(');
	my $opening_index = index($rooted_nwk, '(', $first_brace_index+1);

	# find second last occur of ')'
	my $rev_nwk = reverse $rooted_nwk;
	my $last_brace_index   = index($rev_nwk, ')');
	my $penult_rev_brace_index = index($rev_nwk, ')', $last_brace_index+1);
	my $closing_index = length($rooted_nwk) - $penult_rev_brace_index;

	my $substr_len = $closing_index - $opening_index;
	return substr $rooted_nwk, $opening_index, $substr_len;
}

1;
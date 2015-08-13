package Bio::EnsEMBL::Compara::RunnableDB::ncRNAtrees::NCStoreTree;

use strict;
use warnings;

use Bio::EnsEMBL::Compara::Graph::NewickParser;

use base ('Bio::EnsEMBL::Compara::RunnableDB::GeneTrees::StoreTree');



sub store_newick_into_nc_tree {
    my ($self, $tag, $newick_file) = @_;

    print STDERR "load from file $newick_file\n" if($self->debug);
    my $newick = $self->_slurp($newick_file);
    $self->param('output_clusterset_id', lc $tag);
    $self->store_alternative_tree($newick, $tag, $self->param('gene_tree'), undef, 1);
    if (defined($self->param('model'))) {
        my $bootstrap_tag = $self->param('model') . "_bootstrap_num";
        $self->param('gene_tree')->store_tag($bootstrap_tag, $self->param('bootstrap_num'));
    }
}


1;

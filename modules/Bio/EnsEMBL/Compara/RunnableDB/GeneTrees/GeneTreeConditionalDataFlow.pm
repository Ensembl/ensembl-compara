=pod 

=head1 NAME

Bio::EnsEMBL::Compara::RunnableDB::GeneTrees::GeneTreeConditionalDataFlow

=head1 DESCRIPTION

Version of ConditionalDataFlow that exposes all the gene-tree root-tags as parameters

=head1 LICENSE

    Copyright [1999-2015] Wellcome Trust Sanger Institute and the EMBL-European Bioinformatics Institute

    Licensed under the Apache License, Version 2.0 (the "License"); you may not use this file except in compliance with the License.
    You may obtain a copy of the License at

         http://www.apache.org/licenses/LICENSE-2.0

    Unless required by applicable law or agreed to in writing, software distributed under the License
    is distributed on an "AS IS" BASIS, WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
    See the License for the specific language governing permissions and limitations under the License.

=head1 CONTACT

    Please subscribe to the Hive mailing list:  http://listserver.ebi.ac.uk/mailman/listinfo/ehive-users  to discuss Hive-related questions or to be notified of our updates

=cut


package Bio::EnsEMBL::Compara::RunnableDB::GeneTrees::GeneTreeConditionalDataFlow;

use strict;
use warnings;

use base ('Bio::EnsEMBL::Compara::RunnableDB::ConditionalDataFlow');


=head2 param_defaults

    Description : "defaults" is expected to be there. It contains the default values of the parameters that could be missing

=cut

sub param_defaults {
    my $self = shift;
    return {
        %{ $self->SUPER::param_defaults() },
        defaults => {},
    }
}


=head2 fetch_input

    Description : Loads all the gene-tree tags with the "tree_" prefix, and the tree itself in "gene_tree".
                  Then, it passes the control back to the super-class.

    param('gene_tree_id'): The root_id of the tree to read the paramters of

=cut

sub fetch_input {
    my $self = shift;

    my $gene_tree = $self->compara_dba->get_GeneTreeAdaptor->fetch_by_dbID($self->param_required('gene_tree_id'));
    $self->param('gene_tree', $gene_tree);

    my $defaults = $self->param_required('defaults');
    foreach my $tag (keys %$defaults) {
        $self->param($tag, $defaults->{$tag});
    }

    foreach my $tag ($gene_tree->get_all_tags()) {
        warn sprintf("setting %s=%s\n", 'tree_'.$tag, $gene_tree->get_value_for_tag($tag)) if $self->debug;
        $self->param('tree_'.$tag, $gene_tree->get_value_for_tag($tag));
    }

    return $self->SUPER::fetch_input();
}

1;

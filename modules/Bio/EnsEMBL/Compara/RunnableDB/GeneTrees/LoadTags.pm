=pod 

=head1 NAME

Bio::EnsEMBL::Compara::RunnableDB::GeneTrees::LoadTags

=head1 DESCRIPTION

Version of ConditionalDataFlow that exposes all the gene-tree root-tags as parameters

=head1 LICENSE

    See the NOTICE file distributed with this work for additional information
    regarding copyright ownership.

    Licensed under the Apache License, Version 2.0 (the "License"); you may not use this file except in compliance with the License.
    You may obtain a copy of the License at

         http://www.apache.org/licenses/LICENSE-2.0

    Unless required by applicable law or agreed to in writing, software distributed under the License
    is distributed on an "AS IS" BASIS, WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
    See the License for the specific language governing permissions and limitations under the License.

=head1 CONTACT

    Please subscribe to the Hive mailing list:  http://listserver.ebi.ac.uk/mailman/listinfo/ehive-users  to discuss Hive-related questions or to be notified of our updates

=cut


package Bio::EnsEMBL::Compara::RunnableDB::GeneTrees::LoadTags;

use strict;
use warnings;

use base ('Bio::EnsEMBL::Compara::RunnableDB::BaseRunnable');

=head2 param_defaults

    Description : This runnable is used to inject the tags into the job parameters stack.
                  e.g. It can be used to load the tag aln_num_of_patterns to be used by the raxml_decision analysis. 
                  This runnable must be used upstream the target analysis, loading the tags and data-flowing them to the target analysis.

                  #e.g. Tags and default values must be declared in the pipeline confuration file:
                  #
                  -parameters =>    {
                                        'tags'  => {
                                            'best_fit_model_family      => 'JTT',
                                            'best_fit_model_parameter'  => 'IGF',
                                            'aln_num_of_patterns'       => '777',
                                        }
                                    }

                 Default values are used in case a tag is not found in the database.

=cut


=head2 fetch_input

    Description : Loads the tags passesd by parameters
                  Then, it passes the control back to the super-class.

    param('gene_tree_id'): The root_id of the tree to read the tags from.

=cut

sub fetch_input {
    my $self = shift;

    my $gene_tree = $self->compara_dba->get_GeneTreeAdaptor->fetch_by_dbID($self->param_required('gene_tree_id')) || die "Cound not fetch tree: " . $self->param_required('gene_tree_id');

    my $tags = $self->param_required('tags');

    for my $tag (keys %{$tags}) {
        if ( $gene_tree->has_tag($tag) ) {
            print "Loading tag:$tag, with value:".$gene_tree->get_value_for_tag($tag)."\n" if ($self->debug);
            $self->param( 'tree_'.$tag, $gene_tree->get_value_for_tag($tag));
        }else{
            print "Loading default value for tag:$tag\n" if ($self->debug);
            $self->warning("tag: $tag not found. Using defaults");
            $self->param( 'tree_'.$tag, $tags->{$tag});
        }
    }
}

1;

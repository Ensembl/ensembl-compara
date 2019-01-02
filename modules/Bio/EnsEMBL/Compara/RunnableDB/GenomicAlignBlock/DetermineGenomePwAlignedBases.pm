=head1 LICENSE

Copyright [1999-2015] Wellcome Trust Sanger Institute and the EMBL-European Bioinformatics Institute
Copyright [2016-2019] EMBL-European Bioinformatics Institute

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


=pod 

=head1 NAME

Bio::EnsEMBL::Compara::RunnableDB::DetermineGenomePWwlignedBases

=head1 DESCRIPTION


=cut

package Bio::EnsEMBL::Compara::RunnableDB::GenomicAlignBlock::DetermineGenomePwAlignedBases;

use strict;
use warnings;
use List::Util qw(reduce);
use Data::Dumper;
use base ('Bio::EnsEMBL::Compara::RunnableDB::BaseRunnable');

sub param_defaults {
    return {
#    	'from_genome_db_id'     => 148 ,
#    	'pw_stats' 				=> {'37' =>[3034,4003,1236,798,50], '38' => [3034,4003,1236,798,50]},

    }
}

sub fetch_input {
    my $self = shift @_;
    my $mlss_adap = $self->compara_dba()->get_MethodLinkSpeciesSetAdaptor;
    my $mlss = $mlss_adap->fetch_by_dbID( $self->param_required('mlss_id') );
    my $species_tree = $mlss->species_tree();
    my $species_tree_root = $species_tree->root();
    my $node = $species_tree_root->find_leaves_by_field('genome_db_id', $self->param('from_genome_db_id') )->[0];
    print "this is the node id : ", $node->node_id, "\n \n" if ( $self->debug >3 );
    $self->param('node', $node);

}

sub run {
	my $self = shift @_;
	my @pw_genomes = keys %{$self->param_required('pw_stats')};
	print "DEBUG : run : pw genomes \n";
	print Dumper(\@pw_genomes);
	foreach my $genome (@pw_genomes) {
		my $tag = "genome_coverage_$genome";
		my $genome_pwscore_with_query = reduce{$a+$b} @{$self->param_required('pw_stats')->{$genome}};
		print "\n from genome : ", $self->param_required('from_genome_db_id'), ", to genome : $genome , pw aligned bases : $genome_pwscore_with_query \n node_id : ", $self->param('node')->node_id, " \n\n" if ( $self->debug >3 );
		$self->param('node')->store_tag($tag, $genome_pwscore_with_query);
	}
}

1;
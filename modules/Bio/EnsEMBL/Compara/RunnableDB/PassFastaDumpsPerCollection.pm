=head1 LICENSE

See the NOTICE file distributed with this work for additional information
regarding copyright ownership.

Licensed under the Apache License, Version 2.0 (the "License");
you may not use this file except in compliance with the License.
You may obtain a copy of the License at

     http://www.apache.org/licenses/LICENSE-2.0

Unless required by applicable law or agreed to in writing, software
distributed under the License is distributed on an "AS IS" BASIS,
WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
See the License for the specific language governing permissions and
limitations under the License.

=head1 NAME

Bio::EnsEMBL::Compara::RunnableDB::PassFastaDumpsPerCollection

=head1 DESCRIPTION

Factory to flow the list of fasta files per collection.

=cut

package Bio::EnsEMBL::Compara::RunnableDB::PassFastaDumpsPerCollection;

use warnings;
use strict;
use Bio::EnsEMBL::Registry;
use Bio::EnsEMBL::Compara::DBSQL::DBAdaptor;

use base ('Bio::EnsEMBL::Compara::RunnableDB::BaseRunnable');

sub fetch_input {
    my $self = shift;

    my $base_dir = $self->param('symlink_dir');
    my $ss_adap  = $self->compara_dba->get_SpeciesSetAdaptor;
    my $collections = $ss_adap->fetch_all_current_collections;
    my %collection_set;
    foreach my $collection ( @$collections ) {
        my $gdbs = $collection->genome_dbs;
        my $collection_name = $collection->name;
        $collection_name =~ s/^collection-//;
        my @dir_locs = map {$_->_get_members_dump_path($self->param('ref_member_dumps_dir'))} @$gdbs;
        my $symlink_dir = $base_dir . $collection_name;
        $collection_set{$symlink_dir} = [ @dir_locs ] unless $collection_name =~ /shared/;
    }
    $self->param('fasta_collections', \%collection_set);
}

sub write_output {
    my $self = shift;

    my $collection_set = $self->param('fasta_collections');
    foreach my $dir ( sort keys %$collection_set ) {

        my @fastas = @{$collection_set->{$dir}};
        foreach my $fasta_file ( @fastas ) {
            $self->dataflow_output_id( { 'symlink_dir' => $dir, 'target_file' => $fasta_file, 'cleanup_symlinks' => 1 }, 1 );
        }
        $self->dataflow_output_id({ 'symlink_dir' => $dir }, 2);
    }
}

1;

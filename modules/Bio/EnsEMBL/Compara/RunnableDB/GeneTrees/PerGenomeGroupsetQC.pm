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

Bio::EnsEMBL::Compara::RunnableDB::GeneTrees::PerGenomeGroupsetQC

=head1 DESCRIPTION

This Analysis will take the sequences from a cluster, the cm from
nc_profile and run a profiled alignment, storing the results as
cigar_lines for each sequence.

=head1 SYNOPSIS

my $db           = Bio::EnsEMBL::Compara::DBAdaptor->new($locator);
my $sillytemplate = Bio::EnsEMBL::Compara::RunnableDB::GeneTrees::PerGenomeGroupsetQC->new
  (
   -db         => $db,
   -input_id   => $input_id,
   -analysis   => $analysis
  );
$sillytemplate->fetch_input(); #reads from DB
$sillytemplate->run();
$sillytemplate->write_output(); #writes to DB

=head1 AUTHORSHIP

Ensembl Team. Individual contributions can be found in the GIT log.

=head1 APPENDIX

The rest of the documentation details each of the object methods.
Internal methods are usually preceded with an underscore (_)

=cut

package Bio::EnsEMBL::Compara::RunnableDB::GeneTrees::PerGenomeGroupsetQC;

use strict;
use warnings;

use base ('Bio::EnsEMBL::Compara::RunnableDB::BaseRunnable');


sub fetch_input {
    my $self = shift @_;

    my $genome_db_id            = $self->param_required('genome_db_id');
    my $this_genome_db          = $self->compara_dba->get_GenomeDBAdaptor->fetch_by_dbID($genome_db_id);
    my $this_species_tree       = $self->compara_dba->get_SpeciesTreeAdaptor->fetch_by_method_link_species_set_id_label($self->param_required('mlss_id'), 'default');
    my $this_species_tree_node  = $this_species_tree->root->find_leaves_by_field('genome_db_id', $genome_db_id)->[0];

    $self->param('species_tree_node', $this_species_tree_node);

    my $this_orphans            = $self->fetch_gdb_orphan_genes($self->compara_dba, $genome_db_id);
    my $total_orphans_num       = scalar keys (%$this_orphans);
    my $total_num_genes         = scalar @{ $self->compara_dba->get_GeneMemberAdaptor->fetch_all_by_GenomeDB($genome_db_id) };

    $self->param('total_orphans_num', $total_orphans_num);
    $self->param('total_num_genes',   $total_num_genes);

    my $reuse_this = 0;
    if ($self->param('reuse_ss_id')) {
        my $reuse_ss = $self->compara_dba()->get_SpeciesSetAdaptor->fetch_by_dbID($self->param('reuse_ss_id'));
        if (grep {$_->dbID == $genome_db_id} @{$reuse_ss->genome_dbs}) {
            $reuse_this = 1;
        }
    }
    $self->param('reuse_this', $reuse_this);
    return unless $reuse_this;

    my $reuse_compara_dba       = $self->get_cached_compara_dba('reuse_db');     # may die if bad parameters
    my $old_genome_db           = $reuse_compara_dba->get_GenomeDBAdaptor->fetch_by_dbID($genome_db_id);        # since the species has been reused, the genome_db_id *must* be present

    my $reuse_orphans           = $self->fetch_gdb_orphan_genes($reuse_compara_dba, $genome_db_id);
    my %common_orphans = ();
    my %new_orphans = ();
    foreach my $this_orphan_id (keys %$this_orphans) {
        if($reuse_orphans->{$this_orphan_id}) {
            $common_orphans{$this_orphan_id} = 1;
        } else {
            $new_orphans{$this_orphan_id} = 1;
        }
    }
    $self->param('common_orphans_num', scalar keys (%common_orphans));
    $self->param('new_orphans_num',    scalar keys (%new_orphans));
}


# run() is a good place to do some actual QC

sub write_output {

    my $self = shift @_;

    my $species_tree_node       = $self->param('species_tree_node');

    $species_tree_node->store_tag('nb_genes',               $self->param('total_num_genes'));
    $species_tree_node->store_tag('nb_genes_in_tree',       $self->param('total_num_genes')-$self->param('total_orphans_num'));
    $species_tree_node->store_tag('nb_orphan_genes',        $self->param('total_orphans_num'));

    return unless $self->param('reuse_this');

    $species_tree_node->store_tag('nb_new_orphan_genes',    $self->param('new_orphans_num'));
    $species_tree_node->store_tag('nb_common_orphan_genes', $self->param('common_orphans_num'));

}


sub fetch_gdb_orphan_genes {
    my ($self, $given_compara_dba, $genome_db_id) = @_;

    my %orphan_stable_id_hash = ();

    my $sql = 'SELECT mg.stable_id FROM gene_member mg LEFT JOIN gene_tree_node gtn ON (mg.canonical_member_id = gtn.seq_member_id) WHERE gtn.seq_member_id IS NULL AND mg.genome_db_id = ?';

    my $sth = $given_compara_dba->dbc->prepare($sql);
    $sth->execute($genome_db_id);

    while(my ($member) = $sth->fetchrow()) {
        $orphan_stable_id_hash{$member} = 1;
    }

    return \%orphan_stable_id_hash;
}

1;

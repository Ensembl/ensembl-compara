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

Bio::EnsEMBL::Compara::RunnableDB::ImportAltAlleGroupAsHomologies

=cut

package Bio::EnsEMBL::Compara::RunnableDB::ImportAltAlleGroupAsHomologies;

use strict;
use warnings;

use Data::Dumper;
use Bio::EnsEMBL::Compara::GeneTree;
use Bio::EnsEMBL::Compara::Homology;
use Bio::EnsEMBL::Compara::Utils::CopyData qw(:row_copy);

use base ('Bio::EnsEMBL::Compara::RunnableDB::BaseRunnable');


sub param_defaults {
    return {
        'dry_run'       => 0,
        'method_type'   => 'ENSEMBL_PROJECTIONS',
    };
}


sub fetch_input {
    my $self = shift @_;

    $self->param_required('alt_allele_group_id');
    $self->require_executable('mafft_exe');

    # Adaptors in the current Compara DB
    $self->param('gene_member_adaptor', $self->compara_dba->get_GeneMemberAdaptor);
    $self->param('homology_adaptor', $self->compara_dba->get_HomologyAdaptor);

    # The member database provides a localized GenomeDB
    my $member_dba      = $self->get_cached_compara_dba('member_db');
    my $genome_db_id    = $self->param_required('genome_db_id');
    my $genome_db       = $member_dba->get_GenomeDBAdaptor->fetch_by_dbID($genome_db_id)
                            or die "'$genome_db_id' is not a valid GenomeDB dbID";
    my $core_dba        = $genome_db->db_adaptor
                            or die sprintf("Cannot find a Core DBAdaptor for %s/%s", $genome_db->name, $genome_db_id);
    $self->param('altallele_group_adaptor', $core_dba->get_AltAlleleGroupAdaptor);
    $self->param('member_dbc', $member_dba->dbc);

    # The master database provides the MLSS
    my $master_dba      = $self->get_cached_compara_dba('master_db');;
    my $mlss            = $master_dba->get_MethodLinkSpeciesSetAdaptor->fetch_by_method_link_type_GenomeDBs($self->param('method_type'), [$genome_db])
                            or die sprintf('Cannot find the MLSS %s[%s/%s] in the master database', $self->param('method_type'), $genome_db->name, $genome_db_id);
    $self->param('mlss', $mlss);
    $self->param('master_dbc', $master_dba->dbc);

}



sub copy_and_fetch_gene {
    my $self = shift;
    my $gene = shift;

    copy_data_with_foreign_keys_by_constraint($self->param('member_dbc'), $self->compara_dba->dbc, 'gene_member', 'stable_id', $gene->stable_id, undef, 'expand_tables');

    # Gene Member
    my $gene_member = $self->param('gene_member_adaptor')->fetch_by_stable_id($gene->stable_id);
    if ($self->debug) {print "GENE: $gene_member ", $gene_member->toString(), "\n";}

    # Transcript Member
    return $gene_member->get_canonical_SeqMember;
}

sub run {
    my $self = shift @_;

    copy_data_with_foreign_keys_by_constraint($self->param('master_dbc'), $self->compara_dba->dbc, 'method_link_species_set', 'method_link_species_set_id', $self->param('mlss')->dbID);

    my $group = $self->param('altallele_group_adaptor')->fetch_by_dbID($self->param('alt_allele_group_id'));
    my @genes = @{$group->get_all_Genes};

    # Discard genes whose canonical transcripts are readthrough transcripts
    my %readthrough_genes;
    foreach my $gene (@genes){
        my $canonical_transcript = $gene->canonical_transcript();
        my %attribs = map {$_->value => 1} @{$canonical_transcript->get_all_Attributes()};
        $readthrough_genes{$gene} = 1 if exists $attribs{'readthrough'};
    }
    @genes = grep {not exists $readthrough_genes{$_}} @genes;

    $self->complete_early("All alt alleles are readthrough transcripts. Skipping.") if scalar @genes < 2;

    my @refs = grep {$genes[$_]->slice->is_reference} 0..(scalar(@genes)-1);
    return unless scalar(@refs);
    die if scalar(@refs) > 1;

    my @seq_members = map {$self->copy_and_fetch_gene($_)} @genes;
    map {bless $_, 'Bio::EnsEMBL::Compara::AlignedMember'} @seq_members;
    if ($self->param('dry_run')) {
        foreach my $i (1..scalar(@seq_members)) {
            $seq_members[$i-1]->dbID($i);
        }
    }

    my $set = Bio::EnsEMBL::Compara::AlignedMemberSet->new();
    $set->add_Member($_) for @seq_members;

    my $tempdir = $self->worker_temp_directory;
    my $fastafile = "$tempdir/alt_alleles.fa";
    $set->print_sequences_to_file($fastafile, -id_type => 'MEMBER');

    my $msa_output = "$tempdir/output.fa";

    my $mafft_exe = $self->param('mafft_exe');
    my $cmdline = sprintf('%s --anysymbol --thread 1 --auto %s > %s', $mafft_exe, $fastafile, $msa_output);
    $self->run_command($cmdline, { die_on_failure => 1 });

    $set->load_cigars_from_file($msa_output);

    my $ref_member = $seq_members[$refs[0]];
    foreach my $other_member (@seq_members) {
        next if $other_member->stable_id eq $ref_member->stable_id;
        # Homology pairs must be unique (also allows rerunning the job)
        next if $self->param('homology_adaptor')->fetch_by_Member_Member($ref_member, $other_member);

        # create an Homology object
        my $homology = new Bio::EnsEMBL::Compara::Homology;
        $homology->description('alt_allele');
        $homology->is_tree_compliant(0);
        $homology->method_link_species_set($self->param('mlss'));

        $homology->add_Member($ref_member->Bio::EnsEMBL::Compara::AlignedMember::copy);
        $homology->add_Member($other_member);#->Bio::EnsEMBL::Compara::AlignedMember::copy);
        $homology->update_alignment_stats;

        $self->param('homology_adaptor')->store($homology) unless $self->param('dry_run');
    }
}

1;

=head1 LICENSE

Copyright [1999-2015] Wellcome Trust Sanger Institute and the EMBL-European Bioinformatics Institute

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

package Bio::EnsEMBL::Compara::RunnableDB::ImportAltAlleGroupAsHomologies;

use strict;

use Data::Dumper;
use Bio::EnsEMBL::Compara::GeneTree;
use Bio::EnsEMBL::Compara::Homology;
use Bio::EnsEMBL::Compara::RunnableDB::LoadMembers;

use base ('Bio::EnsEMBL::Compara::RunnableDB::RunCommand');


sub param_defaults {
    return {
        'dry_run'       => 0,
        'method_type'   => 'ENSEMBL_PROJECTIONS',
        'mafft_exe'     => '/bin/mafft',
        'tag_split_genes' => 0,
    };
}


sub fetch_input {
    my $self = shift @_;

    $self->param_required('alt_allele_group_id');
    $self->param_required('mafft_home');
    $self->param_required('mafft_exe');

    my $genome_db_id = $self->param_required('genome_db_id');
    my $genome_db = $self->compara_dba->get_GenomeDBAdaptor->fetch_by_dbID($genome_db_id) || die "'$genome_db_id' is not a valid GenomeDB dbID";
    $self->param('genome_db', $genome_db);
    $self->param('gene_member_adaptor', $self->compara_dba->get_GeneMemberAdaptor);
    $self->param('seq_member_adaptor', $self->compara_dba->get_SeqMemberAdaptor);
    $self->param('homology_adaptor', $self->compara_dba->get_HomologyAdaptor);

    $self->param('mlss', $self->compara_dba->get_MethodLinkSpeciesSetAdaptor->fetch_by_method_link_type_GenomeDBs($self->param('method_type'), [$self->param('genome_db')]));
}



sub fetch_or_store_gene {
    my $self = shift;
    my $gene = shift;
    my $translate = shift;

    # Gene Member
    my $gene_member = $self->param('gene_member_adaptor')->fetch_by_stable_id($gene->stable_id);
    if (defined $gene_member) {
        if ($self->debug) {print "REUSE: $gene_member "; $gene_member->print_member();}
    } else {
        $gene_member = Bio::EnsEMBL::Compara::GeneMember->new_from_Gene(-gene=>$gene, -genome_db=>$self->param('genome_db'));
        $self->param('gene_member_adaptor')->store($gene_member) unless $self->param('dry_run');
        if ($self->debug) {print "NEW: $gene_member "; $gene_member->print_member();}
    }

    # Transcript Member
    my $trans_member = $gene_member->get_canonical_SeqMember;
    if (defined $trans_member) {
        if ($self->debug) {print "REUSE: $trans_member"; $trans_member->print_member();}
    } else {
        my $transcript = $gene->canonical_transcript;
        $trans_member = Bio::EnsEMBL::Compara::SeqMember->new_from_Transcript(
                -transcript     => $transcript,
                -genome_db      => $self->param('genome_db'),
                -translate      => $translate,
                );
        $trans_member->gene_member_id($gene_member->dbID);
        $self->param('seq_member_adaptor')->store($trans_member) unless $self->param('dry_run');
        $self->param('seq_member_adaptor')->_set_member_as_canonical($trans_member) unless $self->param('dry_run');
        if ($self->debug) {print "NEW: $trans_member "; $trans_member->print_member();}
    }

    return $trans_member;
}

sub run {
    my $self = shift @_;

    my $core_aaga = $self->param('genome_db')->db_adaptor->get_AltAlleleGroupAdaptor;

    my $group = $core_aaga->fetch_by_dbID($self->param('alt_allele_group_id'));
    my @genes = @{$group->get_all_Genes};
    my @refs = grep {$genes[$_]->slice->is_reference} 0..(scalar(@genes)-1);
    return unless scalar(@refs);
    die if scalar(@refs) > 1;
    my @canon_transcripts = map {$_->canonical_transcript} @genes;

    my $translate = scalar(grep {not defined $_->translation} @canon_transcripts) ? 0 : 1;

    my @seq_members = map {$self->fetch_or_store_gene($_, $translate)} @genes;
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

    my $mafft_home = $self->param('mafft_home');
    my $mafft_exe = $self->param('mafft_exe');
    die "Cannot execute '$mafft_exe' in '$mafft_home'" unless(-x $mafft_home.'/'.$mafft_exe);
    my $cmdline = sprintf('%s/%s --anysymbol --thread 1 --auto %s > %s', $mafft_home, $mafft_exe, $fastafile, $msa_output);
    my $cmd_out = $self->run_command($cmdline);
    die "Error running mafft: ".$cmd_out->err if $cmd_out->exit_code;

    $set->load_cigars_from_file($msa_output);

    my $ref_member = $seq_members[$refs[0]];
    foreach my $other_member (@seq_members) {
        next if $other_member->stable_id eq $ref_member->stable_id;

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

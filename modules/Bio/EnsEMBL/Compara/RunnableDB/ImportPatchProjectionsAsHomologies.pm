=head1 LICENSE

  Copyright (c) 1999-2013 The European Bioinformatics Institute and
  Genome Research Limited.  All rights reserved.

  This software is distributed under a modified Apache license.
  For license details, please see

   http://www.ensembl.org/info/about/code_licence.html

=head1 CONTACT

  Please email comments or questions to the public Ensembl
  developers list at <dev@ensembl.org>.

  Questions may also be sent to the Ensembl help desk at
  <helpdesk@ensembl.org>.

=head1 NAME

Bio::EnsEMBL::Compara::RunnableDB::ImportPatchProjectionsAsHomologies

=head1 AUTHORSHIP

Ensembl Team. Individual contributions can be found in the CVS log.

=cut

package Bio::EnsEMBL::Compara::RunnableDB::ImportPatchProjectionsAsHomologies;

use strict;

use Bio::EnsEMBL::Compara::Homology;
use Bio::EnsEMBL::Compara::RunnableDB::LoadMembers;

use base ('Bio::EnsEMBL::Compara::RunnableDB::BaseRunnable');


sub param_defaults {
    return {
        'dry_run'       => 0,
        'method_type'   => 'ENSEMBL_PROJECTIONS',
    };
}


sub fetch_input {
    my $self = shift @_;

    # GenomeDB loading
    my $species = $self->param('species');
    my $genome_db = $self->compara_dba->get_GenomeDBAdaptor->fetch_by_name_assembly($species)
        || die "'$species' is not a valid GenomeDB name";
    $self->param('genome_db', $genome_db);
    $self->param('species_dba', $genome_db->db_adaptor);

    # MLSS loading
    my $mlss = $self->compara_dba->get_MethodLinkSpeciesSetAdaptor->fetch_by_method_link_type_genome_db_ids($self->param('method_type'), [$genome_db->dbID])
        || die "Could not find the '".($self->param('method_type'))."' / '$species' MLSS";
    $self->param('mlss', $mlss);
    $self->param('gene_member_adaptor', $self->compara_dba->get_GeneMemberAdaptor);
    $self->param('seq_member_adaptor', $self->compara_dba->get_SeqMemberAdaptor);
    $self->param('homology_adaptor', $self->compara_dba->get_HomologyAdaptor);

    $self->param('stored_homologies', {});
    $self->param('member_hash', {});
}




sub fetch_or_store_gene {
    my $self = shift;
    my $gene = shift;

    # Gene Member
    my $gene_member = $self->param('gene_member_adaptor')->fetch_by_source_stable_id('ENSEMBLGENE', $gene->stable_id);
    if (defined $gene_member) {
        print "REUSE: $gene_member "; $gene_member->print_member();
    } else {
        $gene_member = Bio::EnsEMBL::Compara::GeneMember->new_from_gene(-gene=>$gene, -genome_db=>$self->param('genome_db'));
        $self->param('gene_member_adaptor')->store($gene_member) unless $self->param('dry_run');
        print "NEW: $gene_member "; $gene_member->print_member();
    }

    # Transcript Member
    my $trans_member = $gene_member->get_canonical_SeqMember;
    if (defined $trans_member) {
        print "REUSE: $trans_member"; $trans_member->print_member();
    } else {
        my $transcript = $gene->canonical_transcript;
        $trans_member = Bio::EnsEMBL::Compara::SeqMember->new_from_transcript(
                -transcript     => $transcript,
                -genome_db      => $self->param('genome_db'),
                -description    => Bio::EnsEMBL::Compara::RunnableDB::LoadMembers::fasta_description(undef, $gene, $transcript),
                -translate      => ($transcript->translation ? 'yes' : 'ncrna'),
                );
        $trans_member->gene_member_id($gene_member->dbID);
        $self->param('seq_member_adaptor')->store($trans_member) unless $self->param('dry_run');
        $self->param('seq_member_adaptor')->_set_member_as_canonical($trans_member) unless $self->param('dry_run');
        print "NEW: $trans_member "; $trans_member->print_member();
    }

    $self->param('member_hash')->{$gene->stable_id} = $trans_member;

    return $gene_member;
}


sub keep_homology_in_mind {
    my $self          = shift;
    my $trans_gene1   = shift;
    my $trans_gene2   = shift;

    $self->param('stored_homologies')->{$trans_gene1->stable_id} = $trans_gene2->stable_id;
    $self->param('stored_homologies')->{$trans_gene2->stable_id} = $trans_gene1->stable_id;
}

sub run {
    my $self = shift @_;

    my $core_sa = $self->param('species_dba')->get_SliceAdaptor;
    my $core_ga = $self->param('species_dba')->get_GeneAdaptor;

    foreach my $slice (@{$core_sa->fetch_all('toplevel')}) {
        next unless $slice->is_reference;
        foreach my $orig_gene (@{$slice->get_all_Genes}) {
            my $group = $self->param('species_dba')->get_AltAlleleGroupAdaptor->fetch_by_gene_id($orig_gene->dbID) || next;
            print "Gene ".$orig_gene->stable_id." dbID ".$orig_gene->dbID." found in alt allele group ".$group->dbID."\n";
            foreach my $proj_gene (@{$group->get_all_Genes}) {
                next if $proj_gene->dbID == $orig_gene->dbID;

                # Create the original gene member if necessary
                my $orig_gene_member = $self->fetch_or_store_gene($orig_gene);
                # Create the patch gene member if necessary
                my $proj_gene_member = $self->fetch_or_store_gene($proj_gene);

                # Keep in a hash the homology
                $self->keep_homology_in_mind($orig_gene, $proj_gene);

                print "Alt slice... gene ".$orig_gene->stable_id." (".$orig_gene->slice->seq_region_name.")in same allele group as ".$proj_gene->stable_id." (".$proj_gene->slice->seq_region_name.")\n";
            }
        }
    }
}


sub store_homology {
    my $self          = shift;
    my $trans_member1 = shift;
    my $trans_member2 = shift;

    my $homology = new Bio::EnsEMBL::Compara::Homology;
    $homology->description('alt_allele');
    $homology->method_link_species_set($self->param('mlss'));
    bless $trans_member1, 'Bio::EnsEMBL::Compara::AlignedMember';
    $homology->add_Member($trans_member1);
    bless $trans_member2, 'Bio::EnsEMBL::Compara::AlignedMember';
    $homology->add_Member($trans_member2);

    print "NEW: $homology "; $homology->print_homology();
    $self->param('homology_adaptor')->store($homology) unless $self->param('dry_run');;

    return $homology;
}


sub write_output {
    my $self = shift @_;

    my %stored_homologies = %{$self->param('stored_homologies')};

    my $count_homology = 0;
    foreach my $gene1 (keys %stored_homologies) {
        my $gene2 = $stored_homologies{$gene1};
        next unless $gene1 lt $gene2;
        die $gene1 unless $self->param('member_hash')->{$gene1};
        die $gene2 unless $self->param('member_hash')->{$gene2};
        $self->store_homology($self->param('member_hash')->{$gene1}, $self->param('member_hash')->{$gene2});
        $count_homology ++;
    }

    warn "$count_homology new homologies";
}

1;

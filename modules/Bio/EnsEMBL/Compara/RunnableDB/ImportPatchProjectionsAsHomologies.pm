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

    my @projected_genes;

    #the projected logic names (same as the core but with proj_ at the start)
    #NB: there are some logic_names that start with proj_ at transcript level
    foreach my $analysis (@{$genome_db->db_adaptor->get_AnalysisAdaptor->fetch_all()}){
        if($analysis->logic_name() =~ m/^proj_/){
            #print $analysis->logic_name()."\n";
            push @projected_genes, @{$genome_db->db_adaptor->get_GeneAdaptor->fetch_all_by_logic_name($analysis->logic_name)};
            print $analysis->logic_name.' '.scalar(@projected_genes)."\n" if $self->debug;
        }
    }

    $self->param('projected_genes', \@projected_genes);
    $self->param('stored_homologies', {});
    $self->param('member_hash', {});
}




sub fetch_or_store_gene {
    my $self = shift;
    my $gene = shift;
    my $counter = shift;

    # Gene Member
    my $gene_member = $self->param('gene_member_adaptor')->fetch_by_source_stable_id('ENSEMBLGENE', $gene->stable_id);
    if (defined $gene_member) {
        print "REUSE: $gene_member "; $gene_member->print_member();
    } else {
        $gene_member = Bio::EnsEMBL::Compara::GeneMember->new_from_gene(-gene=>$gene, -genome_db=>$self->param('genome_db'));
        $self->param('gene_member_adaptor')->store($gene_member) unless $self->param('dry_run');
        print "NEW: $gene_member "; $gene_member->print_member();
        ${$counter} ++;
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
        $self->param('seq_member_adaptor')->_set_member_as_canonical($trans_member);
        print "NEW: $trans_member "; $trans_member->print_member();
    }

    $self->param('member_hash')->{$gene->stable_id} = $trans_member;

    return $gene_member;
}


sub keep_homology_in_mind {
    my $self          = shift;
    my $trans_gene1   = shift;
    my $trans_gene2   = shift;
    my $homology_type = shift;

    $self->param('stored_homologies')->{$trans_gene1->stable_id} = [$trans_gene2->stable_id, $homology_type];
    $self->param('stored_homologies')->{$trans_gene2->stable_id} = [$trans_gene1->stable_id, $homology_type];
}

sub run {
    my $self = shift @_;

my $count_orig_gene = 0;
my $count_proj_gene = 0;
my $transcript_count = 0;

$self->param('missing_genes', []);

#get adaptors
my $core_ga = $self->param('species_dba')->get_GeneAdaptor;
my $core_ta = $self->param('species_dba')->get_TranscriptAdaptor;

#work out the relationships
foreach my $proj_gene (@{$self->param('projected_genes')}){
    #print 'Projected gene '.$proj_gene->stable_id()."\n";

    my @proj_transcripts = @{$proj_gene->get_all_Transcripts()};
    #print scalar(@proj_transcripts)." transcripts\n";
    $transcript_count = $transcript_count + scalar(@proj_transcripts); 
    my $patch_type = '';

    #check patch type
    foreach my $slice_attrib (@{$proj_gene->slice->get_all_Attributes()}){
        if($slice_attrib->name() =~ m/Assembly Patch/){
            $patch_type = $slice_attrib->name();
            #print $patch_type."\n";
        }
    }

TRANSCRIPT:
    foreach my $proj_transcript (@proj_transcripts){
        #print 'Projected transcript '.$proj_transcript->stable_id()."\n";
        #check if cdna/transcript seq altered in projection
        my $alt_seq = 'cdna/transcript seq unchanged';
        my $homology_type = 'projection_unchanged';
        foreach my $t_attrib (@{$proj_transcript->get_all_Attributes}){
            if($t_attrib->name =~ m/Projection altered sequence/){
                $alt_seq = 'cdna/transcript seq altered in projection';
                $homology_type = 'projection_altered';
            }
        }

        my $orig_transcript_id = '';
        my @supp_feat_pairs = @{$proj_transcript->get_all_supporting_features()};
        foreach my $feat_pair (@supp_feat_pairs){
            if($feat_pair->db_display_name =~ m/^Ensembl .* Transcript$/){
                $orig_transcript_id = $feat_pair->hseqname;
                #print $proj_transcript->stable_id().' '.$feat_pair->hseqname."\n";

                my $orig_gene = $core_ga->fetch_by_transcript_stable_id($orig_transcript_id);
                my $orig_transcript = $core_ta->fetch_by_stable_id($orig_transcript_id);

                if (not defined $orig_gene or not defined $orig_transcript) {
                    warn "\$core_ga->fetch_by_transcript_stable_id($orig_transcript_id) returned undef" unless $orig_gene;
                    warn "\$core_ta->fetch_by_stable_id($orig_transcript_id) returned undef" unless $orig_transcript;
                    push @{$self->param('missing_genes')}, $orig_transcript_id;
                    next TRANSCRIPT;
                }

                # Create the original gene member if necessary
                my $orig_gene_member = $self->fetch_or_store_gene($orig_gene, \$count_orig_gene);
                # Create the patch gene member if necessary
                my $proj_gene_member = $self->fetch_or_store_gene($proj_gene, \$count_proj_gene);

                # Keep in a hash the homology
                $self->keep_homology_in_mind($orig_gene, $proj_gene, $homology_type);
                print $proj_gene->stable_id.' '.$orig_gene->stable_id.' '.$patch_type.' '.$alt_seq."\n";

                next TRANSCRIPT;
            }
        }
    }
}

print "total transcripts fetched: $transcript_count\n";
print "$count_orig_gene ref genes\n";
print "$count_proj_gene projected genes\n";

}

sub store_homology {
    my $self          = shift;
    my $trans_member1 = shift;
    my $trans_member2 = shift;
    my $homology_type = shift;

    my $homology = new Bio::EnsEMBL::Compara::Homology;
    $homology->description($homology_type);
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

    my $missing_genes = join("\n", @{$self->param('missing_genes')});
    if ($missing_genes) {
        die "!! Some genes are referenced to, but are not present in the core gene set !!\n$missing_genes";
    }

    my %stored_homologies = %{$self->param('stored_homologies')};

    my $count_homology = 0;
    foreach my $gene1 (keys %stored_homologies) {
        my ($gene2, $homology_type) = @{$stored_homologies{$gene1}};
        next unless $gene1 lt $gene2;
        die $gene1 unless $self->param('member_hash')->{$gene1};
        die $gene2 unless $self->param('member_hash')->{$gene2};
        $self->store_homology($self->param('member_hash')->{$gene1}, $self->param('member_hash')->{$gene2}, $homology_type);
        $count_homology ++;
    }

    warn "$count_homology new homologies";
}

1;

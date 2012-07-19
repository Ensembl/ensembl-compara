#!/usr/bin/env perl

use strict;
use warnings;

use Data::Dumper;
use Getopt::Long;

use Bio::EnsEMBL::Registry;
use Bio::EnsEMBL::Utils::Exception qw(throw warning);
use Bio::EnsEMBL::Slice;
use Bio::EnsEMBL::DBSQL::DBAdaptor;
use Bio::EnsEMBL::DBSQL::SliceAdaptor;

use Bio::EnsEMBL::Compara::Subset;
use Bio::EnsEMBL::Compara::MethodLinkSpeciesSet;
use Bio::EnsEMBL::Compara::DBSQL::DBAdaptor;
use Bio::EnsEMBL::Compara::RunnableDB::LoadMembers;

$| = 1;

my $reg_conf = '';
my $comp_alias = '';
my $species_name = '';

my $no_store = 0;

my $description = q'
	PROGRAM: convert_patch_to_compara_homologies.pl

	DESCRIPTION: converts all the gene projections from the core database to compara Members and Homologies.

	EXAMPLE: perl scripts/pipeline/sample_projection_relationship_script.pl -reg_conf scripts/pipeline/production_reg_conf.pl -comp_alias compara_homology_merged -species homo_sapiens 
';

my $help = sub {
	print $description;
};

unless(@ARGV){
	$help->();
	exit(0);
}

&GetOptions(
        'reg_conf:s'    => \$reg_conf,
        'comp_alias:s'  => \$comp_alias,
        'species:s'     => \$species_name,
        'no_store:i'    => \$no_store,
        );

unless ($reg_conf && $comp_alias) {
	$help->();
	exit(0);
}

Bio::EnsEMBL::Registry->load_all($reg_conf, 1);

my $compara_dba = Bio::EnsEMBL::Registry->get_DBAdaptor($comp_alias, 'compara');
my $member_adaptor = $compara_dba->get_MemberAdaptor();
my $homology_adaptor = $compara_dba->get_HomologyAdaptor();
my $human_genome_db = $compara_dba->get_GenomeDBAdaptor()->fetch_by_name_assembly($species_name);

# MLSS
my $mlss = new Bio::EnsEMBL::Compara::MethodLinkSpeciesSet(
    -method => $compara_dba->get_MethodAdaptor->fetch_by_type('ENSEMBL_PROJECTIONS'),
    -species_set_obj => $compara_dba->get_SpeciesSetAdaptor->fetch_by_GenomeDBs([$human_genome_db]),
);
$compara_dba->get_MethodLinkSpeciesSetAdaptor->store($mlss);

# Subsets
my $subset_peps  = Bio::EnsEMBL::Compara::Subset->new(-name => sprintf('gdb:%d %s projected canonical translations', $human_genome_db->dbID, $human_genome_db->name) );
my $subset_genes = Bio::EnsEMBL::Compara::Subset->new(-name => sprintf('gdb:%d %s projected canonical genes',        $human_genome_db->dbID, $human_genome_db->name) );
$compara_dba->get_SubsetAdaptor->store($subset_peps) unless $no_store;
$compara_dba->get_SubsetAdaptor->store($subset_genes) unless $no_store;

print 'FOUND genome_db ', $human_genome_db->dbID, "\n";
print 'FOUND/STORED mlss ', $mlss->dbID, "\n";
print 'FOUND/STORED subsets ', $subset_peps->dbID, ' ', $subset_genes->dbID, "\n";

#get adaptors
my $core_ga = Bio::EnsEMBL::Registry->get_adaptor($species_name, 'core', 'Gene');
my $core_ta = Bio::EnsEMBL::Registry->get_adaptor($species_name, 'core', 'Transcript');

#get the projected genes
my $core_aa = Bio::EnsEMBL::Registry->get_adaptor($species_name, 'core', 'Analysis');
my @core_analyses = @{$core_aa->fetch_all()};

my @projected_logic_names;

#the projected logic names (same as the core but with proj_ at the start)
#NB: there are some logic_names that start with proj_ at transcript level
foreach my $analysis (@core_analyses){
    if($analysis->logic_name() =~ m/^proj_/){
        #print $analysis->logic_name()."\n";
        push @projected_logic_names, $analysis->logic_name();
    }
}

my @projected_genes;

foreach my $logic_name (@projected_logic_names){
    push @projected_genes, @{$core_ga->fetch_all_by_logic_name($logic_name)};
    print $logic_name.' '.scalar(@projected_genes)."\n";
}

my $transcript_count = 0;

my $count_orig_gene = 0;
my $count_proj_gene = 0;

my %gene_stable_id_2_compara_transcript;

sub fetch_or_store_gene {
    my $gene = shift;
    my $counter = shift;
    my $gene_member = $member_adaptor->fetch_by_source_stable_id('ENSEMBLGENE', $gene->stable_id);
    if (defined $gene_member) {
        print "REUSE: $gene_member "; $gene_member->print_member();
        $gene_stable_id_2_compara_transcript{$gene->stable_id} = $gene_member->get_canonical_Member;
    } else {
        $gene_member = Bio::EnsEMBL::Compara::Member->new_from_gene(-gene=>$gene, -genome_db=>$human_genome_db);
        print "NEW: $gene_member "; $gene_member->print_member();
        $member_adaptor->store($gene_member) unless $no_store;
        $subset_genes->add_member($gene_member);
        ${$counter} ++;

        my $transcript = $gene->canonical_transcript;
        my $trans_member = Bio::EnsEMBL::Compara::Member->new_from_transcript(
                -transcript     => $transcript,
                -genome_db      => $human_genome_db,
                -description    => Bio::EnsEMBL::Compara::RunnableDB::LoadMembers::fasta_description(undef, $gene, $transcript),
                -translate      => ($transcript->translation ? 'yes' : 'ncrna'),
                );
        $trans_member->gene_member($gene_member);
        print "NEW: $trans_member "; $trans_member->print_member();
        $member_adaptor->store($trans_member) unless $no_store;
        $member_adaptor->store_gene_peptide_link($gene_member->dbID, $trans_member->dbID) unless $no_store;
        $subset_peps->add_member($trans_member);
        $gene_stable_id_2_compara_transcript{$gene->stable_id} = $trans_member;

    }
    return $gene_member;
}


my %stored_homologies;
sub keep_homology_in_mind {
    my $trans_gene1   = shift;
    my $trans_gene2   = shift;
    my $homology_type = shift;

    $stored_homologies{$trans_gene1->stable_id} = [$trans_gene2->stable_id, $homology_type];
    $stored_homologies{$trans_gene2->stable_id} = [$trans_gene1->stable_id, $homology_type];
}




#work out the relationships
foreach my $proj_gene (@projected_genes){
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
            if($feat_pair->hseqname =~ m/^ENST/){
                $orig_transcript_id = $feat_pair->hseqname;
                #print $proj_transcript->stable_id().' '.$feat_pair->hseqname."\n";

                my $orig_gene = $core_ga->fetch_by_transcript_stable_id($orig_transcript_id);
                my $orig_transcript = $core_ta->fetch_by_stable_id($orig_transcript_id);

                # Create the original gene member if necessary
                my $orig_gene_member = fetch_or_store_gene($orig_gene, \$count_orig_gene);
                # Create the patch gene member if necessary
                my $proj_gene_member = fetch_or_store_gene($proj_gene, \$count_proj_gene);

                # Keep in a hash the homology
                keep_homology_in_mind($orig_gene, $proj_gene, $homology_type);
                print $proj_gene->stable_id.' '.$orig_gene->stable_id.' '.$patch_type.' '.$alt_seq."\n";

                next TRANSCRIPT;
            }
        }
    }
}

print "total transcripts fetched: $transcript_count\n";


sub store_homology {
    my $trans_member1 = shift;
    my $trans_member2 = shift;
    my $homology_type = shift;

    my $homology = new Bio::EnsEMBL::Compara::Homology;
    $homology->description($homology_type);
    $homology->subtype('');
    $homology->ancestor_node_id(0);
    $homology->tree_node_id(0);
    $homology->method_link_species_set_id($mlss->dbID);
    bless $trans_member1, 'Bio::EnsEMBL::Compara::AlignedMember';
    $homology->add_Member($trans_member1);
    bless $trans_member2, 'Bio::EnsEMBL::Compara::AlignedMember';
    $homology->add_Member($trans_member2);

    print "NEW: $homology "; $homology->print_homology();
    $homology_adaptor->store($homology) unless $no_store;

    return $homology;
}

my $count_homology = 0;
foreach my $gene1 (keys %stored_homologies) {
    my ($gene2, $homology_type) = @{$stored_homologies{$gene1}};
    next unless $gene1 lt $gene2;
    store_homology($gene_stable_id_2_compara_transcript{$gene1}, $gene_stable_id_2_compara_transcript{$gene2}, $homology_type);
    $count_homology ++;
}


print "new compara entries:\n";
print "$count_orig_gene ref genes\n";
print "$count_proj_gene projected genes\n";
print "$count_homology new homologies\n";


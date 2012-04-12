#!/usr/bin/env perl

use strict;
use warnings;
use Data::Dumper;
use Getopt::Long;
use Bio::EnsEMBL::Utils::Exception qw(throw warning);
use Bio::EnsEMBL::Slice;
use Bio::EnsEMBL::DBSQL::DBAdaptor;
use Bio::EnsEMBL::DBSQL::SliceAdaptor;

use Bio::EnsEMBL::Compara::Subset;
use Bio::EnsEMBL::Compara::MethodLinkSpeciesSet;
use Bio::EnsEMBL::Compara::DBSQL::DBAdaptor;
use Bio::EnsEMBL::Compara::RunnableDB::LoadMembers;

$| = 1;

my $core_host = '';
my $core_user = '';
my $core_port = '';
my $core_dbname = '';

my $of_host = '';
my $of_user = '';
my $of_port = '';
my $of_dbname = '';

my $comp_url = '';
my $species_name = '';

my $no_store = 0;

my $description = q'
	PROGRAM: convert_patch_to_compara_homologies.pl

	DESCRIPTION: converts all the gene projections from the "otherfeatures"
		     db to compara member and homology tables.
	EXAMPLE: perl workspace/sample_projection_relationship_script.pl -core_host 127.0.0.1 -core_port 4304 -core_user ensro -core_dbname homo_sapiens_core_65_37 -of_host 127.0.0.1 -of_port 4304 -of_user ensro -of_dbname homo_sapiens_otherfeatures_65_37 -comp_url mysql://ensadmin:ensembl@127.0.0.1:4313/mp12_compara_homology_merged_65  -species homo_sapiens 
';

my $help = sub {
	print $description;
};

unless(@ARGV){
	$help->();
	exit(0);
}

&GetOptions(
        'core_host:s'   => \$core_host,
        'core_user:s'   => \$core_user,
        'core_port:n'   => \$core_port,
        'core_dbname:s' => \$core_dbname,

        'of_host:s'     => \$of_host,
        'of_user:s'     => \$of_user,
        'of_port:n'     => \$of_port,
        'of_dbname:s'   => \$of_dbname,

        'comp_url:s'    => \$comp_url,
        'species:s'     => \$species_name,

        'no_store:i'    => \$no_store,
        );

unless(defined $core_host && defined $of_host && defined $comp_url) {
	$help->();
	exit(0);
}


#get core db adaptor
my $core_db = new Bio::EnsEMBL::DBSQL::DBAdaptor( -host   => $core_host,
        -user   => $core_user,
        -port   => $core_port,
        -dbname => $core_dbname );

#get otherfeatures db adaptor
my $of_db = new Bio::EnsEMBL::DBSQL::DBAdaptor( -dnadb  => $core_db,
        -host   => $of_host,
        -user   => $of_user,
        -port   => $of_port,
        -dbname => $of_dbname );

# This needs to be run first
# ALTER TABLE member   AUTO_INCREMENT=300000001
# ALTER TABLE sequence AUTO_INCREMENT=300000001
# ALTER TABLE subset   AUTO_INCREMENT=300000001
# ALTER TABLE homology AUTO_INCREMENT=300000001

my $compara_dba = new Bio::EnsEMBL::Compara::DBSQL::DBAdaptor( -url => $comp_url );
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
my $subset_peps  = Bio::EnsEMBL::Compara::Subset->new(-name => sprintf("gdb:%d %s projected canonical translations", $human_genome_db->dbID, $human_genome_db->name) );
my $subset_genes = Bio::EnsEMBL::Compara::Subset->new(-name => sprintf("gdb:%d %s projected canonical genes",        $human_genome_db->dbID, $human_genome_db->name) );
$compara_dba->get_SubsetAdaptor->store($subset_peps) unless $no_store;
$compara_dba->get_SubsetAdaptor->store($subset_genes) unless $no_store;

print "FOUND genome_db ", $human_genome_db->dbID, "\n";
print "FOUND/STORED mlss ", $mlss->dbID, "\n";
print "FOUND/STORED subsets ", $subset_peps->dbID, " ", $subset_genes->dbID, "\n";

#get adaptors
my $of_ga = $of_db->get_GeneAdaptor();
my $core_ga = $core_db->get_GeneAdaptor();
my $core_ta = $core_db->get_TranscriptAdaptor();

#get the projected genes
my $of_aa = $of_db->get_AnalysisAdaptor();
my @of_analyses = @{$of_aa->fetch_all()};

my @projected_logic_names;

#the projected logic names (same as the core but with proj_ at the start)
#NB: there are some logic_names that start with proj_ at transcript level
foreach my $analysis (@of_analyses){
    if($analysis->logic_name() =~ m/^proj_/){
        #print $analysis->logic_name()."\n";
        push @projected_logic_names, $analysis->logic_name();
    }
}

my @projected_genes;

foreach my $logic_name (@projected_logic_names){
    push @projected_genes, @{$of_ga->fetch_all_by_logic_name($logic_name)};
    print $logic_name." ".scalar(@projected_genes)."\n";
}

my $transcript_count = 0;

my $count_orig_gene = 0;
my $count_orig_trans = 0;
my $count_proj_gene = 0;
my $count_proj_trans = 0;
my $count_homology = 0;

my %compara_to_core;

sub fetch_or_store_gene {
    my $gene = shift;
    my $gene_member = $member_adaptor->fetch_by_source_stable_id('ENSEMBLGENE', $gene->stable_id);
    if (defined $gene_member) {
        print "REUSE: $gene_member "; $gene_member->print_member();
    } else {
        $gene_member = Bio::EnsEMBL::Compara::Member->new_from_gene(-gene=>$gene, -genome_db=>$human_genome_db);
        print "NEW: $gene_member "; $gene_member->print_member();
        $member_adaptor->store($gene_member) unless $no_store;
        $subset_genes->add_member($gene_member);
        my $counter = shift;
        ${$counter} ++;
    }
    $compara_to_core{$gene_member} = $gene;
    return $gene_member;
}
 

sub fetch_or_store_transcript {
    my $transcript = shift;

    my $trans_member = $member_adaptor->fetch_by_source_stable_id('ENSEMBLTRANS', $transcript->stable_id);
       $trans_member = $member_adaptor->fetch_by_source_stable_id('ENSEMBLPEP', $transcript->translation->stable_id) unless $trans_member or not $transcript->translation;
    if (defined $trans_member) {
        print "REUSE: $trans_member ";  $trans_member->print_member();
    } else {
        my $gene_member = shift;
        my $gene = shift;
        $trans_member = Bio::EnsEMBL::Compara::Member->new_from_transcript(
                -transcript     => $transcript,
                -genome_db      => $human_genome_db,
                -description    => Bio::EnsEMBL::Compara::RunnableDB::LoadMembers::fasta_description(undef, $gene, $transcript),
                -translate      => ($transcript->translation ? 'yes' : 'ncrna'),
                );
        $trans_member->gene_member($gene_member);
        print "NEW: $trans_member "; $trans_member->print_member();
        $member_adaptor->store($trans_member) unless $no_store;
        $member_adaptor->store_gene_peptide_link($gene_member->dbID, $trans_member->dbID) unless $no_store;
        my $counter = shift;
        ${$counter} ++;
    }
    $compara_to_core{$trans_member} = $transcript;
    return $trans_member;
}


sub fetch_or_store_homology {
    my $trans_member1 = shift;
    my $trans_member2 = shift;
    my $homology_type = shift;

    my $homology = new Bio::EnsEMBL::Compara::Homology;
    $homology->description($homology_type);
    $homology->subtype('');
    $homology->ancestor_node_id(0);
    $homology->tree_node_id(0);
    $homology->method_link_species_set_id($mlss->dbID);

    my $attribute;
    $attribute = new Bio::EnsEMBL::Compara::Attribute;
    $attribute->peptide_member_id($trans_member1->dbID);
    $homology->add_Member_Attribute([$trans_member1->gene_member, $attribute]);

    $attribute = new Bio::EnsEMBL::Compara::Attribute;
    $attribute->peptide_member_id($trans_member2->dbID);
    $homology->add_Member_Attribute([$trans_member2->gene_member, $attribute]);

    print "NEW: $homology "; $homology->print_homology();
    $homology_adaptor->store($homology) unless $no_store;
    $count_homology ++;

    return $homology;
}



#work out the relationships
foreach my $proj_gene (@projected_genes){
    #print "Projected gene ".$proj_gene->stable_id()."\n";

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
        #print "Projected transcript ".$proj_transcript->stable_id()."\n";
        #check if cdna/transcript seq altered in projection
        my $alt_seq = "cdna/transcript seq unchanged";
        my $homology_type = 'projection_unchanged';
        foreach my $t_attrib (@{$proj_transcript->get_all_Attributes}){
            if($t_attrib->name =~ m/Projection altered sequence/){
                $alt_seq = "cdna/transcript seq altered in projection";
                $homology_type = 'projection_altered';
            }
        }

        my $orig_transcript_id = '';
        my @supp_feat_pairs = @{$proj_transcript->get_all_supporting_features()};
        foreach my $feat_pair (@supp_feat_pairs){
            if($feat_pair->hseqname =~ m/^ENST/){
                $orig_transcript_id = $feat_pair->hseqname;
                #print $proj_transcript->stable_id()." ".$feat_pair->hseqname."\n";

                my $orig_gene = $core_ga->fetch_by_transcript_stable_id($orig_transcript_id);
                my $orig_transcript = $core_ta->fetch_by_stable_id($orig_transcript_id);

                # Create the original gene member if necessary
                my $orig_gene_member = fetch_or_store_gene($orig_gene, \$count_orig_gene);
                # Create the original transcript member if necessary
                my $orig_trans_member = fetch_or_store_transcript($orig_transcript, $orig_gene_member, $orig_gene, \$count_orig_trans);
                # Create the patch gene member if necessary
                my $proj_gene_member = fetch_or_store_gene($proj_gene, \$count_proj_gene);
                # Create the patch transcript member if necessary
                my $proj_trans_member = fetch_or_store_transcript($proj_transcript, $proj_gene_member, $proj_gene, \$count_proj_trans);

                # Create the homology link id necessary
                #fetch_or_store_homology($orig_trans_member, $proj_trans_member, $homology_type);
                print $proj_transcript->stable_id." ".$orig_transcript_id." ".$patch_type." ".$alt_seq."\n";

                next TRANSCRIPT;
            }
        }
    }
}

print "total transcripts fetched: ".$transcript_count."\n";

# canonical translations
my $count_can_trans = 0;
foreach my $gene_member (@{$subset_genes->member_list}) {
    print "CANONICAL ", $gene_member->stable_id, " ";
    my $can_trans = $compara_to_core{$gene_member}->canonical_transcript;
    my $can_member = fetch_or_store_transcript($can_trans, $gene_member, $compara_to_core{$gene_member}, \$count_can_trans);
    $subset_peps->add_member($can_member);
}


print "new compara entries:\n";
print $count_orig_gene, " ref genes\n";
print $count_orig_trans, " ref transcripts\n";
print $count_proj_gene, " projected genes\n";
print $count_proj_trans, " projected transcripts\n";
print $count_homology, " new homologies\n";
print $count_can_trans, " new canonical transcripts\n";


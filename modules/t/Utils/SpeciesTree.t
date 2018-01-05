#!/usr/bin/env perl
# Copyright [1999-2015] Wellcome Trust Sanger Institute and the EMBL-European Bioinformatics Institute
# Copyright [2016-2018] EMBL-European Bioinformatics Institute
# 
# Licensed under the Apache License, Version 2.0 (the "License");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at
# 
#      http://www.apache.org/licenses/LICENSE-2.0
# 
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.


use strict;
use warnings;
 
use File::Basename ();

use Test::More;
use Test::Exception;
use Test::Warn;

use Bio::EnsEMBL::Test::MultiTestDB;

use Bio::EnsEMBL::Compara::Graph::NewickParser;
use Bio::EnsEMBL::Compara::Utils::SpeciesTree;


my $t_dir = File::Basename::dirname( File::Basename::dirname( Cwd::realpath($0) ) );

# # load test db
my $multi_db = Bio::EnsEMBL::Test::MultiTestDB->new('homology', $t_dir);
my $dba = $multi_db->get_DBAdaptor('compara');
my $st_a = $dba->get_SpeciesTreeAdaptor;
my $stn_a = $dba->get_SpeciesTreeNodeAdaptor;
my $ss_a = $dba->get_SpeciesSetAdaptor;
my $nt_a = $dba->get_NCBITaxonAdaptor;


sub tree_as_newick {
    my $node = shift;
    my $s = $node->name // 'NA';
    return $s if $node->is_leaf;
    return '(' . join(',', sort map {tree_as_newick($_)} @{$node->children}) . ')' . $s;
}

sub tree_as_gdb_newick {
    my $node = shift;
    return ($node->genome_db_id // 'NA') if $node->is_leaf;
    return '(' . join(',', sort map {tree_as_gdb_newick($_)} @{$node->children}) . ')';
}

sub tree_as_tax_newick {
    my $node = shift;
    return ($node->taxon_id // 'NA') if $node->is_leaf;
    return '(' . join(',', sort map {tree_as_tax_newick($_)} @{$node->children}) . ')' . ($node->taxon_id // '');
}


sub test_new_from_newick {
    my ($in_newick, $newick_gdb, $newick_tax, $newick_name) = @_;
    my $new_root = Bio::EnsEMBL::Compara::Utils::SpeciesTree->new_from_newick($in_newick, $dba);
    is(tree_as_gdb_newick($new_root), $newick_gdb);
    is(tree_as_tax_newick($new_root), $newick_tax);
    is(tree_as_newick($new_root), $newick_name);
}

subtest 'new_from_newick' => sub {
    #ok(1); return;

    test_new_from_newick(
        '((homo_sapiens,(genus_species,mus_musculus))my_name,danio_rerio)',
        '((134,150),154)',
        '((10090,9606)314146,7955)117571',
        '((Homo sapiens,Mus musculus GRCm38)my_name,Danio rerio)Euteleostomi',
    );

    test_new_from_newick(
        '(((triticum_aestivum,(triticum_urartu,triticum_aestivum_A),triticum_aestivum_B,(aegilops_tauschii,triticum_aestivum_D)),hordeum_vulgare),brachypodium_distachyon)',
        '(((1983,2081),(1984,2083),2080,2082),2088)',
        '(((37682,4565)1648030,(4565,4572)4564,4565,4565)1648030,112509)147389',
        '(((Aegilops tauschii,Triticum aestivum Chinese Spring (component D))Triticinae,(Triticum aestivum Chinese Spring (component A),Triticum urartu)Triticum,Triticum aestivum Chinese Spring,Triticum aestivum Chinese Spring (component B))Triticinae,Hordeum vulgare subsp. vulgare)Triticeae'
    );

    test_new_from_newick(
        '(homo_sapiens,speciesnounderscore)',
        '150',
        '9606',
        'Homo sapiens',
    );

    warning_like {
        Bio::EnsEMBL::Compara::Utils::SpeciesTree->new_from_newick( '(aegilops_tauschii_A)', $dba );
    } qr/aegilops_tauschii_A not found in the genome_db table/;

    throws_ok {Bio::EnsEMBL::Compara::Utils::SpeciesTree->new_from_newick( '(triticum_aestivum_X)', $dba )}
                qr/No component named 'X' in 'triticum_aestivum'/, 'Non-existing component';

    my $new_root = Bio::EnsEMBL::Compara::Utils::SpeciesTree->new_from_newick( '(genus_species)', $dba);
    is($new_root, undef, 'No species found');
};


subtest 'prune_tree' => sub {
    #ok(1); return;

    # Prune to two species
    my $tree = $st_a->fetch_by_method_link_species_set_id_label(40101, 'default');
    my $new_root = Bio::EnsEMBL::Compara::Utils::SpeciesTree->prune_tree($tree->root, $dba, 30982); # O.lat-E.cab
    ok($tree->root->is_leaf, 'The old root has been disconnected');
    ok($new_root, 'Found a match');
    is(tree_as_gdb_newick($new_root), '(37,61)', 'tree_as_gdb_newick');
    is(tree_as_tax_newick($new_root), '(8090,9796)117571', 'tree_as_tax_newick');
    $st_a->{_id_cache}->clear_cache;

    # Prune to one species
    $tree = $st_a->fetch_by_method_link_species_set_id_label(40101, 'default');
    $new_root = Bio::EnsEMBL::Compara::Utils::SpeciesTree->prune_tree($tree->root, $dba, 99999); # M.spr-O.lat
    ok($tree->root->is_leaf, 'The old root has been disconnected');
    ok($new_root, 'Found a match');
    $new_root->print_tree(0.02);
    ok($new_root->is_leaf, 'Only one species');
    is($new_root->genome_db_id, 37);
    is($new_root->taxon_id, 8090);
    $st_a->{_id_cache}->clear_cache;

    # Prune to zero species
    $tree = $st_a->fetch_by_method_link_species_set_id_label(40101, 'default');
    $new_root = Bio::EnsEMBL::Compara::Utils::SpeciesTree->prune_tree($tree->root, $dba, 99998); # M.spr
    ok($tree->root->is_leaf, 'The old root has been disconnected');
    ok(!$new_root, 'No match found');
    $st_a->{_id_cache}->clear_cache;

    my $newick = '(danio_rerio,pan_troglodytes)';
    $tree = Bio::EnsEMBL::Compara::Graph::NewickParser::parse_newick_into_tree( $newick, 'Bio::EnsEMBL::Compara::SpeciesTreeNode' ); 
    $new_root = Bio::EnsEMBL::Compara::Utils::SpeciesTree->prune_tree($tree, $dba, 36099); # D.rer
    ok($tree->is_leaf, 'The old root has been disconnected');
    ok($new_root, 'Found a match');
    ok($new_root->is_leaf, 'Only one species');
    is($new_root->genome_db_id, 154);
    is($new_root->taxon_id, 7955);
    $st_a->{_id_cache}->clear_cache;

    $newick = '(danio_rerio,unknown_species)';
    $tree = Bio::EnsEMBL::Compara::Graph::NewickParser::parse_newick_into_tree( $newick, 'Bio::EnsEMBL::Compara::SpeciesTreeNode' ); 
    $new_root = Bio::EnsEMBL::Compara::Utils::SpeciesTree->prune_tree($tree, $dba); # all species
    ok($tree->is_leaf, 'The old root has been disconnected');
    ok($new_root, 'Found a match');
    ok($new_root->is_leaf, 'Only one species');
    is($new_root->genome_db_id, 154);
    is($new_root->taxon_id, 7955);
    $st_a->{_id_cache}->clear_cache;
};


subtest 'create_species_tree' => sub {
    #ok(1); return;

    my $ss = $ss_a->fetch_by_dbID(33928);   # O.lat-B.tau
    my $new_root = Bio::EnsEMBL::Compara::Utils::SpeciesTree->create_species_tree(
        -COMPARA_DBA => $dba,
        -SPECIES_SET => $ss,
    );
    ok($new_root, 'Made a tree');
    is(tree_as_gdb_newick($new_root), '(122,37)', 'tree_as_gdb_newick');
    is(tree_as_tax_newick($new_root), '(8090,9913)117571', 'tree_as_tax_newick');

    $new_root = Bio::EnsEMBL::Compara::Utils::SpeciesTree->create_species_tree(
        -COMPARA_DBA => $dba,
        -NO_PREVIOUS => 1,
        -SPECIES_SET => $ss,
    );
    ok($new_root, 'Made a tree');
    is(tree_as_gdb_newick($new_root), '(122,37)', 'tree_as_gdb_newick');
    is(tree_as_tax_newick($new_root), '(8090,9913)117571', 'tree_as_tax_newick');

    $new_root = Bio::EnsEMBL::Compara::Utils::SpeciesTree->create_species_tree(
        -COMPARA_DBA => $dba,
        -SPECIES_SET => $ss,
        -RETURN_NCBI_TREE => 1,
    );
    ok($new_root, 'Made a tree');
    is(tree_as_tax_newick($new_root), '(8090,9913)117571', 'tree_as_tax_newick');

    $new_root = Bio::EnsEMBL::Compara::Utils::SpeciesTree->create_species_tree(
        -COMPARA_DBA => $dba,
        -NO_PREVIOUS => 1,
    );
    is($new_root, undef, 'No tree built because no taxa requested');

    $new_root = Bio::EnsEMBL::Compara::Utils::SpeciesTree->create_species_tree(
        -COMPARA_DBA => $dba,
        -NO_PREVIOUS => 1,
        -EXTRATAXON_SEQUENCED => [10141, 9813, 9813, 9978, 10116],
        -MULTIFURCATION_DELETES_NODE => [314147],
    );
    ok($new_root, 'Made a tree');
    is($new_root->taxon_id, 9347, 'The root node is Eutheria');
    is(scalar(@{$new_root->get_all_leaves}), 4, 'Two species in the tree');
    is(tree_as_gdb_newick($new_root), '((NA,NA),NA,NA)', 'tree_as_gdb_newick');
    is(tree_as_tax_newick($new_root), '((10116,10141)9989,9813,9978)9347', 'tree_as_tax_newick');

    # -MULTIFURCATION_DELETES_NODE has no effect because this is the root
    $new_root = Bio::EnsEMBL::Compara::Utils::SpeciesTree->create_species_tree(
        -COMPARA_DBA => $dba,
        -NO_PREVIOUS => 1,
        -EXTRATAXON_SEQUENCED => [10141, 9813, 9813, 9978, 10116],
        -MULTIFURCATION_DELETES_NODE => [9347],
    );
    ok($new_root, 'Made a tree');
    is($new_root->taxon_id, 9347, 'The root node is Eutheria');
    is(scalar(@{$new_root->get_all_leaves}), 4, 'Two species in the tree');
    is(tree_as_gdb_newick($new_root), '(((NA,NA),NA),NA)', 'tree_as_gdb_newick');
    is(tree_as_tax_newick($new_root), '(((10116,10141)9989,9978)314147,9813)9347', 'tree_as_tax_newick');

    warning_like {
        $new_root = Bio::EnsEMBL::Compara::Utils::SpeciesTree->create_species_tree(
            -COMPARA_DBA => $dba,
            -NO_PREVIOUS => 1,
            -EXTRATAXON_SEQUENCED => [10141, 9813, 9813, 9978, 10116],
            -MULTIFURCATION_DELETES_ALL_SUBNODES => [9347, 117571],
        );
    } qr/Cannot flatten the taxon 117571 as it is not found in the tree/;

    ok($new_root, 'Made a tree');
    is($new_root->taxon_id, 9347, 'The root node is Eutheria');
    is(scalar(@{$new_root->get_all_leaves}), 4, 'Two species in the tree');
    is(tree_as_gdb_newick($new_root), '(NA,NA,NA,NA)', 'tree_as_gdb_newick');
    is(tree_as_tax_newick($new_root), '(10116,10141,9813,9978)9347', 'tree_as_tax_newick');

    throws_ok {Bio::EnsEMBL::Compara::Utils::SpeciesTree->create_species_tree(-COMPARA_DBA => $dba, -EXTRATAXON_SEQUENCED => [101421891])}
                qr/Unknown taxon_id '101421891'/, 'Unknown taxon_id';

    throws_ok {Bio::EnsEMBL::Compara::Utils::SpeciesTree->create_species_tree(-COMPARA_DBA => $dba)}
                qr/Cannot add .* because it is below a node \(.*\) that is already in the tree/, 'sub-taxa are not allowed by default';

    $new_root = Bio::EnsEMBL::Compara::Utils::SpeciesTree->create_species_tree(
        -COMPARA_DBA => $dba,
        -ALLOW_SUBTAXA => 1,
    );
    ok($new_root, 'Made a tree');
    my $ng = '((((((((((((((((((((123,125,150),60),115),((158,31),151,153)),117),82),((159,58),124)),((((((134,160,162,165,172),174),155),131,83),69),(108,67)),48),(((109,135,138),139),((122,147),132,80,84),(118,85),(49,55),61)),(149,78),(33,79,98)),(121,46,91)),43),((((((142,157),112),144),(145,87)),136),111)),116),129),(((((((137,152),37),130),((4,65),36)),126),(146,154)),148)),(128,27)),(143,156)),127),((((2080,2081,2082,2083,2084),1983),1984),2088))';
    my $nt = '((((((((((((((((((((9595,9598,9606)207598,9601)9604,61853)314295,((9544,9544)9544,60711,9555)9528)9526,9483)314293,9478)376913,((30608,30608)30608,30611)376911)9443,((((((10090,10090,10090,10091,39442)10090,10096)862507,10116)39107,10020,43179)33553,10141)9989,(9978,9986)9975)314147,37347)314146,(((9615,9646,9669)379584,9685)33554,((9913,9940)9895,30538,9739,9823)91561,(132908,59463)9397,(42254,9365)9362,9796)314145)1437010,(9358,9361)9348,(9371,9785,9813)311790)9347,(13616,9305,9315)9263)32525,9258)40674,((((((9031,9031)9031,9103)9005,8839)1549675,(59729,59894)9126)8825,13735)1329799,28377)32561)32524,8364)32523,7897)8287,(((((((48698,8083)586240,8090)1489913,8128)1489908,((31033,99883)31031,69293)1489922)1489872,8049)123368,(7955,7994)186626)186625,7918)41665)117571,(51511,7719)7718)7711,(6239,7227)1206794)33213,4932)33154,((((4565,4565,4565,4565,4565)4565,4572)4564,37682)1648030,112509)147389)2759';
    is(tree_as_gdb_newick($new_root), $ng, 'tree_as_gdb_newick');
    is(tree_as_tax_newick($new_root), $nt, 'tree_as_tax_newick');

    $new_root = Bio::EnsEMBL::Compara::Utils::SpeciesTree->create_species_tree(
        -COMPARA_DBA => $dba,
        -ALLOW_SUBTAXA => 1,
        -MULTIFURCATION_DELETES_ALL_SUBNODES => [9347],
    );
    ok($new_root, 'Made a tree');
    $ng = '((((((((((((((142,157),112),144),(145,87)),136),111),(((108,109,115,117,118,122,123,124,125,131,132,134,135,138,139,147,149,150,151,153,155,158,159,160,162,165,172,174,31,33,48,49,55,58,60,61,67,69,78,79,80,82,83,84,85,98),(121,46,91)),43)),116),129),(((((((137,152),37),130),((4,65),36)),126),(146,154)),148)),(128,27)),(143,156)),127),((((2080,2081,2082,2083,2084),1983),1984),2088))';
    $nt = '((((((((((((((9031,9031)9031,9103)9005,8839)1549675,(59729,59894)9126)8825,13735)1329799,28377)32561,(((10020,10090,10090,10090,10091,10096,10116,10141,132908,30538,30608,30608,30611,37347,39442,42254,43179,59463,60711,61853,9358,9361,9365,9371,9478,9483,9544,9544,9555,9595,9598,9601,9606,9615,9646,9669,9685,9739,9785,9796,9813,9823,9913,9940,9978,9986)9347,(13616,9305,9315)9263)32525,9258)40674)32524,8364)32523,7897)8287,(((((((48698,8083)586240,8090)1489913,8128)1489908,((31033,99883)31031,69293)1489922)1489872,8049)123368,(7955,7994)186626)186625,7918)41665)117571,(51511,7719)7718)7711,(6239,7227)1206794)33213,4932)33154,((((4565,4565,4565,4565,4565)4565,4572)4564,37682)1648030,112509)147389)2759';
    is(tree_as_gdb_newick($new_root), $ng, 'tree_as_gdb_newick');
    is(tree_as_tax_newick($new_root), $nt, 'tree_as_tax_newick');
    #warn tree_as_gdb_newick($new_root);
    #warn tree_as_tax_newick($new_root);

    $nt_a->_id_cache->clear_cache();
};

sub timetree_equals {
    my ($a, $b) = @_;
    if ((defined $a) and (defined $b)) {
        ok(abs($a-$b) < 0.01, "Timetree equal: $a vs $b");
    } else {
        fail('Timetree not equal: got an undef');
    }
}

sub interpolate_test {
    my ($taxa_for_tree, $timetree_interpolated) = @_;
    my $new_root = Bio::EnsEMBL::Compara::Utils::SpeciesTree->create_species_tree(
        -COMPARA_DBA => $dba,
        -ALLOW_SUBTAXA => 1,
        -NO_PREVIOUS => 1,
        -EXTRATAXON_SEQUENCED => $taxa_for_tree,
    );
    $new_root->print_tree(0.002);

    # Reset everything
    my %timetree_backup;
    foreach my $n (@{$new_root->get_all_nodes}) {
        $n->adaptor($stn_a);
        $n->distance_to_parent($n->has_parent ? 1 : 0);
        if ($timetree_interpolated->{$n->taxon_id}) {
            $n->taxon->remove_tag('ensembl timetree mya');
        } elsif ($n->taxon->has_tag('ensembl timetree mya')) {
            $timetree_backup{$n->taxon_id} = $n->taxon->get_value_for_tag('ensembl timetree mya');
        }
    }
    Bio::EnsEMBL::Compara::Utils::SpeciesTree::interpolate_timetree($new_root);
    foreach my $n (@{$new_root->get_all_nodes}) {
        if ($timetree_interpolated->{$n->taxon_id}) {
            timetree_equals($n->taxon->get_value_for_tag('ensembl timetree mya'), $timetree_interpolated->{$n->taxon_id});
        } elsif ($timetree_backup{$n->taxon_id}) {
            timetree_equals($n->taxon->get_value_for_tag('ensembl timetree mya'), $timetree_backup{$n->taxon_id});
        } elsif ($n->taxon->has_tag('ensembl timetree mya')) {
            fail('No expectation for '.$n->taxon_id);
        }
    }
}

subtest 'interpolate_timetree' => sub {
    #ok(1); return;

    # Test setting the root from 1 sample
    interpolate_test( [8083, 48698, 8090], { 1489913 => 60 } );

    # Test setting the root from 2 samples
    interpolate_test( [8083, 48698, 8090, 8128], { 1489908 => 116.7 } );

    # Test interpolating an intermediate node (just above a leaf)
    interpolate_test( [8083, 48698, 8090], { 586240 => 50 } );

    # Test interpolating an intermediate node (just above an internal node)
    interpolate_test( [8083, 48698, 8090, 8128], { 1489913 => 71.9 } );

    # Test interpolating several intermediate nodes
    interpolate_test( [8083, 48698, 8090, 8128], { 1489913 => 69.2, 586240 => 34.6 } );

    # Test interpolating several intermediate nodes, forming two sub-trees
    interpolate_test( [59463, 132908, 9365, 42254], { 9397 => 45.9, 9362 => 45.9 } );

    # Cannot interpolate if no data at all
    throws_ok {interpolate_test([8083, 48698], {586240 => 'X'})} qr/Need at least 1 data-point to extrapolate divergence times/;

};

sub is_ultrametric {
    my $root = shift;
    my @todo = map {[$_, 0]} @{$root->children};
    is(scalar(@todo), 2, 'Binary root node');
    my $ref_path = undef;
    while (my $a = shift @todo) {
        my ($c, $d) = @$a;
        like($c->distance_to_parent, qr/^\d+$/, $c->distance_to_parent.' is an integer');
        ok($c->distance_to_parent >= 1, 'Non-zero branch');
        if ($c->is_leaf) {
            $d += $c->distance_to_parent;
            if ($ref_path) {
                is($d, $ref_path, 'Same distance from root to leaf');
            } else {
                $ref_path = $d;
            }
        } else {
            #is(scalar(@{$c->children}), 2, 'Binary internal node');
            push @todo, [$_, $d+$c->distance_to_parent] for @{$c->children};
        }
    }
    ok($ref_path, 'Ultrametric tree');
}

subtest 'Ultrametrisation and consensus from gene-trees' => sub {
    #ok(1); return;

    my $mlss = $dba->get_MethodLinkSpeciesSetAdaptor->fetch_by_dbID(40101);
    my $species_tree_root = $mlss->species_tree->root;
    my $cet_node = $species_tree_root->find_node_by_node_id(40101049);  # Cetartiodactyla

    $_->distance_to_parent($_->has_parent ? 1 : 0) for @{$species_tree_root->get_all_nodes};

    # Wrong dbID space (protein vs ncrna) -> no topology
    my $ngts = $dba->get_GeneTreeAdaptor->fetch_all(-TREE_TYPE => 'tree', -MEMBER_TYPE => 'ncrna', -CLUSTERSET_ID => 'default');
    throws_ok {Bio::EnsEMBL::Compara::Utils::SpeciesTree::binarize_multifurcation_using_gene_trees($cet_node, $ngts)}
                qr/No topology found for Cetartiodactyla/;

    my $gts = $dba->get_GeneTreeAdaptor->fetch_all(-TREE_TYPE => 'tree', -METHOD_LINK_SPECIES_SET => $mlss);

    # Right dbID space but this tree doesn't have data for Cetartiodactyla
    throws_ok {Bio::EnsEMBL::Compara::Utils::SpeciesTree::binarize_multifurcation_using_gene_trees($cet_node, [grep {$_->clusterset_id eq 'default'} @$gts])}
                qr/No topology found for Cetartiodactyla/;

    $_->preload for @$gts;

    Bio::EnsEMBL::Compara::Utils::SpeciesTree::set_branch_lengths_from_gene_trees($species_tree_root, $gts);
    Bio::EnsEMBL::Compara::Utils::SpeciesTree::binarize_multifurcation_using_gene_trees($_, $gts) for @{$species_tree_root->get_all_nodes};
    Bio::EnsEMBL::Compara::Utils::SpeciesTree::ultrametrize_from_branch_lengths($species_tree_root);
    is_ultrametric($species_tree_root);

    $cet_node->taxon->remove_tag('ensembl timetree mya');   # Will force assigning some values
    Bio::EnsEMBL::Compara::Utils::SpeciesTree::ultrametrize_from_timetree($species_tree_root);
    is_ultrametric($species_tree_root);

    $_->release_tree for @$gts;
};

subtest 'get_timetree_estimate_for_node' => sub {
    #ok(1); return;

    my $cet_taxon = $nt_a->fetch_by_dbID(91561);
    my $timetree = Bio::EnsEMBL::Compara::Utils::SpeciesTree->get_timetree_estimate_for_node($cet_taxon);
    is($timetree, 16394);

    my $hum_taxon = $nt_a->fetch_by_dbID(9606);  # Human has no subspecies in the test database
    $timetree = Bio::EnsEMBL::Compara::Utils::SpeciesTree->get_timetree_estimate_for_node($hum_taxon);
    is($timetree, 0);

    my $fol_taxon = $nt_a->fetch_by_dbID(948953);   # Monofurcation
    warning_like {
        $timetree = Bio::EnsEMBL::Compara::Utils::SpeciesTree->get_timetree_estimate_for_node($fol_taxon);
    } qr/'Folivora' has a single child. Cannot estimate the divergence time of a non-furcating node/;
    is($timetree, undef);

    my $cet_node = $stn_a->fetch_by_dbID(40101049);  # Cetartiodactyla
    $timetree = Bio::EnsEMBL::Compara::Utils::SpeciesTree->get_timetree_estimate_for_node($cet_node);
    is($timetree, 16394);

    my $laur_node = $stn_a->fetch_by_dbID(40101163);    # Laurasiatheria
    $timetree = Bio::EnsEMBL::Compara::Utils::SpeciesTree->get_timetree_estimate_for_node($laur_node);
    is($timetree, undef);

    $_->taxon_id(314145) for @{$laur_node->children};
    $timetree = Bio::EnsEMBL::Compara::Utils::SpeciesTree->get_timetree_estimate_for_node($laur_node);
    is($timetree, 0);

    $_->taxon_id(0) for @{$laur_node->children};
    $timetree = Bio::EnsEMBL::Compara::Utils::SpeciesTree->get_timetree_estimate_for_node($laur_node);
    is($timetree, undef);
};

done_testing();

package Bio::EnsEMBL::Compara::Utils::SpeciesTree;

# Overrides get from LWP::Simple
sub get ($) {   ## no critic
    my $url = shift;
    my $html_template = q{BLABLA
    <h1 style="margin-bottom: 0px;">%s</h1> Million Years Ago
BLABLA};
    warn $url;
    return '' if $url =~ /Bos/;
    return sprintf($html_template, '') if $url =~ /Equus/;
    return sprintf($html_template, '16394');
}


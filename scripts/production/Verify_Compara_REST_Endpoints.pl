#!/usr/bin/env perl
# Copyright [1999-2015] Wellcome Trust Sanger Institute and the EMBL-European Bioinformatics Institute
# Copyright [2016-2019] EMBL-European Bioinformatics Institute
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

#example:  perl Verify_Compara_REST_Endpoints.pl <server address>


use LWP;
use HTTP::Tiny;
use JSON qw(decode_json);
use XML::Simple;
use Bio::TreeIO;
use IO::String;
use Test::More;
use Test::Differences;
use strict;
use warnings;
use Data::Dumper;
use Try::Tiny;
use Getopt::Long;

my $browser = HTTP::Tiny->new('timeout' => 300);
my $server = 'https://rest.ensembl.org';
my $division;
my ( $skip_genetrees, $skip_cafe, $skip_alignments, $skip_epo, $skip_lastz, $skip_families, $skip_homology );

GetOptions( 
    "server=s"        => \$server, 
    "division=s"      => \$division,
    'skip_genetrees'  => \$skip_genetrees,
    'skip_cafe'       => \$skip_cafe,
    'skip_alignments' => \$skip_alignments,
    'skip_epo'        => \$skip_epo,
    'skip_lastz'      => \$skip_lastz,
    'skip_families'   => \$skip_families,
    'skip_homology'   => \$skip_homology,
);

if ( !$server or !$division ) {
    die "Usage: perl $0 --division [vertebrates|plants] --server [https://rest.ensembl.org]";
}

my $responseIDGet = $browser->get( ( $server . '/info/ping?content-type=application/json' ), { headers => { 'Content-type' => 'application/json', 'Accept' => 'application/json' } } );
die "Server unavailable - please check your URL\n" unless $responseIDGet->{status} == 200;

my ($gene_member_id, $gene_tree_id, $gene_tree_member_id, $alignment_region, $lastz_alignment_region);
my ($species_1, $species_2, $species_3, $taxon_1, $taxon_2, $taxon_3);
my ($gene_symbol, $species_set_group);
my $extra_params;

if ($division eq "vertebrates"){
    $gene_member_id           = "ENSG00000157764";
    $gene_tree_id             = "ENSGT00390000003602";
    $gene_tree_member_id      = "";
    $alignment_region         = "2:106040000-106040050:1";
    $lastz_alignment_region   = "2:106041430-106041480:1";

    $species_1                = "homo_sapiens";
    $species_2                = "macaca_mulatta";
    $species_3                = "pan_troglodytes";

    $taxon_1                  = 9606;#homo_sapiens
    $taxon_2                  = 9544;#macaca_mulatta
    $taxon_3                  = 9598;#pan_troglodytes

    $gene_symbol              = "BRCA2";
    $species_set_group        = "primates";
}
elsif($division eq "plants"){
    $gene_member_id           = "AT3G52430";
    $gene_tree_id             = "EPlGT00140000000744";
    $gene_tree_member_id      = "AT3G52430";
    $alignment_region         = "1:8001-18000:1";
    $lastz_alignment_region   = $alignment_region;

    $species_1                = "arabidopsis_thaliana";
    $species_2                = "vitis_vinifera";
    $species_3                = "oryza_barthii";

    $taxon_1                  = 3702;#arabidopsis_thaliana
    $taxon_2                  = 29760;#vitis_vinifera
    $taxon_3                  = 65489;#oryza_barthii

    $gene_symbol              = "PAD4";
    $species_set_group        = "rosids";
    
    $extra_params             = 'compara=plants';
    $skip_families            = 1;
    $skip_epo                 = 1;
}

my $anyErrors = 0;
my ($jsontxt, $xml, $nh, $orthoXml, $phyloXml, $json_leaf);
my $sleepTime = 0;


# FIXME: replace all tabs with spaces

# FIXME: all process_*_get functions have the same structure -> factor out !

sub process_nh_get {
    my ($url, $content_type) = @_;
    $content_type ||= 'text/x-nh';
    my $result = process_get($url, $content_type);
    return $result;
}

sub process_orthoXml_get {
    my ($url, $content_type) = @_;
    $content_type ||= 'text/x-orthoxml+xml';
    my $result = process_get($url, $content_type);
    return $result;
}

sub process_phyloXml_get {
    my ($url, $content_type) = @_;
    $content_type ||= 'text/x-phyloxml+xml';
    my $result = process_get($url, $content_type);
    return $result;
}

sub process_json_get {
    my ($url, $content_type) = @_;
    $content_type ||= 'application/json';
    my $result = process_get($url, $content_type);
    return $result;
}

sub process_get {
    my ($url, $content_type) = @_;
    my ($try_decode);
    if (!$content_type) {
         die "Input argument error   - no content type argument provided ";
    }

    my $responseIDGet = $browser->get($url, { headers => {'Content-type' => $content_type } } );

    if($responseIDGet->{status} == 200){
        try {
            if ($content_type eq 'application/json') {
                $try_decode = decode_json($responseIDGet->{content});
            }
            elsif ($content_type eq 'text/x-phyloxml+xml') {
                $try_decode = XMLin($responseIDGet->{content});
            }
            elsif ($content_type eq 'text/x-orthoxml+xml') {
                $try_decode = XMLin($responseIDGet->{content});
            }
            elsif ($content_type eq 'text/x-nh') {
                my $io = IO::String->new($responseIDGet->{content});
                my $treeio = Bio::TreeIO->new(-fh => $io, -format => 'newick');
                $try_decode = $treeio->next_tree;
            }
            else {
                die "Input argument error   - the argument provided does not match any of the output options expected";
            }
        }
        catch {
            print STDERR "ERROR\n";
            return "";
        };

        sleep($sleepTime);
        return $try_decode;
    }
    elsif($responseIDGet->{status} == 400){
        return 0;
    }
    elsif($responseIDGet->{status} == 599){
        die "Unsuccessful Request - Error Code: ". $responseIDGet->{status}. " - is your server ";
    }
    else{
        die "Unsuccessful Request - Error Code: ". $responseIDGet->{status};
    }
}

sub find_leaf {
    my ($node, $leaf_name) = @_;
    if (exists $node->{children}) {
        return map {find_leaf($_, $leaf_name)} @{$node->{children}};
    } elsif ($node->{id}->{accession} eq $leaf_name) {
        return ($node,);
    } else {
        return (),
    }
}


#fetch_leaf_hash_from_json
#takes as input a json_hash of a gene tree
#traverses the gene tree hash to return an hash of a leaf node
sub fetch_leaf_hash_from_json {

    my ($input_json) = @_;
    while (exists $input_json->{children}) {
        $input_json = $input_json->{children}[0];
    }
    return $input_json;
}

sub verify_xml_leaf {
    my ($this_node, $species_name) = @_;
    my $nodes = ref($this_node) eq 'ARRAY' ? $this_node : [$this_node];

    foreach my $node ( @$nodes ) {
        if ( exists $node->{property} ) {
            return 1 if ($node->{property}->{content} // '') eq $species_name;
        }

        if ( exists $node->{clade} ) {
            my $verify_recursive = verify_xml_leaf($node->{clade}, $species_name);
            return 1 if $verify_recursive;
        } else {
            foreach my $value ( values %$node ) {
                return 1 if ($value->{property}->{content} // '') eq $species_name;
            }
        }
    }
    return 0;
}

#Compara currently have no POST requests. For future purposes.


my ( @pruned_species, %pruned_species );

try{
    print "\nTesting " . $server."\n";

    print "\n\#\#\# Compara REST endpoint TESTS \#\#\#\n";

    unless ( $skip_genetrees ) {
        print "\nTesting GET genetree\/id\/\:id \n\n";

        #### ID GET ####
        my $ext = "/genetree/id/$gene_tree_id";
        $ext .= "?$extra_params" if $extra_params;

        my $responseIDGet = $browser->get($server.$ext, { headers => { 'Content-type' => 'application/json' } } );
        ok($responseIDGet->{success}, "Check JSON Validity");

        $responseIDGet = $browser->get($server.$ext, { headers => { 'Content-type' => 'text/x-phyloxml+xml' } } );
        ok($responseIDGet->{success}, "Check phyloXml Validity");

        $responseIDGet = $browser->get($server.$ext, { headers => { 'Content-type' => 'text/x-orthoxml+xml' } } );
        ok($responseIDGet->{success}, "Check orthoXml Validity");

        $responseIDGet = $browser->get($server.$ext, { headers => {'Content-type' => 'text/x-nh'} });
        ok($responseIDGet->{success}, "Check New Hampshire NH Validity");

        $jsontxt = process_json_get($server."/genetree/id/$gene_tree_id?content-type=application/json&aligned=1".($extra_params ? ";$extra_params" : ''));
        $json_leaf = fetch_leaf_hash_from_json($jsontxt->{tree});
        ok($jsontxt && $json_leaf->{sequence}->{mol_seq}->{is_aligned} == 1, "Check seqs alignment == 1 Validity");

        $jsontxt = process_json_get($server."/genetree/id/$gene_tree_id?content-type=application/json&aligned=0".($extra_params ? ";$extra_params" : ''));
        $json_leaf = fetch_leaf_hash_from_json($jsontxt->{tree});
        ok($jsontxt && $json_leaf->{sequence}->{mol_seq}->{is_aligned} == 0, "Check seqs alignment == 0 Validity");

        $jsontxt = process_json_get($server."/genetree/id/$gene_tree_id?content-type=application/json&cigar_line=1".($extra_params ? ";$extra_params" : ''));
        $json_leaf = fetch_leaf_hash_from_json($jsontxt->{tree});
        ok($jsontxt && $json_leaf->{sequence}->{mol_seq}->{cigar_line}, "Check cigar line == 1 Validity");

        $jsontxt = process_json_get($server."/genetree/id/$gene_tree_id?content-type=application/json&cigar_line=0".($extra_params ? ";$extra_params" : ''));
        $json_leaf = fetch_leaf_hash_from_json($jsontxt->{tree});
        ok($jsontxt && ! exists $json_leaf->{sequence}->{mol_seq}->{cigar_line}, "Check cigar line == 0 Validity");

        $ext = "/genetree/id/$gene_tree_id?content-type=text/javascript&callback=thisisatest".($extra_params ? ";$extra_params" : '');
        $responseIDGet = $browser->get($server.$ext, { headers => { 'Content-type' => 'text/javascript' } } );
        ok((substr($responseIDGet->{'content'}, 0, 11) eq "thisisatest"), "Check Callback Validity");

        $phyloXml = process_phyloXml_get($server."/genetree/id/$gene_tree_id?content-type=text/x-phyloxml+xml;prune_species=$species_1;prune_species=$species_3".($extra_params ? ";$extra_params" : ''));
        ok( verify_xml_leaf($phyloXml->{phylogeny}, $species_1) && verify_xml_leaf($phyloXml->{phylogeny}, $species_3) , "check prune species Validity");

        $orthoXml = process_orthoXml_get($server."/genetree/id/$gene_tree_id?content-type=text/x-orthoxml+xml;prune_taxon=$taxon_1;prune_taxon=$taxon_2;prune_taxon=$taxon_3".($extra_params ? ";$extra_params" : ''));
        @pruned_species = keys %{ $orthoXml->{species} };
        %pruned_species = map {$_ => 1} @pruned_species;
        ok( (exists($pruned_species{$species_2})) && (exists($pruned_species{$species_3})) && (exists($pruned_species{$species_1} )), "check prune taxon Validity");


        $jsontxt = process_json_get($server."/genetree/id/$gene_tree_id?content-type=application/json;sequence=none".($extra_params ? ";$extra_params" : ''));
    #    diag explain $jsontxt;
        $json_leaf = fetch_leaf_hash_from_json($jsontxt->{tree});
        ok($jsontxt && !(exists $json_leaf->{mol_seq}), "check sequence eq none Validity");


        print "\nTesting GET genetree by member\/id\/\:id \n\n";

        $ext = "/genetree/member/id/$gene_member_id";
        $ext .= "?$extra_params" if $extra_params;

        $responseIDGet = $browser->get($server.$ext, { headers => { 'Content-type' => 'application/json' } } );
        ok($responseIDGet->{success}, "Check JSON Validity");

        $responseIDGet = $browser->get($server.$ext, { headers => { 'Content-type' => 'text/x-phyloxml+xml' } } );
        ok($responseIDGet->{success}, "Check phyloXml Validity");

        $responseIDGet = $browser->get($server.$ext, { headers => { 'Content-type' => 'text/x-orthoxml+xml' } } );
        ok($responseIDGet->{success}, "Check orthoXml Validity");

        $responseIDGet = $browser->get($server.$ext, { headers => { 'Content-type' => 'text/x-nh' } } );
        ok($responseIDGet->{success}, "Check New Hampshire NH Validity");

        $jsontxt = process_json_get($server."/genetree/member/id/$gene_member_id?content-type=application/json".($extra_params ? ";$extra_params" : ''));
        ok($jsontxt->{tree}, "check gene tree member  Validity");


        print "\nTesting GET genetree by member symbol\/\:species\/\:symbol \n\n";

        $ext = "/genetree/member/symbol/$species_1/$gene_symbol";
        $ext .= "?$extra_params" if $extra_params;

        $responseIDGet = $browser->get($server.$ext, { headers => { 'Content-type' => 'application/json' } } );
        ok($responseIDGet->{success}, "Check JSON Validity");

        $responseIDGet = $browser->get($server.$ext, { headers => { 'Content-type' => 'text/x-phyloxml+xml' } } );
        ok($responseIDGet->{success}, "Check phyloXml Validity");

        $responseIDGet = $browser->get($server.$ext, { headers => { 'Content-type' => 'text/x-nh' } } );
        ok($responseIDGet->{success}, "Check New Hampshire NH Validity");

        $orthoXml = process_orthoXml_get($server."/genetree/member/symbol/$species_1/$gene_symbol?prune_species=$species_1;prune_species=$species_2;content-type=text/x-orthoxml%2Bxml;prune_taxon=$taxon_3".($extra_params ? ";$extra_params" : ''));
        @pruned_species = keys %{ $orthoXml->{species} };
        %pruned_species = map {$_ => 1} @pruned_species;
        ok((exists($pruned_species{$species_1})) && (exists($pruned_species{$species_2})) && (exists($pruned_species{$species_3} )), "Check gene tree by symbol Validity");
    }
    
    unless ( $skip_genetrees || $skip_cafe ) {
        print "\nTesting GET Cafe tree\/id\/\:id \n\n";

        my $ext = "/cafe/genetree/id/$gene_tree_id";
        $ext .= "?$extra_params" if $extra_params;

        $responseIDGet = $browser->get($server.$ext, { headers => { 'Content-type' => 'application/json' } } );
        ok($responseIDGet->{success}, "Check JSON Validity");

        $responseIDGet = $browser->get($server.$ext, { headers => { 'Content-type' => 'text/x-nh' } } );
        ok($responseIDGet->{success}, "Check New Hampshire NH Validity");

        $nh = process_nh_get($server."/cafe/genetree/id/$gene_tree_id?content-type=text/x-nh;nh_format=simple".($extra_params ? ";$extra_params" : ''));
        ok(scalar $nh->get_leaf_nodes, "check cafe tree nh simple format Validity");

        print "\nTesting GET Cafe tree by member\/id\/\:id \n\n";

        $ext = "/cafe/genetree/member/id/$gene_member_id";
        $ext .= "?$extra_params" if $extra_params;

        $responseIDGet = $browser->get($server.$ext, { headers => { 'Content-type' => 'application/json' } } );
        ok($responseIDGet->{success}, "Check JSON Validity");

        $responseIDGet = $browser->get($server.$ext, { headers => { 'Content-type' => 'text/x-nh' } } );
        ok($responseIDGet->{success}, "Check New Hampshire NH Validity");


        $jsontxt = process_json_get($server."/cafe/genetree/member/id/$gene_member_id?content-type=application/json".($extra_params ? ";$extra_params" : ''));
        ok(exists $jsontxt->{pvalue_avg}, "Check get cafe tree by transcript member Validity");


        print "\nTesting GET Cafe tree by member symbol\/:species\/\:symbol \n\n";

        $ext = "/cafe/genetree/member/symbol/$species_1/$gene_symbol";
        $ext .= "?$extra_params" if $extra_params;

        $responseIDGet = $browser->get($server.$ext, { headers => { 'Content-type' => 'application/json' } } );
        ok($responseIDGet->{success}, "Check JSON Validity");

        $responseIDGet = $browser->get($server.$ext, { headers => { 'Content-type' => 'text/x-nh' } } );
        ok($responseIDGet->{success}, "Check New Hampshire NH Validity");

        $nh = process_nh_get($server."/cafe/genetree/member/symbol/$species_1/$gene_symbol?content-type=text/x-nh;nh_format=simple".($extra_params ? ";$extra_params" : ''));
        ok($nh->get_leaf_nodes, "Check get cafe tree member by symbol Validity");
    }

    unless ( $skip_families ) {
        print "\nTesting GET family\/id\/\:id \n\n";

        my $ext = '/family/id/TF660629';
        $ext .= "?$extra_params" if $extra_params;

        $responseIDGet = $browser->get($server.$ext, { headers => { 'Content-type' => 'application/json' } } );
        ok($responseIDGet->{success}, "Check JSON Validity");

        $jsontxt = process_json_get($server.'/family/id/TF660629?content-type=application/json'.($extra_params ? ";$extra_params" : ''));
        ok($jsontxt->{family_stable_id} eq 'TF660629', "Check get family Validity");

        $jsontxt = process_json_get($server.'/family/id/TF660629?content-type=application/json;member_source=uniprot'.($extra_params ? ";$extra_params" : ''));
        ok( (index($jsontxt->{members}[0]->{source_name}, 'Uniprot') != -1 ), "Check get family UNIPROT memeber filter Validity");

        $jsontxt = process_json_get($server.'/family/id/TF660629?content-type=application/json;member_source=ensembl'.($extra_params ? ";$extra_params" : ''));
        ok( ($jsontxt->{members}[0]->{source_name} eq 'ENSEMBLPEP' ) , "Check get family ensembl member filter Validity");

        $jsontxt = process_json_get($server.'/family/id/TF660629?content-type=application/json;member_source=ensembl;aligned=1'.($extra_params ? ";$extra_params" : ''));
        ok( exists($jsontxt->{members}[0]->{protein_alignment}), "Check get family aligned == 1 Validity");

        $jsontxt = process_json_get($server.'/family/id/TF660629?content-type=application/json;member_source=ensembl;aligned=0'.($extra_params ? ";$extra_params" : ''));
        ok( exists ($jsontxt->{members}[0]->{protein_seq}), "Check get family aligned == 0 Validity");


        print "\nTesting GET family member\/id\/\:id \n\n";

        $ext = "/family/member/id/$gene_member_id";
        $ext .= "?$extra_params" if $extra_params;

        $responseIDGet = $browser->get($server.$ext, { headers => { 'Content-type' => 'application/json' } } );
        ok($responseIDGet->{success}, "Check JSON Validity");


        $jsontxt = process_json_get($server."/family/member/id/$gene_member_id?content-type=application/json;aligned=0;sequence=none".($extra_params ? ";$extra_params" : ''));
        ok($jsontxt->{1}->{family_stable_id}, "Check get family by member Validity");


        print "\nTesting GET family member by species symbol\/:species\/\:symbol \n\n";

        $ext = "/family/member/symbol/$species_1/$gene_symbol";
        $ext .= "?$extra_params" if $extra_params;

        $responseIDGet = $browser->get($server.$ext, { headers => { 'Content-type' => 'application/json' } } );
        ok($responseIDGet->{success}, "Check JSON Validity");

        $jsontxt = process_json_get($server."/family/member/symbol/$species_1/$gene_symbol?content-type=application/json;aligned=0;sequence=none;member_source=ensembl".($extra_params ? ";$extra_params" : ''));
        ok($jsontxt->{1}->{family_stable_id}, "Check family member by species symbol Validity");
    }

    # EPO not working until web roll out correct ensembl_ancestral!
    unless ( $skip_alignments || $skip_epo ) {
        print "\nTesting GET EPO alignment region\/\:species\/\:region \n\n";
    
        my $ext = "/alignment/region/$species_1/$alignment_region?species_set_group=$species_set_group";
        $ext .= "?$extra_params" if $extra_params;

        $responseIDGet = $browser->get($server.$ext, { headers => { 'Content-type' => 'application/json' } } );
        ok($responseIDGet->{success}, "Check json Validity");
    
        $responseIDGet = $browser->get($server.$ext, { headers => { 'Content-type' => 'text/x-phyloxml+xml' } } );
        ok($responseIDGet->{success}, "Check phyloXml Validity");
    
        print $server.$ext.';content-type=text/x-phyloxml;aligned=0' . "\n";
        $phyloXml = process_phyloXml_get($server.$ext.';content-type=text/x-phyloxml;aligned=0'.($extra_params ? ";$extra_params" : ''));
        print Dumper $phyloXml;
        ok($phyloXml->{phylogeny}->{clade}->{sequence}->{mol_seq}->{is_aligned} == 0, "Check get alignment region and unaligned sequences");
    
        $jsontxt = process_json_get($server."/alignment/region/$species_1/$lastz_alignment_region?content-type=application/json;display_species_set=$species_1".($extra_params ? ";$extra_params" : ''));
        ok($jsontxt->[0]->{alignments}[0]->{species} eq $species_1, "Check alignment region display_species_set option Validity");
    
        print "\nTesting GET alignment region\/\:species\/\:region on HAL file\n\n";
    
        $ext = '/alignment/region/rattus_norvegicus/2:56040000-56040100:1?method=CACTUS_HAL;species_set_group=murinae'.($extra_params ? ";$extra_params" : '');
        $responseIDGet = $browser->get($server.$ext, { headers => { 'Content-type' => 'application/json' } } );
        ok($responseIDGet->{success}, "Check json Validity");
    
        $responseIDGet = $browser->get($server.$ext, { headers => { 'Content-type' => 'text/x-phyloxml+xml' } } );
        ok($responseIDGet->{success}, "Check phyloXml Validity");
    
        $responseIDGet = $browser->get($server.$ext.';aligned=0', { headers => { 'Content-type' => 'text/x-phyloxml+xml' } } );
        ok($responseIDGet->{success}, "Check phyloXml Validity with unaligned sequences");
    }

    unless ( $skip_alignments || $skip_lastz ) {
        $jsontxt = process_json_get($server."/alignment/region/$species_1/$lastz_alignment_region?content-type=application/json;method=LASTZ_NET;species_set=$species_1;species_set=$species_2".($extra_params ? ";$extra_params" : ''));
        ok( index($jsontxt->[0]->{tree},"$species_1") !=-1 && index($jsontxt->[0]->{tree},$species_2) !=-1, "Check get alignment region method option");
    }

    unless ( $skip_homology ) {
        print "\nTesting GET homology \/id\/\:id \n\n";

        my $ext = "/homology/id/$gene_member_id";
        $ext .= "?$extra_params" if $extra_params;

        $responseIDGet = $browser->get($server.$ext, { headers => {'Content-type' => 'application/json' } } );
        ok($responseIDGet->{success}, "Check JSON Validity");

        $responseIDGet = $browser->get($server.$ext, { headers => {'Content-type' => 'text/x-orthoxml+xml'} } );
        ok($responseIDGet->{success}, "Check orthoXml Validity");

        $jsontxt = process_json_get($server."/homology/id/$gene_member_id?content-type=application/json;target_taxon=$taxon_2".($extra_params ? ";$extra_params" : ''));
        ok( $jsontxt->{data}[0]->{homologies}[0]->{target}->{taxon_id} == $taxon_2 , "Check homology endpoint target_taxon option Validity");

        $orthoXml = process_orthoXml_get($server."/homology/id/$gene_member_id?content-type=text/x-orthoxml+xml;target_species=$species_1;target_species=$species_2;target_species=$species_3;".($extra_params ? ";$extra_params" : ''));
        @pruned_species = keys %{ $orthoXml->{species} };
        %pruned_species = map {$_ => 1} @pruned_species;
        ok((exists($pruned_species{$species_1})) && (exists($pruned_species{$species_2})) && (exists($pruned_species{$species_3} )), "Check homology endpoint target species option Validity");

        $jsontxt = process_json_get($server."/homology/id/$gene_member_id?content-type=application/json;sequence=cdna".($extra_params ? ";$extra_params" : ''));
        ok( index($jsontxt->{data}[0]->{homologies}[0]->{source}->{align_seq}, 'M') == -1 , "Check homology endpoint sequence CDNA option Validity");

        $jsontxt = process_json_get($server."/homology/id/$gene_member_id?content-type=application/json;sequence=protein".($extra_params ? ";$extra_params" : ''));
        ok( index($jsontxt->{data}[0]->{homologies}[0]->{source}->{align_seq}, 'M') != -1 , "Check homology endpoint sequence protein option Validity");

        $jsontxt = process_json_get($server."/homology/id/$gene_member_id?content-type=application/json;aligned=0;sequence=none".($extra_params ? ";$extra_params" : ''));
        ok( !(exists $jsontxt->{data}[0]->{homologies}[0]->{source}->{seq}), "Check homology endpoint sequence none option Validity");

        $jsontxt = process_json_get($server."/homology/id/$gene_member_id?content-type=text/x-orthoxml+xml;type=orthologues".($extra_params ? ";$extra_params" : ''));
        ok( $jsontxt->{data}[0]->{homologies}[0]->{method_link_type} eq 'ENSEMBL_ORTHOLOGUES', "Check homology endpoint type option Validity");

        $jsontxt = process_json_get($server."/homology/id/$gene_member_id?content-type=application/json;aligned=0".($extra_params ? ";$extra_params" : ''));
        ok( !(exists $jsontxt->{data}[0]->{homologies}[0]->{source}->{align_seq}), "Check homology endpoint aligned =0 option Validity");

        $jsontxt = process_json_get($server."/homology/id/$gene_member_id?content-type=application/json;cigar_line=1".($extra_params ? ";$extra_params" : ''));
        ok( exists $jsontxt->{data}[0]->{homologies}[0]->{source}->{cigar_line} , "Check homology endpoint cigar line =1 Validity");

        $jsontxt = process_json_get($server."/homology/id/$gene_member_id?content-type=application/json;cigar_line=0".($extra_params ? ";$extra_params" : ''));
        ok( !(exists $jsontxt->{data}[0]->{homologies}[0]->{source}->{cigar_line}) , "Check homology endpoint cigar line =1 Validity");

        $jsontxt = process_json_get($server."/homology/id/$gene_member_id?content-type=application/json;format=condensed".($extra_params ? ";$extra_params" : ''));
        ok(!(exists $jsontxt->{data}[0]->{homologies}[0]->{source}), "Check homology endpoint format Validity");

        print "\nTesting GET homology by symbol and species\/\:species\/\:symbol \n\n";

        $jsontxt = process_json_get($server."/homology/symbol/$species_1/$gene_symbol?content-type=application/json".($extra_params ? ";$extra_params" : ''));
        ok((exists $jsontxt->{data}[0]->{homologies}[0]->{source}), "Check homology species symbol endpoint format Validity");

        $orthoXml = process_orthoXml_get($server."/homology/symbol/$species_1/$gene_symbol?target_taxon=$taxon_2;content-type=text/x-orthoxml+xml;format=condensed;target_species=$species_3;type=orthologues".($extra_params ? ";$extra_params" : ''));
        @pruned_species = keys %{ $orthoXml->{species} };
        %pruned_species = map {$_ => 1} @pruned_species;
        ok((exists($pruned_species{$species_1})) && (exists($pruned_species{$species_2})) && (exists($pruned_species{$species_3} )), "Check homology species symbol endpoint target species option Validity");
    }

}catch{
    warn "caught error: $_";
};

done_testing();

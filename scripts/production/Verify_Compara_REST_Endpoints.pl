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

#example:  perl Verify_Compara_REST_Endpoints.pl <server address>

 
use LWP;
use HTTP::Tiny;
use JSON qw(decode_json);
use Test::More;
use Test::Differences;
use strict;
use warnings;
use Data::Dumper;
use Try::Tiny;
use feature 'say';

my $browser = HTTP::Tiny->new('timeout' => 300);
my $anyErrors = 0;

my ($jsontxt, $xml, $nh, $orthoXml, $phyloXml);
my $response = "";
my $server = "";
my $num_args = $#ARGV + 1;
my $sleepTime = 0;

print "\nXXXX\n", $server, "\n\n";

my $subtree_result = '(((((ENSPFOP00000011979:0.015457,ENSXMAP00000013387:0.032852):0.065319,ENSORLP00000021821:0.073657):0.015707,ENSONIP00000005406:0.108887):0.018218,ENSGACP00000005150:0.056991):0.026746,((ENSTNIP00000020640:0.003661,ENSTNIP00000004507:0.047464):0.07026,ENSTRUP00000013256:0.094795):0.065814):0.05792;';

if ($num_args >= 2) {
    print "\nUsage: VerifyRestEndpoints.pl REST_server_location\n";
    exit;
}
elsif($num_args == 1){
    $server = $ARGV[0];
    my $responseIDGet = $browser->get(($server.'/info/ping?content-type=application/json'), {
	headers => {
      'Content-type' => 'application/json',
          'Accept' => 'application/json',
	},
				      });
    die "Server unavailable - please check your URL\n" unless $responseIDGet->{status} == 200;
}
else{
    $server = 'https://rest.ensembl.org';
}

#wont be using this as we can guarantee the newick tree will be returned in the same order all the time
sub process_nh_get {
    my ($url, $content_type) = @_;
    $content_type ||= 'text/x-nh';
    my $result = "";
    my $responseIDGet = $browser->get($url, {
	headers => {
      'Content-type' => 'text/x-nh'
	},
				      });

#    print Dumper($responseIDGet) , "\n\n\n";
    if($responseIDGet->{status} == 200){
	try{
	    $result = $responseIDGet->{content};
	} catch{
	    print STDERR "ERROR\n";
	    return "";
	};
#	print $result , "\n\n";
	sleep($sleepTime);
	if(ref($result) eq 'ARRAY'){
	    return defined(@$result[0]) ? $result : ""; #Yo. learn this
	}
	else{
	    return $result;
	}
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

sub process_orthoXml_get {
    my ($url, $content_type) = @_;
    $content_type ||= 'text/x-nh';
    my $result = "";
    my $responseIDGet = $browser->get($url, {
	headers => {
      'Content-type' => 'text/x-orthoxml+xml'
	},
				      });

#    print Dumper($responseIDGet) , "\n\n\n";
    if($responseIDGet->{status} == 200){
	try{
	    $result = $responseIDGet->{content};
	} catch{
	    print STDERR "ERROR\n";
	    return "";
	};
#	print $result , "\n\n";
	sleep($sleepTime);
	if(ref($result) eq 'ARRAY'){
	    return defined(@$result[0]) ? $result : ""; #Yo. learn this
	}
	else{
	    return $result;
	}
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

sub process_phyloXml_get {
    my ($url, $content_type) = @_;
    $content_type ||= 'text/x-nh';
    my $result = "";
    my $responseIDGet = $browser->get($url, {
	headers => {
      'Content-type' => 'text/x-phyloxml+xml'
	},
				      });

#    print Dumper($responseIDGet) , "\n\n\n";
    if($responseIDGet->{status} == 200){
	try{
	    $result = $responseIDGet->{content};
	} catch{
	    print STDERR "ERROR\n";
	    return "";
	};
#	print $result , "\n\n";
	sleep($sleepTime);
	if(ref($result) eq 'ARRAY'){
	    return defined(@$result[0]) ? $result : ""; #Yo. learn this
	}
	else{
	    return $result;
	}
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

sub process_json_get {
    my ($url, $content_type) = @_;
    $content_type ||= 'application/json';
    my $try_decode = "";
    my $responseIDGet = $browser->get($url, {
	headers => {
      'Content-type' => 'application/json',
      'Accept' => 'application/json',
	},
				      });

    if($responseIDGet->{status} == 200){
	try{
	    $try_decode = decode_json($responseIDGet->{content});
	} catch{
	    print STDERR "ERROR\n";
	    return "";
	};
	sleep($sleepTime);
	if(ref($try_decode) eq 'ARRAY'){
	    return defined(@$try_decode[0]) ? $try_decode : "";
	}
	else{
	    return $try_decode;
	}
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


#Compara currently have no POST requests. For future purposes.



try{
    print "\nTesting " . $server."\n";

    print "\n\#\#\# Compara REST endpoint TESTS \#\#\#\n";

    print "\nTesting GET genetree\/id\/\:id \n\n";


#### ID GET ####
    my $ext = '/genetree/id/ENSGT00390000003602';
    my $responseIDGet = $browser->get($server.$ext, {
	headers => {
	        'Content-type' => 'application/json',
	},
				      });

    ok($responseIDGet->{success}, "Check JSON Validity");

    $responseIDGet = $browser->get($server.$ext, {
	headers => {
	        'Content-type' => 'text/x-phyloxml+xml',
	},
				      });

    ok($responseIDGet->{success}, "Check phyloXml Validity");

    $responseIDGet = $browser->get($server.$ext, {
	headers => {
	        'Content-type' => 'text/x-orthoxml+xml',
	},
				      });

    ok($responseIDGet->{success}, "Check orthoXml Validity");

    $responseIDGet = $browser->get($server.$ext, {
	headers => {
	        'Content-type' => 'text/x-nh',
	},
				      });

    ok($responseIDGet->{success}, "Check New Hampshire NH Validity");

    $jsontxt = process_json_get($server.'/genetree/id/RF01168?content-type=application/json&aligned=1');
 #  print Dumper($jsontxt->{tree}->{children});
#	say keys $jsontxt->{tree}->{children}[0]->{children}[0]->{children}[0]->{children}[0]->{children}[0]->{children}[0]->{children}[0]->{children}[0];
	ok($jsontxt && $jsontxt->{tree}->{children}[0]->{children}[0]->{children}[0]->{children}[0]->{children}[0]->{children}[0]->{children}[0]->{children}[0]->{sequence}->{mol_seq}->{is_aligned}, "Check seqs alignment Validity");

	$jsontxt = process_json_get($server.'/genetree/id/RF01168?content-type=application/json&cigar_line=1');
	ok($jsontxt && $jsontxt->{tree}->{children}[0]->{children}[0]->{children}[0]->{children}[0]->{children}[0]->{children}[0]->{children}[0]->{children}[0]->{sequence}->{mol_seq}->{cigar_line}, "Check cigar line Validity");

	$ext = '/genetree/id/RF01168?content-type=text/javascript&callback=thisisatest';
    $responseIDGet = $browser->get($server.$ext, {
	headers => {
	    'Content-type' => 'text/javascript',
	},
				   });
    ok((substr($responseIDGet->{'content'}, 0, 11) eq "thisisatest"), "Check Callback Validity");

	$phyloXml = process_phyloXml_get($server.'/genetree/id/RF01168?content-type=text/x-phyloxml+xml;prune_species=Macaque;prune_species=human;prune_species=Chimpanzee');
	ok($phyloXml && (index($phyloXml,'ENST00000459475') !=-1), "check prune species Validity");
#	diag $nh;
	$orthoXml = process_orthoXml_get($server.'/genetree/id/RF01168?content-type=text/x-orthoxml+xml;prune_taxon=9598;prune_taxon=9544;prune_taxon=9606');
	ok($orthoXml && $orthoXml =~ 'ENSMMUT00000052798', "check prune taxon Validity");
	
	$nh = process_nh_get($server.'/genetree/id/ENSGT00390000003602?content-type=text/x-nh&subtree_node_id=11416568');
	is($nh, $subtree_result, "Check subtree Validity"); #I am wary of this test as I am not sure the nodes in the string will always be returned in the same other

	$jsontxt = process_json_get($server.'/genetree/id/RF01168?content-type=application/json;prune_species=Macaque;prune_species=human;prune_species=Chimpanzee;sequence=none');
#	diag explain $jsontxt;
	ok($jsontxt && (index($jsontxt, 'mol_seq') == -1), "check sequence eq none Validity");

	print "\nTesting GET genetree by member\/id\/\:id \n\n";

	$ext = '/genetree/member/id/ENSG00000157764';
    $responseIDGet = $browser->get($server.$ext, {
	headers => {
	        'Content-type' => 'application/json',
	},
				      });

    ok($responseIDGet->{success}, "Check JSON Validity");

    $responseIDGet = $browser->get($server.$ext, {
	headers => {
	        'Content-type' => 'text/x-phyloxml+xml',
	},
				      });

    ok($responseIDGet->{success}, "Check phyloXml Validity");

    $responseIDGet = $browser->get($server.$ext, {
	headers => {
	        'Content-type' => 'text/x-orthoxml+xml',
	},
				      });

    ok($responseIDGet->{success}, "Check orthoXml Validity");

    $responseIDGet = $browser->get($server.$ext, {
	headers => {
	        'Content-type' => 'text/x-nh',
	},
				      });
    ok($responseIDGet->{success}, "Check New Hampshire NH Validity");

    $jsontxt = process_json_get($server.'/genetree/member/id/ENSMUSG00000017167?content-type=application/json;subtree_node_id=4385998');
    ok($jsontxt->{tree}, "check gene tree member  Validity");

    $phyloXml = process_phyloXml_get($server.'/genetree/member/id/ENSMUSG00000017167?content-type=text/x-phyloxml+xml');
    ok($phyloXml, "check gene tree member phyloXml Validity");

    print "\nTesting GET genetree by member symbol\/\:species\/\:symbol \n\n";

	$ext = '/genetree/member/symbol/homo_sapiens/BRCA2';
    $responseIDGet = $browser->get($server.$ext, {
	headers => {
	        'Content-type' => 'application/json',
	},
				      });

    ok($responseIDGet->{success}, "Check JSON Validity");

    $responseIDGet = $browser->get($server.$ext, {
	headers => {
	        'Content-type' => 'text/x-phyloxml+xml',
	},
				      });

    ok($responseIDGet->{success}, "Check phyloXml Validity");

    $responseIDGet = $browser->get($server.$ext, {
	headers => {
	        'Content-type' => 'text/x-nh',
	},
				      });
    ok($responseIDGet->{success}, "Check New Hampshire NH Validity");

    $orthoXml = process_orthoXml_get($server.'/genetree/member/symbol/homo_sapiens/BRCA2?prune_species=cow;content-type=text/x-orthoxml%2Bxml;prune_taxon=9526');
    ok($orthoXml, "Check gene tree by symbol Validity");


	print "\nTesting GET Cafe tree\/id\/\:id \n\n";

	$ext = '/cafe/genetree/id/ENSGT00390000003602';
    $responseIDGet = $browser->get($server.$ext, {
	headers => {
	        'Content-type' => 'application/json',
	},
				      });

    ok($responseIDGet->{success}, "Check JSON Validity");

    $responseIDGet = $browser->get($server.$ext, {
	headers => {
	        'Content-type' => 'text/x-nh',
	},
				      });
    ok($responseIDGet->{success}, "Check New Hampshire NH Validity");

    $nh = process_nh_get($server.'/cafe/genetree/id/ENSGT00390000003602?content-type=text/x-nh;nh_format=simple');
    ok($nh, "check cafe tree nh simple format Validity");

    print "\nTesting GET Cafe tree by member\/id\/\:id \n\n";

	$ext = '/cafe/genetree/member/id/ENSG00000157764';
    $responseIDGet = $browser->get($server.$ext, {
	headers => {
	        'Content-type' => 'application/json',
	},
				      });

    ok($responseIDGet->{success}, "Check JSON Validity");

    $responseIDGet = $browser->get($server.$ext, {
	headers => {
	        'Content-type' => 'text/x-nh',
	},
				      });
    ok($responseIDGet->{success}, "Check New Hampshire NH Validity");


    $jsontxt = process_json_get($server.'/cafe/genetree/member/id/ENSMUST00000103109?content-type=application/json');
    ok(exists $jsontxt->{pvalue_avg}, "Check get cafe tree by transcript member Validity");


	print "\nTesting GET Cafe tree by member symbol\/:species\/\:symbol \n\n";

	$ext = '/cafe/genetree/member/symbol/homo_sapiens/BRCA2';
    $responseIDGet = $browser->get($server.$ext, {
	headers => {
	        'Content-type' => 'application/json',
	},
				      });

    ok($responseIDGet->{success}, "Check JSON Validity");

    $responseIDGet = $browser->get($server.$ext, {
	headers => {
	        'Content-type' => 'text/x-nh',
	},
				      });
    ok($responseIDGet->{success}, "Check New Hampshire NH Validity");

    $nh = process_nh_get($server.'/cafe/genetree/member/symbol/homo_sapiens/BRCA2?content-type=text/x-nh;nh_format=simple');
    ok($nh, "Check get cafe tree member by symbol Validity");

    print "\nTesting GET family\/id\/\:id \n\n";

	$ext = '/family/id/PTHR15573';
    $responseIDGet = $browser->get($server.$ext, {
	headers => {
	        'Content-type' => 'application/json',
	},
				      });

    ok($responseIDGet->{success}, "Check JSON Validity");

    $jsontxt = process_json_get($server.'/family/id/PTHR15573?content-type=application/json');
    ok($jsontxt->{type} eq 'family', "Check get family Validity");

    $jsontxt = process_json_get($server.'/family/id/TF625635?content-type=application/json;member_source=uniprot');
    ok($jsontxt->{MEMBERS}->{UNIPROT_proteins}, "Check get family UNIPROT memeber filter Validity");

    $jsontxt = process_json_get($server.'/family/id/TF625635?content-type=application/json;member_source=ensembl');
    ok($jsontxt->{MEMBERS}->{ENSEMBL_gene_members}, "Check get family ensembl member filter Validity");

    $jsontxt = process_json_get($server.'/family/id/TF625635?content-type=application/json;member_source=ensembl;aligned=0');
    ok($jsontxt->{MEMBERS}->{ENSEMBL_gene_members}->{ENSLACG00000022687}[0]->{seq}, "Check get family aligned option Validity");

    print "\nTesting GET family member\/id\/\:id \n\n";

	$ext = '/family/member/id/ENSG00000157764';
    $responseIDGet = $browser->get($server.$ext, {
	headers => {
	        'Content-type' => 'application/json',
	},
				      });
    ok($responseIDGet->{success}, "Check JSON Validity");


	$jsontxt = process_json_get($server.'/family/member/id/ENSG00000157764?content-type=application/json;aligned=0;sequence=none');
	ok($jsontxt->{1}->{type} eq 'family', "Check get family by member Validity");


	print "\nTesting GET family member by species symbol\/:species\/\:symbol \n\n";

	$ext = '/family/member/symbol/homo_sapiens/BRCA2';
    $responseIDGet = $browser->get($server.$ext, {
	headers => {
	        'Content-type' => 'application/json',
	},
				      });

    ok($responseIDGet->{success}, "Check JSON Validity");

	$jsontxt = process_json_get($server.'/family/member/symbol/homo_sapiens/BRCA2?content-type=application/json;aligned=0;sequence=none;member_source=ensembl');
	ok($jsontxt->{1}->{type} eq 'family', "Check family member by species symbol Validity");


	print "\nTesting GET alignment region\/\:species\/\:region \n\n";

	$ext = '/alignment/region/taeniopygia_guttata/2:106040000-106040050:1?species_set_group=sauropsids';
    $responseIDGet = $browser->get($server.$ext, {
	headers => {
	        'Content-type' => 'application/json',
	},
				      });
    ok($responseIDGet->{success}, "Check json Validity");

    $responseIDGet = $browser->get($server.$ext, {
	headers => {
	        'Content-type' => 'text/x-phyloxml+xml',
	},
				      });
    ok($responseIDGet->{success}, "Check phyloXml Validity");


    $phyloXml = process_phyloXml_get($server.'/alignment/region/taeniopygia_guttata/2:106040000-106040050:1?content-type=text/x-phyloxml;species_set_group=sauropsids;aligned=1');
    ok($phyloXml, "Check get alignment region and align the sequences");

    $jsontxt = process_json_get($server.'/alignment/region/taeniopygia_guttata/2:106041430-106041480:1?content-type=application/json;method=LASTZ_NET;species_set=taeniopygia_guttata;species_set=gallus_gallus');
    ok($jsontxt->[0]->{alignments}[0]->{species}, "Check get alignment region method option");

    $jsontxt = process_json_get($server.'/alignment/region/taeniopygia_guttata/2:106040000-106040050:1?content-type=application/json;species_set_group=sauropsids;display_species_set=chicken');
    ok($jsontxt->[0]->{alignments}[0]->{species} eq 'gallus_gallus', "Check alignment region display_species_set option Validity");



    print "\nTesting GET homology \/id\/\:id \n\n";

	$ext = '/homology/id/ENSG00000157764';
    $responseIDGet = $browser->get($server.$ext, {
	headers => {
	        'Content-type' => 'application/json',
	},
				      });

    ok($responseIDGet->{success}, "Check JSON Validity");

    $responseIDGet = $browser->get($server.$ext, {
	headers => {
	        'Content-type' => 'text/x-orthoxml+xml',
	},
				      });

    ok($responseIDGet->{success}, "Check orthoXml Validity");


    $jsontxt = process_json_get($server.'/homology/id/ENSG00000157764?target_taxon=10090;content-type=application/json');
    ok($jsontxt->{data}[0]->{homologies}[0]->{source}, "Check homology endpoint target_taxon option Validity");

    $jsontxt = process_json_get($server.'/homology/id/ENSG00000157764?content-type=application/json;target_species=cow');
    ok($jsontxt->{data}[0]->{homologies}[0]->{source}, "Check homology endpoint target_species option Validity");

    $jsontxt = process_json_get($server.'/homology/id/ENSG00000157764?content-type=application/json;sequence=cdna;');
    ok($jsontxt->{data}[0]->{homologies}[0]->{source}, "Check homology endpoint sequence option Validity");

    $orthoXml = process_orthoXml_get($server.'/homology/id/ENSG00000157764?content-type=text/x-orthoxml+xml;type=orthologues');
    ok($orthoXml, "Check homology endpoint type option Validity");

    $jsontxt = process_json_get($server.'/homology/id/ENSG00000157764?content-type=application/json;target_species=cow;aligned=0;cigar_line=1');
    ok($jsontxt->{data}[0]->{homologies}[0]->{source}->{seq} && $jsontxt->{data}[0]->{homologies}[0]->{source}->{cigar_line} , "Check homology endpoint aligned & cigar line option Validity");

    $jsontxt = process_json_get($server.'/homology/id/ENSG00000157764?content-type=application/json;format=condensed');
    ok($jsontxt, "Check homology endpoint format Validity");
}catch{
    warn "caught error: $_"; 
};

done_testing();

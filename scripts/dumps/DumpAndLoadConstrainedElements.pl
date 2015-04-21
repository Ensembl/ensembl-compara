#!/usr/bin/perl -w
# Copyright [1999-2015] Wellcome Trust Sanger Institute and the EMBL-European Bioinformatics Institute
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


#DESCRIPTION
#transfers constrained elements data from old schema (pre-53) tables 
#(genomic_align and genomic_align_block) to new constrained_element 
#table (53 and later).
#

=head1 NAME

create_mlss.pl

=head1 AUTHORS

Stephen Fitzgerald

=head1 CONTACT

Please email comments or questions to the public Ensembl
developers list at <http://lists.ensembl.org/mailman/listinfo/dev>.

Questions may also be sent to the Ensembl help desk at
<http://www.ensembl.org/Help/Contact>.

=head1 DESCRIPTION

This script transfers constrained elements data from old schema (pre-53) tables
(genomic_align and genomic_align_block) to the constrained_element
table in the new schema (release 53 and later). 

=head1 SYNOPSIS

DumpAndLoadConstrainedElements.pl --old mysql://ensro@compara1:3306/ensembl_compara_52 --new mysql://ensadmin:<pass>@compara1:3306/ensembl_compara_53 --mlssid 339

it requires 3 args. 
1). the database to take the data from (--old) 

2). the database in which to insert the constrained elements (--new)

3). the method_link_species_set_id of the constrained elements (must be present in both databases). 		

=cut 

use strict;
use Bio::EnsEMBL::Registry;
use Bio::EnsEMBL::Compara::DBSQL::DBAdaptor;
use Bio::EnsEMBL::Utils::Exception qw(throw);
use Bio::EnsEMBL::Compara::ConstrainedElement;
use Getopt::Long;
use DBI;
use Data::Dumper; 

my ($help, $old_url, $new_url, $mlssid);

GetOptions(                
	"help" => \$help,
	"old=s" => \$old_url,                
	"new=s" => \$new_url,
        "mlssid=s" => \$mlssid,
);

if($help) {
	help();
}

sub help {        
	print STDERR 'Args:  --old mysql://ensro@compara1:3306/ensembl_compara_52', "\n", 
		     '       --new mysql://ensadmin:<pass>@compara1:3306/ensembl_compara_53', "\n",
		     "       --mlssid 339\n";
	die;
}

help() unless $old_url =~ s/^mysql\:\/\///;
help() unless $old_url =~ s/[\/@]/:/g;
help() unless $new_url =~ s/^mysql\:\/\///;
help() unless $new_url =~ s/[\/@]/:/g;
help() unless ($old_url=~ s/:/:/g == 3 && $new_url=~ s/:/:/g == 4);
die "** no mlssid defined **\n" unless defined ($mlssid);


my ($old_user,$old_host,$old_port,$old_db) = split(":", $old_url);
my ($new_user,$pass,$new_host,$new_port,$new_db) = split(":", $new_url);

my $old_dba = Bio::EnsEMBL::Compara::DBSQL::DBAdaptor->new (
	-user => $old_user,
	-host => $old_host,
	-port => $old_port,
	-dbname => $old_db,
	-species => "OLD",
);

my $new_dba = Bio::EnsEMBL::Compara::DBSQL::DBAdaptor->new (
	-user => $new_user,
	-pass => $pass,
	-host => $new_host,
	-port => $new_port,
	-dbname => $new_db,
	-species => "NEW",
);

my $old_dbh = DBI->connect("DBI:mysql:host=$old_host;port=$old_port;database=$old_db", $old_user) 
		or die "Couldn't connect to database: " . DBI->errstr;
my $new_dbh = DBI->connect("DBI:mysql:host=$new_host;port=$new_port;database=$new_db", $old_user) 
		or die "Couldn't connect to database: " . DBI->errstr;

my $old_mlss_adaptor = $old_dba->get_adaptor("MethodLinkSpeciesSet");
my $old_mlss = $old_mlss_adaptor->fetch_by_dbID($mlssid);
eval { $old_mlss->dbID };
die "$@$mlssid : no such mlssid in $old_db\@$old_host\n" if $@;
my ($taxonomic_level) = join(" ", $old_mlss->name=~/\b[a-z]+\b/g);

my $new_mlss_adaptor = $new_dba->get_adaptor("MethodLinkSpeciesSet");

die "$mlssid : no such mlssid in $new_url\n" unless defined($new_mlss_adaptor->fetch_by_dbID($mlssid));

my $ga_sql = "SELECT
	dnafrag_id, dnafrag_start, dnafrag_end
	FROM 
	genomic_align
	WHERE
	genomic_align_block_id = ?";

my $gab_sql = "SELECT 
	genomic_align_block_id, score
	FROM 
	genomic_align_block 
	WHERE 
	method_link_species_set_id = ?";

my $cel_sql = "SELECT
	COUNT(*) 
	FROM 
	constrained_element
	WHERE
	method_link_species_set_id = ?";

my $cel_sth = $new_dbh->prepare($cel_sql);
my $gab_sth = $old_dbh->prepare($gab_sql);
my $ga_sth = $old_dbh->prepare($ga_sql);
my $ce_adaptor = $new_dba->get_adaptor("ConstrainedElement");

$cel_sth->execute($mlssid);
if(my$db_entries = $cel_sth->fetchrow_arrayref->[0]) {
	printf("%d entries with mlssid %s were found in the constrained element table in %s. 
		Do you wish to delete them ? [y/N] ",$db_entries, $mlssid, $new_db);
	my $resp = <STDIN>;
	if ($resp !~ /^y$/i and $resp !~ /^yes$/i) {
		print "Cancelled.\n";
	}
	else {
		$ce_adaptor->delete_by_MethodLinkSpeciesSet($old_mlss);	
		print "Deleted.\n";
	}
}

$gab_sth->execute($mlssid);

while( my@gab = $gab_sth->fetchrow_array ) {
	my($gab_id, $score) = ($gab[0], $gab[1]);
	$ga_sth->execute($gab_id);
	my $constrained_element_block;
	while( my@ga = $ga_sth->fetchrow_array ) {
		my $constrained_element = new Bio::EnsEMBL::Compara::ConstrainedElement(
			-reference_dnafrag_id => $ga[0],
			-start => $ga[1],
			-end => $ga[2],
			-score => $score,
			-taxonomic_level => $taxonomic_level,
		);  
	push(@$constrained_element_block, $constrained_element);
	}
	$ce_adaptor->store($old_mlss, [ $constrained_element_block ]);	
}


#!/bin/env perl
# Copyright [1999-2016] Wellcome Trust Sanger Institute and the EMBL-European Bioinformatics Institute
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

use warnings;
use strict;
use Getopt::Long qw(:config pass_through);
use Bio::EnsEMBL::Registry;
use Bio::EnsEMBL::Utils::Exception qw(throw);
use Bio::EnsEMBL::Compara::DBSQL::XrefAssociationAdaptor;
use Data::Dumper;

my ( $reg_conf, $gene_tree_id, $help, $compara_name, $db_name );

GetOptions( 'help'               => \$help,
			'compara|c=s'       => \$compara_name,
			'db_name|n=s'       => \$db_name,
			'reg_conf|regfile=s' => \$reg_conf,
			'gene_tree_id|g=s' => \$gene_tree_id );

if ( $help or !$reg_conf or !$gene_tree_id or !$compara_name or !$db_name) {
	pod2usage(1);
}

Bio::EnsEMBL::Registry->load_all($reg_conf);

# get compara database
my ($compara) = grep {$_->dbc()->dbname() eq $compara_name} @{Bio::EnsEMBL::Registry->get_all_DBAdaptors(-GROUP=>'compara')};

throw("Could not find compara $compara_name") unless (defined $compara);

my $gene_tree_adaptor = $compara->get_GeneTreeAdaptor();

my $gt = $gene_tree_adaptor->fetch_by_stable_id($gene_tree_id);

 my $adaptor = Bio::EnsEMBL::Compara::DBSQL::XrefAssociationAdaptor->new($compara);
 
 for my $xref (@{$adaptor->get_associated_xrefs_for_tree($gt,$db_name)}) {
 	print "$xref\n";
 	for my $member (@{$adaptor->get_members_for_xref($gt,$xref,$db_name)}) {
 		print $member->stable_id()."\n"
 	}
 }
 my $stuff = $adaptor->get_all_member_associations($gt, $db_name);
 while( my($xref,$ms) = each %$stuff) {
 	print "$xref\n";
 	for my $member (@$ms) {
 		print $member->stable_id()."\n"
 	}
 }
 
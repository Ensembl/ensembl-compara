#!/usr/bin/env perl
# See the NOTICE file distributed with this work for additional information
# regarding copyright ownership.
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

use Getopt::Long;

use Bio::EnsEMBL::ApiVersion;
use Bio::EnsEMBL::Compara::DBSQL::DBAdaptor;
use Bio::EnsEMBL::Compara::Utils::SpeciesTree;

#
# Script to print the species-tree used by a given method
#

my $url;
my $mlss_id;
my $method = 'PROTEIN_TREES';
my $ss_name;
my $label = 'default';
my $stn_root_id;
my $format_mode;
my $with_distances;
my $ascii_scale;
my ($reg_conf, $compara_db);

GetOptions(
       'url=s'          => \$url,
       'mlss_id=s'      => \$mlss_id,
       'method=s'       => \$method,
       'ss_name=s'      => \$ss_name,
       'label=s'        => \$label,
       'stn_root_id=i'  => \$stn_root_id,
       'format_mode=s'  => \$format_mode,
       'with_distances' => \$with_distances,
       'ascii_scale=f'  => \$ascii_scale,
       'reg_conf=s'     => \$reg_conf,
       'compara_db=s'   => \$compara_db,
);

$compara_db = $url if !$compara_db && defined $url;

my $registry = 'Bio::EnsEMBL::Registry';
$registry->load_all($reg_conf, 0, 0, 0, "throw_if_missing") if $reg_conf;
my $compara_dba = Bio::EnsEMBL::Compara::DBSQL::DBAdaptor->go_figure_compara_dba( $compara_db ) or die "Must define a url or (reg_conf & alias)";

my $species_tree;
if ($stn_root_id) {
    $species_tree = $compara_dba->get_SpeciesTreeAdaptor->fetch_by_dbID($stn_root_id);
} elsif ($mlss_id) {
    my $mlss = $compara_dba->get_MethodLinkSpeciesSetAdaptor->fetch_by_dbID($mlss_id);
    die "Could not fetch a MLSS with dbID=$mlss_id\n" unless $mlss;
    $species_tree = $mlss->species_tree($label);
} elsif ($method) {
    my $mlss;
    if ($ss_name) {
        $mlss = $compara_dba->get_MethodLinkSpeciesSetAdaptor->fetch_by_method_link_type_species_set_name($method, $ss_name);
        die "Could not fetch a MLSS with the method '$method' and the species set '$ss_name'\n" unless $mlss;
    } else {
        my $all_mlsss = $compara_dba->get_MethodLinkSpeciesSetAdaptor->fetch_all_by_method_link_type($method);
        die "Could not fetch a MLSS with the method '$method'\n" unless scalar(@$all_mlsss);
        die "Too many '$method' MLSSs. Set -ss_name to one of: ".join(", ", map {$_->species_set->name} @$all_mlsss) if scalar(@$all_mlsss) > 1;
        $mlss = $all_mlsss->[0];
    }
    $species_tree = $mlss->species_tree($label);
}

if ($ascii_scale) {
    $species_tree->root->print_tree($ascii_scale);
} elsif ($format_mode) {

    my @format_args;
    if ($format_mode =~ /^ryo\s+(?<ryo_string>.+)$/) {
        push(@format_args, ('ryo', $+{'ryo_string'}));
    } else {
        push(@format_args, $format_mode);
    }

    print $species_tree->root->newick_format( @format_args ), "\n";

} else {
    print $species_tree->root->newick_format( 'ryo', $with_distances ? '%{n}:%{d}' : '%{n}' ), "\n";
}


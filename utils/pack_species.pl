#!/usr/local/bin/perl
# Copyright [1999-2015] Wellcome Trust Sanger Institute and the EMBL-European Bioinformatics Institute
# Copyright [2016-2021] EMBL-European Bioinformatics Institute
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


#package EnsEMBL::Web::config_packer;
use FindBin qw($Bin);
use File::Basename qw(dirname);
#use strict;# use warnings;
use Data::Dumper;
use Storable qw(lock_nstore lock_retrieve thaw);

BEGIN{
  unshift @INC, "$Bin/../conf";
  eval{ require SiteDefs; SiteDefs->import; };
  if ($@){ die "Can't use SiteDefs.pm - $@\n"; }
  map{ unshift @INC, $_ } @SiteDefs::ENSEMBL_LIB_DIRS;
}

use EnsEMBL::Web::SpeciesDefs;
use EnsEMBL::Web::Root;

my $SD = new EnsEMBL::Web::SpeciesDefs;
my @species = @ARGV ? @ARGV : @{$SD->ENSEMBL_DATASETS};
my $root = new EnsEMBL::Web::Root;
my @modules;

$Data::Dumper::Indent = 1;

foreach my $part ( @{$SD->ENSEMBL_PLUGIN_ROOTS}, 'EnsEMBL::Web' ) {
  my $class_name = join '::', $part, 'config_packer_plugin';
  warn $class_name;
  unless( $root->dynamic_use( $class_name ) ) {
    my $message = $root->dynamic_use_failure( $class_name );
    warn $message unless $message =~ /Can't locate/;
  } else {
    my $T = $class_name->new();
    push @modules, { 'part' => $part, 'obj' => $T, 'methods' => $T->_methods };
  }
}

print Data::Dumper::Dumper( @modules );

foreach my $sp ( @species ) {
  warn "Parsing species $sp";
  my $species_tree = {};
  my $data_structure = { 'features' => {} };
  my $tree = $SD->{_storage}{$sp};
  my $dbhandle_hash = {};
  my $analysis_hash = {};
  foreach my $db_name ( qw(DATABASE_CORE DATABASE_VEGA DATABASE_OTHERFEATURES DATABASE_CDNA) ) {
    next unless $tree->{'databases'}->{$db_name}{'NAME'};
warn "... ",$tree->{'databases'}->{$db_name}{'NAME'};
    my $dbh = $SD->db_connect( $tree, $db_name );
    my $analyses = {
      map { $_->[0] => {
        'logic_name'    => $_->[1],
        'display_label' => $_->[2],
        'description'   => $_->[3],
        'displayable'   => $_->[4],
        'extra'         => $_->[5]?eval($_->[5]):undef,
      }} @{$dbh->selectall_arrayref(q(
        select a.analysis_id, a.logic_name, ad.display_label,
               ad.description, ad.displayable, ad.web_data
          from analysis as a left join analysis_description as ad on a.analysis_id = ad.analysis_id
      ))}
    };
    foreach my $mod ( @modules ) {
      foreach my $fn ( @{$mod->{'methods'}{'feature'}} ) {
warn "$mod->{'part'} - $fn ";
        $mod->{'obj'}->$fn({'dbh'=>$dbh,'key'=>$db_name,'analyses'=>$analyses,'species_tree'=>$species_tree});
      }
    }
  }
  
  open FH, ">conf/packed/$sp.packed.dd";
  my $obj = Data::Dumper->new([$species_tree],[qw(DATA)]);
  $obj->Deparse(1);
  $obj->Useqq(1);
  $obj->Terse(1);
  $obj->Indent(1);

  print FH $obj->Dump;
  close FH;
  lock_nstore( [$species_tree], "conf/packed/$sp.packed" );
}

1;

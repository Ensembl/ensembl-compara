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


use strict;

use DBI;
use File::Basename qw(dirname);
use FindBin qw($Bin);

BEGIN {
  my $serverroot = dirname($Bin);
  unshift @INC, "$serverroot/conf", $serverroot;

  require SiteDefs; SiteDefs->import;

  unshift @INC, $_ for @SiteDefs::ENSEMBL_LIB_DIRS;

  require EnsEMBL::Web::SpeciesDefs;
}

my $db = EnsEMBL::Web::SpeciesDefs->new->session_db;

my $dsn = sprintf(
  'DBI:mysql:database=%s;host=%s;port=%s',
  $db->{'NAME'},
  $db->{'HOST'},
  $db->{'PORT'},
);

my $dbh = DBI->connect(
  $dsn, $db->{'USER'}, $db->{'PASS'}
);

$dbh->do('CREATE TABLE session_record_tmp2 LIKE session_record');
$dbh->do('CREATE TABLE configuration_details_tmp LIKE configuration_details');
$dbh->do('CREATE TABLE configuration_record_tmp LIKE configuration_record');

$dbh->do('INSERT INTO session_record_tmp2 SELECT * FROM session_record WHERE type in ("image_config","view_config")');
$dbh->do('INSERT INTO configuration_details_tmp SELECT * FROM configuration_details order by record_id');
$dbh->do('INSERT INTO configuration_record_tmp SELECT * FROM configuration_record order by record_id');

my $sth = $dbh->prepare('select max(record_id)+1 from configuration_details_tmp');
$sth->execute;
my ($record_id) = $sth->fetchrow_array;


$sth = $dbh->prepare('SELECT session_id, type, code, data, created_at, modified_at FROM session_record_tmp2 where session_id');
$sth->execute;

my %records;
my %existing;
my @details;
my @records;
my @update;

# need to define the links
my %ic_links = (
  alignsliceviewbottom           => 'Location::Compara_Alignments',
  contigviewbottom               => 'Location::ViewBottom',
  contigviewtop                  => 'Location::ViewTop',
  cytoview                       => 'Location::Region',
  generegview                    => 'Gene::RegulationImage',
  GeneSNPView                    => 'Gene::GeneSNPImage',
  GeneSpliceView                 => 'Gene::GeneSpliceImage',
  gene_summary                   => 'Gene::TranscriptsImage',
  ldview                         => 'Location::LDImage',
  lrg_summary                    => 'LRG::TranscriptsImage',
  MultiBottom                    => 'Location::MultiBottom',
  MultiTop                       => 'Location::MultiTop',
  protview                       => 'Transcript::TranslationImage',
  regulation_view                => 'Regulation::FeaturesByCellLine',
  reg_detail                     => 'Regulation::FeatureDetails',
  reg_summary                    => 'Regulation::FeatureSummary',
  snpview                        => 'Variation::Context',
  structural_variation           => 'StructuralVariation::Context',
  supporting_evidence_transcript => 'Transcript::SupportingEvidence',
  Vkaryotype                     => 'Location::Genome',
  Vmapview                       => 'Location::ChromosomeImage',
);

my %vc_links = reverse %ic_links;

foreach (@{$sth->fetchall_arrayref}) {
  my ($session_id, $type, $code, $data, $created_at, $modified_at) = @$_;
  
  $records{$session_id}{$type}{$code} = {
    data        => $dbh->quote($data),
    created_at  => $created_at,
    modified_at => $modified_at
  };
}

foreach my $session_id (sort { $a <=> $b } keys %records) {
  foreach my $type (sort keys %{$records{$session_id}}) {
    foreach my $code (keys %{$records{$session_id}{$type}}) {
      my $record     = $records{$session_id}{$type}{$code};
      my $other_type = $type eq 'image_config' ? 'view_config' : 'image_config';
      my $link_code  = $type eq 'image_config' ? $ic_links{$code} : $vc_links{$code};
      
      push @details, "($record_id, 'session', $session_id, 'n', '', '', '', '')";
      push @records, sprintf "($record_id, '$type', '$code', 'y', %s, %s, $record->{data}, '$record->{created_at}', '$record->{modified_at}')", $record->{link_id} || 'NULL', $dbh->quote($link_code) || 'NULL';
      
      if ($link_code && $records{$session_id}{$other_type} && $records{$session_id}{$other_type}{$link_code}) {
        if ($record->{'link_id'}) {
         push @update, "UPDATE configuration_record_tmp SET link_id = $record_id WHERE record_id = $record->{'link_id'};";
        } else {
          $records{$session_id}{$other_type}{$link_code}{'link_id'} = $record_id;
        }
      }
      
      $record_id++;
    }
  }
}

while (@details) {
  my $values = join(',', splice(@details, 0, 10000));
  $dbh->do("INSERT INTO configuration_details_tmp (record_id, record_type, record_type_id, is_set, name, description, servername, release_number) VALUES $values");
}

while (@records) {
  my $values = join(',', splice(@records, 0, 10000));
  $dbh->do("INSERT INTO configuration_record_tmp (record_id, type, code, active, link_id, link_code, data, created_at, modified_at) VALUES $values");
}

$dbh->do($_) for @update;

$sth = $dbh->prepare('SELECT * FROM configuration_details');
$sth->execute;

foreach (@{$sth->fetchall_arrayref}) {
  my $id = shift @$_;
  $existing{$id}{'details'} = $_;
}

$sth = $dbh->prepare('SELECT * FROM configuration_record');
$sth->execute;

foreach (@{$sth->fetchall_arrayref}) {
  my $id = shift @$_;
  $existing{$id}{'record'} = $_;
}

$dbh->do('DELETE FROM session_record WHERE type in ("image_config","view_config")');

$dbh->do('RENAME TABLE configuration_details TO configuration_details2, configuration_details_tmp TO configuration_details');
$dbh->do('RENAME TABLE configuration_record TO configuration_record2, configuration_record_tmp TO configuration_record');
$dbh->do('DROP TABLE session_record_tmp2');
#$dbh->do('DROP TABLE configuration_details2'); ********* DO THIS MANUALLY ONCE YOU'VE CHECKED EVERYTHING IS OK *********
#$dbh->do('DROP TABLE configuration_record2');  ********* DO THIS MANUALLY ONCE YOU'VE CHECKED EVERYTHING IS OK *********

$dbh->do('OPTIMIZE TABLE session_record');
$dbh->do('OPTIMIZE TABLE configuration_details');
$dbh->do('OPTIMIZE TABLE configuration_record');

$dbh->disconnect;

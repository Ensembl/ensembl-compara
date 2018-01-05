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

use Bio::EnsEMBL::Registry;
use Getopt::Long;
use IO::Compress::Gzip qw(gzip $GzipError);
use Pod::Usage;
use Text::CSV;

my $OPTIONS = options();
my $DBA = _dba();

write_tsv();
compress();

sub options {
  my $opts = {};
  my @flags = qw(reg_conf=s database=s file=s overwrite gzip help man);
  GetOptions($opts, @flags) or pod2usage(1);
  
  _exit( undef, 0, 1) if $opts->{help};
	_exit( undef, 0, 2) if $opts->{man};
	
	_exit('No -database given', 1, 1) unless $opts->{database};
  _exit('No -reg_conf given', 1, 1) unless $opts->{reg_conf};
  _exit('No -file given', 1, 1) unless $opts->{file};
	
  return $opts;
}

sub write_tsv {
  
  my $file = $OPTIONS->{file};
  _file($file);
    
  open my $fh, '>', $file or confess("Cannot open $file for writing: $!");
  my $tsv = Text::CSV->new({sep_char => "\t", eol => "\n"});
  $tsv->print($fh, [qw(GeneTreeStableID EnsPeptideStableID EnsGeneStableID Canonical)]);
    
  my $sql = <<'SQL';
SELECT
    gtr.stable_id AS GeneTreeStableID,
    gm.stable_id AS EnsGeneStableID,
    pm.stable_id AS EnsPeptideStableID,
    CASE m.seq_member_id WHEN pm.seq_member_id THEN 'Y' ELSE 'N' END AS Canonical
FROM
    gene_tree_root gtr
    JOIN gene_tree_node gtn ON (gtr.root_id=gtn.root_id)
    JOIN seq_member m ON (gtn.seq_member_id=m.seq_member_id)
    JOIN gene_member gm ON (m.gene_member_id=gm.gene_member_id)
    JOIN seq_member pm ON (gm.gene_member_id=pm.gene_member_id) 
SQL

  $DBA->dbc->sql_helper->execute_no_return(
    -SQL => $sql,
    -CALLBACK => sub {
      my ($row) = @_;
      $tsv->print($fh, $row);
      return;
    }
  );
    
  close($fh);
  return;
}

sub compress {
  return unless $OPTIONS->{gzip};
  my $file = $OPTIONS->{file};
  my $file_gz = $file.'.gz';
  _file($file_gz);
  my $status = gzip $file => $file_gz, AutoClose => 1 
    or die "gzip failed: $GzipError\n";
  unlink $file;
  return;
}

sub _dba {
  my $registry = $OPTIONS->{reg_conf};
  Bio::EnsEMBL::Registry->load_all($registry);
  
  my $name = $OPTIONS->{database};
  my $dba = Bio::EnsEMBL::Registry->get_DBAdaptor($name, 'compara');
  _exit("No database adaptor found for ${name}. Check your settings and try again")
    unless defined $dba;
  return $dba;
}

sub _file {
  my ($file) = @_;
  if(-f $file) {
    if($OPTIONS->{overwrite}) {
      unlink $file;
    }
    else {
      _exit("File already exists at ${file}. Remove before proceeeding", 2, 1);
    }
  }
  return;
}

sub _exit {
  my ($msg, $status, $verbose) = @_;
  print STDERR $msg, "\n" if defined $msg;
  pod2usage( -exitstatus => $status, -verbose => $verbose );
}

__END__

=pod

=head1 NAME

DumpGeneTreeIdToGenePepIds

=head1 SYNOPSIS 

	./DumpGeneTreeIdToGenePepIds.pl -reg_conf REG -database DB -file FILE [-gzip] [-overwrite] [ --help | --man ]

=head1 DESCRIPTION

=head2 OPTIONS

=over 8

=item B<--reg_conf>

Registry file to use

=item B<--database>

The database reference to use

=item B<--file>

File to write to. Will create gzipped version with .gz added

=item B<--overwrite>

If specified the script will remove any existing file

=item B<--gzip>

If specified will force the code to GZip the produced file and will 
remove the uncompressed dump

=back

=cut

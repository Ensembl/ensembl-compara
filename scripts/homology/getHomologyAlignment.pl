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

=head1 NAME

getHomologyAlignment.pl

=head1 DESCRIPTION

This script retrieves the homology alignments for a gene.

=head1 SYNOPSIS

perl getHomologyAlignment.pl \
    --url mysql://ensro@mysql-ens-compara-prod-5:4617/ensembl_compara_plants_55_108 \
    --gene LR48_Vigan1529s000400 \
    --species vigna_angularis \
    --linewidth 60

=head1 OPTIONS

=over

=item B<[--help]>
Prints help message and exits.

=item B<[--url URL]>
(Mandatory) The mysql URL mysql://user@host:port/database_name

=item B<[--gene stable_id]>
(Mandatory) The gene_member stable_id. Requires --species parameter.

=item B<[--species genome]>
(Mandatory) The species name. Requires --gene parameter.

=item B<[--linewidth aa-line width]>
(Optional) Specify line width for amino acids in alignment dump.


=back

=cut

use strict;
use warnings;
use Getopt::Long;
use Pod::Usage;
use Bio::EnsEMBL::Compara::DBSQL::DBAdaptor;

my $self = {};

my $help;
$self->{'gene_stable_id'} = undef;
$self->{'species'} = undef;
my $aaPerLine = 60;

GetOptions(
  'url=s'       => \$self->{'url'},
  'gene=s'      => \$self->{'gene_stable_id'},
  'species=s'   => \$self->{'species'},
  'linewidth=i' => \$aaPerLine,
  'help'        => \$help,
) or pod2usage(-verbose => 2);
pod2usage(-exitvalue => 0, -verbose => 2) if $help;

if ( !defined $self->{'url'} ) {
  pod2usage(-exitvalue => 0, -verbose => 2);
}

if ( !defined $self->{'gene_stable_id'} or !defined $self->{'species'}) {
  pod2usage(-exitvalue => 0, -verbose => 2)
}

$self->{'comparaDBA'} = new Bio::EnsEMBL::Compara::DBSQL::DBAdaptor( -URL => $self->{'url'} );

my $gdb    = $self->{'comparaDBA'}->get_GenomeDBAdaptor->fetch_by_name_assembly($self->{'species'});
my $member = $self->{'comparaDBA'}->get_GeneMemberAdaptor->fetch_by_stable_id_GenomeDB($self->{'gene_stable_id'}, $gdb);

my ($homology) = @{$self->{'comparaDBA'}->get_HomologyAdaptor->fetch_all_by_Member($member, -TARGET_SPECIES => $self->{'species'})};

my $queryMA;
my $orthMA;

foreach my $other_member (@{$homology->get_all_Members}) {

  $other_member->{'gene'} = $other_member->gene_member;
  $other_member->{'peptide'} = $other_member;
  $other_member->{'pep_len'} = $other_member->{'peptide'}->seq_length;

  if($other_member->gene_member->dbID ne $member->dbID) {
    $orthMA = $other_member;
  } else {
    $queryMA = $other_member;
  }

}
print("Homology between ", $queryMA->{'gene'}->stable_id, "(",$queryMA->{'pep_len'}, ")" ,
      " and ", $orthMA->{'gene'}->stable_id, "(",$orthMA->{'pep_len'}, ")\n\n"); 

#
# now get the alignment region
#

my $alignment = $homology->get_SimpleAlign();

my ($seq1, $seq2)  = $alignment->each_seq;
my $seqStr1 = "|".$seq1->seq().'|';
my $seqStr2 = "|".$seq2->seq().'|';

my $label1 = sprintf("%20s : ", $seq1->id);
my $label2 = sprintf("%20s : ", "");
my $label3 = sprintf("%20s : ", $seq2->id);

my $line2 = "";
for(my $x=0; $x<length($seqStr1); $x++) {
  if(substr($seqStr1,$x,1) eq substr($seqStr2, $x,1)) { $line2.='|'; } else { $line2.=' '; }
}

my $offset=0;
my $numLines = (length($seqStr1) / $aaPerLine);
while($numLines>0) {
  printf("$label1 %s\n", substr($seqStr1,$offset,$aaPerLine));
  printf("$label2 %s\n", substr($line2,$offset,$aaPerLine));
  printf("$label3 %s\n", substr($seqStr2,$offset,$aaPerLine));
  print("\n\n");
  $offset+=$aaPerLine;
  $numLines--;
}

exit(0);

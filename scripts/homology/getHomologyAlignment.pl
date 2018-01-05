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
use Getopt::Long;
use Bio::EnsEMBL::Compara::DBSQL::DBAdaptor;

# ok this is a hack, but I'm going to pretend I've got an object here
# by creating a blessed hash ref and passing it around like an object
# this is to avoid using global variables in functions, and to consolidate
# the globals into a nice '$self' package
my $self = bless {};

$self->{'compara_conf'} = {};
$self->{'compara_conf'}->{'-user'} = 'ensro';
$self->{'compara_conf'}->{'-port'} = 3306;

$self->{'outputFasta'} = undef;
$self->{'noSplitSeqLines'} = undef;

my $aaPerLine = 60;
my ($help, $host, $user, $pass, $dbname, $port, $adaptor);

GetOptions('help'     => \$help,
           'dbhost=s' => \$host,
           'dbport=i' => \$port,
           'dbuser=s' => \$user,
           'dbpass=s' => \$pass,
           'dbname=s' => \$dbname,
           'g=s'      => \$self->{'gene_stable_id'},
	   'sp=s'     => \$self->{'species'},
	   'l=i'      => \$aaPerLine,
          );

if ($help) { usage(); }

$self->{'member_stable_id'} = shift if(@_);

if($host)   { $self->{'compara_conf'}->{'-host'}   = $host; }
if($port)   { $self->{'compara_conf'}->{'-port'}   = $port; }
if($dbname) { $self->{'compara_conf'}->{'-dbname'} = $dbname; }
if($user)   { $self->{'compara_conf'}->{'-user'}   = $user; }
if($pass)   { $self->{'compara_conf'}->{'-pass'}   = $pass; }


unless(defined($self->{'compara_conf'}->{'-host'})
       and defined($self->{'compara_conf'}->{'-user'})
       and defined($self->{'compara_conf'}->{'-dbname'}))
{
  print "\nERROR : must specify host, user, and database to connect to compara\n\n";
  usage(); 
}

unless(defined($self->{'gene_stable_id'}) and defined($self->{'species'})) 
{
  print "\nERROR : must specify query gene and target species\n\n";
  usage(); 
}

$self->{'comparaDBA'}  = new Bio::EnsEMBL::Compara::DBSQL::DBAdaptor(%{$self->{'compara_conf'}});

my $member;
$member = $self->{'comparaDBA'}->get_GeneMemberAdaptor->fetch_by_stable_id($self->{'gene_stable_id'});
#print $member->toString(), "\n" if($member);

my ($homology) = @{$self->{'comparaDBA'}->get_HomologyAdaptor->fetch_all_by_Member($member, -TARGET_SPECIES => $self->{'species'})};
#print $homology->toString(), "\n" if($homology);

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
#print($queryMA->{'peptide'}->sequence, "\n");
#print($orthMA->{'peptide'}->sequence, "\n");


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


#######################
#
# subroutines
#
#######################

sub usage {
  print "getHomologyAlignment.pl [options] <member stable_id>\n";
  print "  -help                  : print this help\n";
  print "  -dbhost <machine>      : compara mysql database host <machine>\n";
  print "  -dbport <port#>        : compara mysql port number\n";
  print "  -dbname <name>         : compara mysql database <name>\n";
  print "  -dbuser <name>         : compara mysql connection user <name>\n";
  print "  -dbpass <pass>         : compara mysql connection password\n";
  print "  -g <id>                : stable_id of query gene\n";
  print "  -sp <name>             : name of target species\n";
  print "  -l <num>               : number if bases per line for pretty output\n";
  print "getHomologyAlignment.pl v1.1\n";
  
  exit(1);  
}



#!/usr/local/ensembl/bin/perl -w

use strict;
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

$self->{'speciesList'} = ();
$self->{'removeXedSeqs'} = undef;
$self->{'outputFasta'} = undef;
$self->{'noSplitSeqLines'} = undef;

my $aaPerLine = 60;
my $conf_file;
my ($help, $host, $user, $pass, $dbname, $port, $adaptor);

GetOptions('help'     => \$help,
           'conf=s'   => \$conf_file,
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

parse_conf($self, $conf_file);

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
$member = $self->{'comparaDBA'}->get_MemberAdaptor->fetch_by_source_stable_id('ENSEMBLGENE', $self->{'gene_stable_id'});
#$member->print_member() if($member);

my ($homology) = @{$self->{'comparaDBA'}->get_HomologyAdaptor->fetch_by_Member_paired_species($member, $self->{'species'})};
#$homology->print_homology() if($homology);

my $queryMA;
my $orthMA;

foreach my $ma (@{$homology->get_all_Member_Attribute}) {
  my ($other_member, $attribute) = @{$ma};

  $attribute->{'gene'} = $other_member;
  $attribute->{'peptide'} = $self->{'comparaDBA'}->get_MemberAdaptor->fetch_by_dbID($attribute->peptide_member_id);
  $attribute->{'pep_len'} = $attribute->{'peptide'}->seq_length;

  if($other_member->dbID ne $member->dbID) {
    $orthMA = $attribute;
  } else {
    $queryMA = $attribute;
  }

}
print("Homology between ", $queryMA->{'gene'}->stable_id, "(",$queryMA->cigar_start, ",", $queryMA->cigar_end, ",", $queryMA->{'pep_len'}, ")" ,
      " and ", $orthMA->{'gene'}->stable_id, "(",$orthMA->cigar_start, ",", $orthMA->cigar_end, ",", $orthMA->{'pep_len'}, ")\n\n"); 
#print($queryMA->{'peptide'}->sequence, "\n");
#print($orthMA->{'peptide'}->sequence, "\n");


#
# now get the alignment region
#

my $alignment = $homology->get_SimpleAlign();

my ($seq1, $seq2)  = $alignment->each_seq;
my $seqStr1 = "|".$seq1->seq().'|';
my $seqStr2 = "|".$seq2->seq().'|';

if($queryMA->cigar_start>1) {
  my $missingSeq = substr($queryMA->{'peptide'}->sequence, 0, $queryMA->cigar_start-1);
  $seqStr1 = $missingSeq . $seqStr1;
}
if($orthMA->cigar_start>1) {
  my $missingSeq = substr($orthMA->{'peptide'}->sequence, 0, $orthMA->cigar_start-1);
  $seqStr2 = $missingSeq . $seqStr2;
}
my $startdiff = $orthMA->cigar_start - $queryMA->cigar_start;
while($startdiff>0) { $seqStr1 = " ".$seqStr1; $startdiff--; }
while($startdiff<0) { $seqStr2 = " ".$seqStr2; $startdiff++; }

if($queryMA->cigar_end < $queryMA->{'pep_len'}) {
  my $missingSeq = substr($queryMA->{'peptide'}->sequence, $queryMA->cigar_end, $queryMA->{'pep_len'}-$queryMA->cigar_end);
  $seqStr1 .= $missingSeq;
}
if($orthMA->cigar_end < $orthMA->{'pep_len'}) {
  my $missingSeq = substr($orthMA->{'peptide'}->sequence, $orthMA->cigar_end, $orthMA->{'pep_len'}-$orthMA->cigar_end);
  $seqStr2 .= $missingSeq;
}
my $enddiff = length($seqStr1) - length($seqStr2);
while($enddiff>0) { $seqStr2 .= " "; $enddiff--; }
while($enddiff<0) { $seqStr1 .= " "; $enddiff++; }


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
  print "  -conf <path>           : config file describing compara, templates, and external genome databases\n";
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


sub parse_conf {
  my $self      = shift;
  my $conf_file = shift;

  if($conf_file and (-e $conf_file)) {
    #read configuration file from disk
    my @conf_list = @{do $conf_file};

    foreach my $confPtr (@conf_list) {
      #print("HANDLE type " . $confPtr->{TYPE} . "\n");
      if($confPtr->{TYPE} eq 'COMPARA') {
        $self->{'compara_conf'} = $confPtr;
      }
      if($confPtr->{TYPE} eq 'BLAST_TEMPLATE') {
        $self->{'analysis_template'} = $confPtr;
      }
      if($confPtr->{TYPE} eq 'SPECIES') {
        push @{$self->{'speciesList'}}, $confPtr;
      }
    }
  }
}


sub dump_fasta {
  my $self = shift;

  my $sql = "SELECT member.stable_id, member.description, sequence.sequence " .
            " FROM member, sequence, source " .
            " WHERE member.source_id=source.source_id ".
            " AND source.source_name='ENSEMBLPEP' ".
            " AND member.sequence_id=sequence.sequence_id " .
            " GROUP BY member.member_id ORDER BY member.stable_id;";

  my $fastafile = $self->{'outputFasta'};
  open FASTAFILE, ">$fastafile"
    or die "Could open $fastafile for output\n";
  print("writing fasta to loc '$fastafile'\n");

  my $sth = $self->{'comparaDBA'}->prepare( $sql );
  $sth->execute();

  my ($stable_id, $description, $sequence);
  $sth->bind_columns( undef, \$stable_id, \$description, \$sequence );

  while( $sth->fetch() ) {
    $sequence =~ s/(.{72})/$1\n/g  unless($self->{'noSplitSeqLines'});

    #if removedXedSeqs defined then it contains the minimum num of
    # Xs in a row that is not acceptable, the regex X{#,}? says
    # if X occurs # or more times (not exhaustive search)
    unless($self->{'removeXedSeqs'} and
          ($sequence =~ /X{$self->{'removeXedSeqs'},}?/)) {
      print FASTAFILE ">$stable_id $description\n$sequence\n";
    }
  }
  close(FASTAFILE);

  $sth->finish();
}

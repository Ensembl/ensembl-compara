#!/usr/local/ensembl/bin/perl -w

use strict;
use Getopt::Long;
use IO::File;
use Bio::EnsEMBL::Compara::DBSQL::DBAdaptor;
use Bio::EnsEMBL::Compara::Family;
use Bio::EnsEMBL::Compara::Member;
use Bio::EnsEMBL::Compara::Taxon;
use Bio::EnsEMBL::Compara::Attribute;
use Bio::EnsEMBL::Slice;

$| = 1;

my $usage = "
Usage: $0 options mcl_file index_file desc_file redundancy_file

i.e.

$0 

Options:
-host 
-dbname family dbname
-dbuser
-dbpass
-prefix family stable id prefix (default: ENSF)
-offset family id numbering start (default:1)

\n";

my $help = 0 ;
my $family_source_name = "ENSEMBL_FAMILIES";
my $family_prefix = "ENSF";
my $family_offset = 1;
my $host;
my $port = "";
my $dbname;
my $dbuser;
my $dbpass;
my $conf_file;

GetOptions('help' => \$help,
	   'host=s' => \$host,
	   'port=i' => \$port,
	   'dbname=s' => \$dbname,
	   'dbuser=s' => \$dbuser,
	   'dbpass=s' => \$dbpass,
	   'prefix=s' => \$family_prefix,
	   'offset=i' => \$family_offset,
           'conf_file=s' => \$conf_file);

if ($help) {
  print $usage;
  exit 0;
}

unless (scalar @ARGV == 4) {
  print "Need 4 arguments\n";
  print $usage;
  exit 0;
}

my ($mcl_file,$index_file,$desc_file, $redunfile) = @ARGV;

my @clusters;
my %seqinfo;
my %member_index;
my %redun_hash;

my $db = new Bio::EnsEMBL::Compara::DBSQL::DBAdaptor(-host   => $host,
                                                     -port   => $port,
                                                     -user   => $dbuser,
                                                     -dbname => $dbname,
                                                     -pass => $dbpass,
                                                     -conf_file => $conf_file);

my $fa = $db->get_FamilyAdaptor;
my $gdb = $db->get_GenomeDBAdaptor;
my %genomedbs;
foreach my $genomedb (@{$gdb->fetch_all}) {
  $genomedbs{$genomedb->taxon_id} = $genomedb;
}

print STDERR "Reading index file...";

if ($index_file =~ /\.gz/) {
  open INDEX, "gunzip -c $index_file|" ||
    die "$index_file: $!";
} else {
  open INDEX, $index_file ||
    die "$index_file: $!";
}
my $max_member_index;

while (<INDEX>) {
  if (/^(\S+)\s+(\S+)/) {
    my ($index,$seqid) = ($1,$2);
    $member_index{$index} = $seqid;
    $seqinfo{$seqid}{'index'} = $index;
    unless (defined $max_member_index) {
      $max_member_index = $index;
    } elsif ($index > $max_member_index) {
      $max_member_index = $index;
    }
  } else {
    warn "$index_file has not the expected format
EXIT 1\n";
    exit 1;
  }
}
close INDEX
  || die "$index_file: $!";

print STDERR "Done\n";

print STDERR "Reading description file...";

if ($desc_file =~ /\.gz/) {
  open DESC, "gunzip -c $desc_file|" || 
    die "$desc_file: $!"; 
} else {
  open DESC, $desc_file ||
    die "$desc_file: $!";
}

while (<DESC>) {
  if (/^(.*)\t(.*)\t(.*)\t(.*)$/) {
    my ($type,$seqid,$desc,$taxon) = ($1,$2,$3,$4);
    if(!$taxon || !$seqid) {
      warn("taxon or seqid not defined, skipping description:\n".
           "\t[$type]\t[$seqid]\t\[$desc]\t[$taxon]\n");
      next;
    }
    $desc = "" unless (defined $desc);
    $seqinfo{$seqid}{'type'} = $type;
    $seqinfo{$seqid}{'description'} = $desc;
    $seqinfo{$seqid}{'taxon'} = $taxon;
    unless (defined $seqinfo{$seqid}{'index'}) {
      $max_member_index++;
      $seqinfo{$seqid}{'index'} = $max_member_index;
    }
  } else {
    warn "$desc_file has not the expected format
EXIT 2\n";
    exit 2;
  }
}

close DESC
  || die "$desc_file: $!";

print STDERR "Done\n";

print STDERR "Reading redundancies file...";
if ($redunfile =~ /\.gz/) {
  open REDUN, "gunzip -c $redunfile|" ||
    die "$redunfile: $!";
} else {
  open REDUN, $redunfile ||
    die "$redunfile: $!";
}

while (<REDUN>) {
  chomp;
  my @tab = split;
  my $refid = shift @tab;
  foreach my $id (@tab) {
    next if ($id eq $refid);
    $redun_hash{$refid}{$id} = 1;
  }
}

close REDUN;

print STDERR "Done\n";

print STDERR "Reading mcl file...";
if ($mcl_file =~ /\.gz/) {
  open MCL, "gunzip -c $mcl_file|" ||
    die "$mcl_file: $!";
} else {
  open MCL, $mcl_file ||
    die "$mcl_file: $!";
}

my $headers_off = 0;
my $one_line_members = "";

while (<MCL>) {
  if (/^begin$/) {
    $headers_off = 1;
    next;
  }
  next unless ($headers_off);
  last if (/^\)$/);
  chomp;
  $one_line_members .= $_;
  if (/\$/) {
    push @clusters, $one_line_members;
    $one_line_members = "";
  }
}

close MCL ||
  die "$mcl_file: $!";

print STDERR "Done\n";

print STDERR "Loading clusters in family db\n";

# starting to use the Family API here to load in a family database
# still print out description for each entries in order to determinate 
# a consensus description

my $max_cluster_index;

foreach my $cluster (@clusters) {
  my ($cluster_index, @cluster_members) = split /\s+/,$cluster;
  print STDERR "Loading cluster $cluster_index...";

  unless (defined $max_cluster_index) {
    $max_cluster_index = $cluster_index;
  } elsif ($cluster_index > $max_cluster_index) {
    $max_cluster_index = $cluster_index;
  }

  my $family_stable_id = sprintf ("$family_prefix%011.0d",$cluster_index + $family_offset);
  my $family = Bio::EnsEMBL::Compara::Family->new_fast
    ({
      '_stable_id' => $family_stable_id,
      '_source_name' => $family_source_name,
      '_description' => "NULL",
      '_description_score' => 0
     });
  
  foreach my $member_idx (@cluster_members) {
    last if ($member_idx =~ /^\$$/);
    my $seqid = $member_index{$member_idx};

    unless($seqid) {
      warn("no seqid defined for member [$member_idx]\n");
      next;
    }

    if(!$seqinfo{$seqid}) {
      warn("no seqinfo defined for [$seqid]\n");
      next;
    }
   
    if(!$seqinfo{$seqid}{'taxon'}) {
      warn("taxon is not defined for seqid [$seqid]");
      if($seqinfo{$seqid}) {
         map {warn( $_ . '=>' . $seqinfo{$seqid}{$_})} keys %{$seqinfo{$seqid}};
      }
      next;
    }

    my $taxon_hash = parse_taxon($seqinfo{$seqid}{'taxon'});
    my @classification = split(':',$taxon_hash->{'taxon_classification'});
    my $taxon = new Bio::EnsEMBL::Compara::Taxon->new(-classification=>\@classification);
    $taxon->common_name($taxon_hash->{'taxon_common_name'});
    $taxon->sub_species($taxon_hash->{'taxon_sub_species'});
    $taxon->ncbi_taxid($taxon_hash->{'taxon_id'});

    my $member = Bio::EnsEMBL::Compara::Member->new_fast
      ({'_stable_id' => $seqid,
        '_taxon_id' => $taxon->ncbi_taxid,
        '_taxon' => $taxon,
        '_description' => $seqinfo{$seqid}{'description'},
        '_source_name' => uc $seqinfo{$seqid}{'type'},
        '_genome_db_id' => "NULL",
        '_chr_name' => "NULL",
        '_chr_start' => "NULL",
        '_chr_end' => "NULL",
        '_sequence' => "NULL"});
    
    if ($member->source_name eq "ENSEMBLPEP" ||
        $member->source_name eq "ENSEMBLGENE") {
      #get genome_db_id
      my $genomedb = $genomedbs{$member->taxon_id};
      $member->genome_db_id($genomedb->dbID);
      #get chr_name, chr_start, chr_end
      my $core_db = $db->get_db_adaptor($genomedb->name, $genomedb->assembly);
      my $GeneAdaptor = $core_db->get_GeneAdaptor;
      my $TranscriptAdaptor = $core_db->get_TranscriptAdaptor;
      my $gene;
      my $transcript;

      if ($member->source_name eq "ENSEMBLPEP") {
        $transcript = $TranscriptAdaptor->fetch_by_translation_stable_id($member->stable_id);
        $transcript->transform('toplevel');
        $member->chr_name($transcript->slice->seq_region_name);
        $member->chr_start($transcript->coding_region_start);
        $member->chr_end($transcript->coding_region_end);
        $member->sequence($transcript->translate->seq); 
      } 
      elsif ($member->source_name eq "ENSEMBLGENE") {
        $gene = $GeneAdaptor->fetch_by_stable_id($member->stable_id);
        
        unless (defined $gene) {
          print STDERR $member->stable_id," ",$member->source_name," ",$member->taxon_id," is undef!!!\n";
          die;
        }
        $gene->transform('toplevel');
        $member->chr_name($gene->slice->seq_region_name);
        $member->chr_start($gene->slice->seq_region_start);
        $member->chr_end($gene->slice->seq_region_end);
      }
    }
    

    my $attribute = new Bio::EnsEMBL::Compara::Attribute;
    $attribute->cigar_line("NULL");
    
    $family->add_Member_Attribute([$member, $attribute]);
  }

  my $dbID = $fa->store($family);

  foreach my $member_attribute (@{$family->get_all_Member_Attribute}) {
    my ($member,$attribute) = @{$member_attribute};
    print $member->source_name,"\t$dbID\t",$member->stable_id,"\t",$seqinfo{$member->stable_id}{'description'},"\n";
    $seqinfo{$member->stable_id}{'printed'} = 1;
    if (defined $redun_hash{$member->stable_id}) {
      foreach my $member_stable_id (keys %{$redun_hash{$member->stable_id}}) {
        print uc($seqinfo{$member_stable_id}{'type'}),"\t$dbID\t$member_stable_id\t",$seqinfo{$member_stable_id}{'description'},"\n";
        $seqinfo{$member_stable_id}{'printed'} = 1;
      }
    } 
  }
  print STDERR "Done\n";
}

print STDERR "END\n";

sub parse_taxon {
  my ($str) = @_;

  $str=~s/=;/=NULL;/g;
  my %taxon = map {split '=',$_} split';',$str;

  return \%taxon;
}

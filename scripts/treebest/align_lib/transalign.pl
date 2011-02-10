#!/usr/local/bin/perl -w
# nucl_align.pl
#
# Creator: duwenfeng <duwf@genomics.org.cn>
# Date of creation: 2004.12.16
# Last modified :   2005-04-19
#
# 2005-04-19 lh3
#
#     * code clean up
#     * change name to transalign.pl
#     * improve which

use strict;
use Getopt::Long;

my $VER = '1.2'; 
my(%index_nucl, %align_prot);                                       # global variables

my %opts;
GetOptions(\%opts, "f", "e=s", "t");
&usage() if (@ARGV < 2);
my $pwalign = &which((defined($opts{e}))? $opts{e} : 'pwalign');
$pwalign .= ' -f' if (defined($opts{f}));
my $in_nucl = shift(@ARGV);
foreach my $in_prot (@ARGV) {
	my $prefix = $in_prot;
	my $fh_log;
	open($fh_log, ">$prefix.log") || die("Fail to write log file");
	&buildindex($in_nucl, $fh_log);
	&buildtmp($prefix, $in_nucl, $in_prot, $fh_log);
	&align($prefix, $pwalign, $in_nucl, $in_prot, $fh_log);
	unlink("$prefix.nucl.tmp", "$prefix.prot.tmp");
	unlink("$prefix.pwa", "$prefix.prot.mfa") unless(defined($opts{t}));
	close($fh_log);
}

#--------begin of subroutines--------

sub usage {
  print <<EOF; 

Program: transalign.pl (translate protein alignment to nucleotide alignment)
Version: $VER on 2005-04-19
Contact: Du Wenfeng and Li Heng <lh3\@sanger.ac.uk>

Usage  : transalign.pl [options] <nt_fasta> <aligned_aa_fasta1> [<aligned_aa_fasta2> ...]

Options: -f        use global alignment
         -t        reserve some temorary files
         -e STR    executable pwalign

EOF
  exit 1;
}

sub buildindex { # build gene index of nucleotide sequences
  my ($in_nucl, $fh_log) = @_;
  my $fh;
  open($fh, $in_nucl) || die("Fail to open $in_nucl");
  my $offset = 0;
  while(<$fh>) {
    ($_ =~ /^\s+$/) && next;
    if($_ =~ /^>/) {
      $offset = tell($fh);          # offset of the first sequence line below the title in file  
      chomp($_);
      my @title = split(/\s/, $_);  # title of sequence in FASTA format 
      my $id = substr($title[0],1); # retrieve nucl seq id
      (defined $index_nucl{$id}) && (print $fh_log ("$id multi define in nucl file\n"));
      $index_nucl{$id} = [$offset, $_];
    }
  }
  close($fh);
}

sub buildtmp { # build temporary files for nucleotide to protein align
  my ($prefix, $in_nucl, $in_prot, $fh_log) = @_;
  my ($fh_in_nucl, $fh_in_prot, $fh_tmp_nucl, $fh_tmp_prot);
  my ($id, @title, $desc, $prot_seq);
  my $out_prot = 0;                       # flag of output
  
  open($fh_tmp_nucl, ">$prefix.nucl.tmp") || die("Fail to create $prefix.nucl.tmp");
  open($fh_tmp_prot, ">$prefix.prot.tmp") || die("Fail to create $prefix.prot.tmp");
  open($fh_in_nucl, $in_nucl) || die("Fail to open $in_nucl");
  open($fh_in_prot, $in_prot) || die("Fail to open $in_prot");
  %align_prot = ();
  while (<$fh_in_prot>) {
    ($_ =~ /^\s+$/) && next;
    chomp($_);
    if($_ =~ /^>/) {
      # output previous prot seq
      ($out_prot == 1) && &out_prot_seq($fh_tmp_prot, $desc, $prot_seq);
      # retrieve id of current prot seq
      @title = split(/\s/, $_);
      $id = substr($title[0], 1); 
      if(defined $index_nucl{$id}) { # prot seq has corresponding nucl seq
        $out_prot = 1;                    # set flag of output
        $desc = $_;                       # store title of prot seq into desc
        $prot_seq = "";
        # retrive nucl seq and output to temp file
        seek($fh_in_nucl, $index_nucl{$id}[0], 0);
        print $fh_tmp_nucl (">$id\n");
        while(<$fh_in_nucl>) {
          ($_ =~ /^\s+$/) && next;
          ($_ =~ /^>/) && last;
          print $fh_tmp_nucl ($_);
        }
      } else {                            # prot seq has NO corresponding nucl seq
        $out_prot = 0;
        print $fh_log ("$in_prot $id no corresponding nucleic acid sequence.\n");
      }
    } else {
      ($out_prot == 1) && ($prot_seq .= $_);
    }
  }
  ($out_prot == 1) && &out_prot_seq($fh_tmp_prot, $desc, $prot_seq);
  
  close($fh_in_nucl);
  close($fh_in_prot);
  close($fh_tmp_nucl);
  close($fh_tmp_prot);
}
sub out_prot_seq { # remove '-' in prot seq, output to given file handle, store title and seq in prot hash
  my ($fh, $desc, $seq) = @_;
  ($fh eq '') && usage(5, 'write to file error');
  my @title = split(/\s/, $desc);
  $seq =~ s/[^\w\-\.]//g;
  $align_prot{substr($title[0], 1)} = [($desc, $seq)];
  $seq =~ s/-//g;
  my $base_num = ($seq =~ tr/a-zA-Z//); # count base num in prot seq
  print $fh ("$desc\n");
  my $pos = 0;
  while($pos < $base_num) {
    (defined (my $seq_part = substr($seq, $pos, 60))) || last;
    print $fh ($seq_part."\n");
    $pos += 60;
  } 
}

sub align { # nucleotide to protein align
  my ($prefix, $pwalign, $in_nucl, $in_prot, $fh_log) = @_;
  my ($pos_nucl, $phase);
  my ($fh_out_nucl, $fh_out_prot, $fh_result, $fh_out_result);
   
  open($fh_out_nucl, ">$prefix.nucl.mfa") || die("Fail to create $prefix.nucl.mfa");
  open($fh_out_prot, ">$prefix.prot.mfa") || die("Fail to create $prefix.prot.mfa");
  open($fh_out_result, ">$prefix.pwa") || die("Fail to create $prefix.pwa");
  open($fh_result, "$pwalign nt2aa $prefix.nucl.tmp $prefix.prot.tmp |") || die("Fail to execute $pwalign");
  
  while(<$fh_result>) {
    print $fh_out_result $_;
    ($_ =~ /^\s+$/) && next;
    chomp($_);
    if($_ =~ /^>/) {
      my @title = split(/\s/, $_); # first line in pwalign result
      my $id_nucl = substr($title[0], 1);
      my $id_prot = $title[4];
      
      my $seq_ali_prot = $align_prot{$id_prot}[1]; # prot seq of multi align
      chomp(my $seq_nucl = <$fh_result>);                     # nucl seq of nt2aa align
      chomp(my $seq_match = <$fh_result>);                    # nt2aa align information
      chomp(my $seq_prot = <$fh_result>);                     # prot seq of nt2aa align
	  print $fh_out_result "$seq_nucl\n$seq_match\n$seq_prot\n";
      # seperate seq into array of bases
      my @array_ali_prot = split(//, $seq_ali_prot);
      my @array_nucl = split(//, $seq_nucl);
      my @array_prot = split(//, $seq_prot);
      # print title of seq, same as those in input nucl and prot seq files
      print $fh_out_nucl ("$index_nucl{$id_nucl}[1]\n");
      print $fh_out_prot ("$align_prot{$id_prot}[0]\n");
      # get nucl seq correspond to original prot seq     
      for($pos_nucl = 0; $pos_nucl < @array_nucl; $pos_nucl++) {
        if($array_prot[$pos_nucl] eq "!") {               # remove '!' in prot and nucl seq
          splice(@array_prot, $pos_nucl, 1);
          splice(@array_nucl, $pos_nucl, 1);
          print $fh_log ("$id_nucl $pos_nucl deleted\n");
          $pos_nucl--;
        } elsif($array_prot[$pos_nucl] eq "-") {          # remove bases correspond to '-' in prot seq
          splice(@array_prot, $pos_nucl - 2, 3);
          splice(@array_nucl, $pos_nucl - 2, 3);
          print $fh_log ("$id_nucl $pos_nucl 3bases deleted\n");
          $pos_nucl -= 3;
        }
      }
      # print out leading hyphen(-) in multi-align prot seq
      my $index_nucl = 0;                                 # number of outputed nucl base
      my $index_prot = 0;                                 # number of outputed prot base, pointer of base in array_ali_prot
      &out_hyphen(0, $array_prot[2], $fh_out_nucl, $fh_out_prot, \$index_nucl, \$index_prot, \@array_ali_prot);

      $pos_nucl = 0;                                      # pointer of base in array_nucl(prot)  
      while($pos_nucl < @array_nucl) {
        if($array_prot[$pos_nucl + 2] eq $array_ali_prot[$index_prot]) {
          for($phase = 0; $phase < 3; $phase++) {         # output 3 nucl base and 1 aminoacid  
            $index_nucl++;
            print $fh_out_nucl ($array_nucl[$pos_nucl]);
            (($index_nucl % 60) == 0) && print $fh_out_nucl ("\n");
                    
            if($array_prot[$pos_nucl] ne ".") {
              $index_prot++;
              print $fh_out_prot ($array_prot[$pos_nucl]);
              (($index_prot % 60) == 0) && print $fh_out_prot ("\n");
            }
            $pos_nucl++;
          }
        } elsif($array_ali_prot[$index_prot] eq "-") {   # '-' in multi-align prot, output '-' to prot and '---' to nucl
          &out_hyphen(0, $array_prot[$pos_nucl + 2], $fh_out_nucl, $fh_out_prot, \$index_nucl, \$index_prot, \@array_ali_prot);
        } else {                                         # failed to match nt2aa aligned prot with original prot
          print $fh_log ("$array_prot[$pos_nucl + 2] $array_ali_prot[$index_prot] at $index_prot\n");
          print $fh_out_nucl ("---");
          print $fh_out_prot ("-");
          $index_prot++;
          $pos_nucl += 3;
        }
      }
      
      &out_hyphen(1, 0, $fh_out_nucl, $fh_out_prot, \$index_nucl, \$index_prot, \@array_ali_prot);
      (($index_nucl % 60) != 0) && print $fh_out_nucl ("\n");
      (($index_prot % 60) != 0) && print $fh_out_prot ("\n");
    }
  }
  close($fh_result);
  close($fh_out_nucl);
  close($fh_out_prot);
  close($fh_out_result);
}

sub out_hyphen {
  # output bases in @$ref_ali_array to $fh_prot and '---' to $fh_nucl. 
  # if $toend is 0, from $$ref_ind_p to first base equal to $target.
  # if $toend is 1, from $$ref_ind_p to end of @$ref_ali_array
  # $$ref_ind_p: number of outputed base of prot, $$ref_ind_n: number of outputed base of nucl   
  my ($toend, $target, $fh_nucl, $fh_prot, $ref_ind_n, $ref_ind_p, $ref_ali_array) = @_;
  my ($pos, $phase);
  
  for($pos = $$ref_ind_p; $pos < @$ref_ali_array; $pos++) {
    ($toend == 0) && ($ref_ali_array->[$pos] eq $target) && last;

    for($phase = 0; $phase < 3; $phase++) {
      $$ref_ind_n ++;
      print $fh_nucl ("-");
      (($$ref_ind_n % 60) == 0) && print $fh_nucl ("\n");
    }
    
    $$ref_ind_p++;
    print $fh_prot ($ref_ali_array->[$pos]);
    (($$ref_ind_p % 60) == 0) && print $fh_prot ("\n");
  }
}
#
# locate a excutable program
#
sub which
{
	my ($progname) = @_;
	my $dirname = &dir_name($0);
	my $tmp;

	chomp($dirname);
	if ($progname =~ /^\// && (-x $progname)) {
		return $progname;
	} elsif (-x "./$progname") {
		return "./$progname";
	} elsif (-x "$dirname/$progname") {
		return "$dirname/$progname";
	} elsif (($tmp = &my_which($progname)) ne "") {
		return $tmp;
	} else {
		warn("[which()] fail to find executable $progname anywhere.");
		return;
	}
}
sub dir_name
{
	my ($prog) = @_;
	return '.' if (!($prog =~ /\//));
	$prog =~ s/\/[^\s\/]+$//;
	return $prog;
}
sub my_which
{
	my ($file) = @_;
	return "" if (!defined($ENV{PATH}));
	foreach my $x (split(":", $ENV{PATH})) {
		$x =~ s/\/$//;
		return "$x/$file" if (-x "$x/$file");
	}
}

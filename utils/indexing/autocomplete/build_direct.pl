#! /usr/bin/env perl

use strict;
use warnings;

use FindBin qw($Bin);

die "Please specify path to xml files" unless $ARGV[0];

my $files = qx{ find $ARGV[0] -name \\*_Phenotype.xml -or -name \\*_Gene.xml };

my %doc;
foreach my $file (split("\n",$files)) {
  chomp $file;
  print STDERR "Examining $file\n";
  unless(open(FILE,$file)) {
    print STDERR "No such file '$file'\n";
    next;
  }
  while(<FILE>) {
    if(/<doc/) { %doc = (); }
    elsif(/<field name="feature_type">(.*?)<\/field>/) { $doc{'type'} = $1; }
    elsif(/<field name="species_name">(.*?)<\/field>/) { $doc{'species'} = $1; }
    elsif(/<field name="name">(.*?)<\/field>/) { $doc{'name'} = $1; }
    elsif(/<field name="id">(.*?)<\/field>/) { $doc{'id'} = $1; }
    elsif(/<field name="domain_url">(.*?)<\/field>/) { $doc{'url'} = $1; }
    elsif(/<\/doc/) {
      next unless $doc{'type'} eq 'Gene' or $doc{'type'} eq 'Phenotype';
      next unless $doc{'name'} and $doc{'species'} and $doc{'url'};
      $doc{'species'} = lc($doc{'species'});
      $doc{'lcname'} = lc($doc{'name'});
      $doc{'species'} =~ s/\s/_/g;
      $doc{'name'} =~ s/\s/_/g;
      print join('__',map { $doc{$_} } qw(species lcname type id name url))."\n";
    }
  }
  close FILE;
}

1;


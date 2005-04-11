#!/usr/local/ensembl/bin/perl -w

use strict;

my $description = q{
###########################################################################
##
## PROGRAM fastafetch.pl
##
## AUTHORS
##    Javier Herrero (jherrero@ebi.ac.uk)
##
## COPYRIGHT
##    This script is part of the Ensembl project http://www.ensembl.org
##
## DESCRIPTION
##    This script takes a FASTA file, a index file and a file with IDs
##    and creates another FASTA file containing the sequences
##    corresponding to the IDs specified in the third file
##
###########################################################################

};

=head1 NAME

fastafetch.pl

=head1 AUTHORS

Javier Herrero (jherrero@ebi.ac.uk)

=head1 COPYRIGHT

This script is part of the Ensembl project http://www.ensembl.org

=head1 DESCRIPTION

This script takes a FASTA file, a index file and a file with IDs
and creates another FASTA file containing the sequences
corresponding to the IDs specified in the third file

=head1 SYNOPSIS

perl fastafetch.pl --help

perl fastafetch.pl index_file ids_file

=head1 OPTIONS

=head2 GETTING HELP

=over

=item B<[--help]>

  Prints help message and exits.

=back

=head2 GENERAL CONFIGURATION

=over

=item B<>



=back


=cut

use Bio::EnsEMBL::Utils::Exception qw(throw warning);

my $usage = qq{
perl fastafetch.pl --help|-h

perl fastafetch.pl fasta_file index_file ids_file
};

my $help;

my $fasta_file;
my $index_file;
my $ids_file;
if (@ARGV) {
  if (($ARGV[0] eq "--help") or ($ARGV[0] eq "-h")) {
    print $description, $usage;
    exit(0);
  } elsif (@ARGV == 2) {
    $index_file = $ARGV[0];
    $ids_file = $ARGV[1];
  } else {
    print $usage;
    exit(1);
  }
} else {
  print $usage;
  exit(1);
}

#if (!-e $fasta_file or !open(FASTA, $fasta_file)) {
#  throw("Cannot open $fasta_file");
#}
#
if (!-e $index_file or !open(INDEX, $index_file)) {
  throw("Cannot open $index_file");
}

if (!-e $ids_file or !open(IDS, $ids_file)) {
  throw("Cannot open $ids_file");
}

my @ids;
while (<IDS>) {
  $_ =~ s/[\r\n]+$//;
  push(@ids, $_);
}
close(IDS);

my $index;
while (<INDEX>) {
  $_ =~ s/[\r\n]+$//;
  my ($id, $file, $pos) = $_ =~ /(\S+)\s+(\S+)\s+(\d+)/;
#  print "$id, $file, $pos\n";
  $index->{$id}->{file} = $file;
  $index->{$id}->{pos} = $pos;
}

my $fhs;
foreach my $id (@ids) {
  my $file = $index->{$id}->{file};
  my $pos = $index->{$id}->{pos};
  if (!defined($fhs->{$file})) {
    open($fhs->{$file}, $file);
  }
  my $fh = $fhs->{$file};
  seek($fh, $pos, 0);
  print ">";
  while (defined($_ = <$fh>) and $_ !~ /^>/) {
    print $_;
  }
}

foreach my $fh (values %$fhs) {
  close($fh);
}

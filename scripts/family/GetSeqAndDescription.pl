#!/usr/local/ensembl/bin/perl -w

use strict;
use Getopt::Long;
use Bio::SeqIO;

my $USAGE =<<END;

This script creates the description and fasta files necessary for the protein family pipeline
from SWISSPROT and SPTEMBL formatted files

Dependancy on Bio:Species from bioperl-1-2

Usage: GetSeqAndDescription.pl -swiss  path_to_swissprot_peptides_file 
                               -sptrembl path_to_sptrembl_peptide_file
                               -fasta  file name for the dumped FASTA file
                               -desc   file name for the dumped description file from swissprot and trembl entires
                               -help    displays this help


END

my ($SWISS,$TREMBL,$FASTA,$DESC,$HELP);

GetOptions('swiss=s'  => \$SWISS,
	   'sptrembl=s' => \$TREMBL,
	   'fasta=s'  => \$FASTA,
	   'desc=s'   => \$DESC,
	   'help'     => \$HELP
	  ) or die $USAGE;

$HELP && die $USAGE;

$SWISS || die $USAGE;
$TREMBL || die $USAGE;

my $pep_file = $FASTA||"swiss_trembl.fa";
my $desc_file      = $DESC || "family.desc"; 

my $swiss_file = $SWISS;
-e $swiss_file || die("$swiss_file doesn't exist");

print STDERR "Using swissprot file $swiss_file\n";

my $sptrembl_file = $TREMBL;

-e $sptrembl_file || die("$sptrembl_file doesn't exist");

print STDERR "Using sptrembl file $sptrembl_file\n";

#create description file for swissprot and sptrembl files
#as well as peptide files in fasta format

print STDERR "Creating swissprot description file and fasta file\n";

my ($swiss_desc,$swiss_fasta) = &print_swiss_format_file('swissprot',$swiss_file);

print STDERR "Creating sptrembl description file and fasta file\n";

my ($sptrembl_desc,$sptrembl_fasta) = &print_swiss_format_file('sptrembl',$sptrembl_file);

print STDERR "Creating $desc_file\n";
system("cat $swiss_desc $sptrembl_desc |gzip -c > $desc_file.gz"); 
unlink $swiss_desc;
unlink $sptrembl_desc;

#create blast peptide file

print STDERR "Creating peptide file for blasting $pep_file\n";
system("cat $swiss_fasta $sptrembl_fasta |gzip -c > $pep_file.gz");

unlink $swiss_fasta;
unlink $sptrembl_fasta;

print STDERR "Setup Completed for peptide files\n";

print "****************************************************************\n";
print STDERR "Swissprot and Trembl Description file : $desc_file.gz\n";
print STDERR "Swissprot and Trembl Fasta file       : $pep_file.gz\n";

print STDERR "You may now proceed to cat the ensembl peptides to $pep_file.gz\n";
print "****************************************************************\n";



sub print_swiss_format_file {
    my ($db,$file) = @_;

    my $rand = time().rand(1000);
    
    if ($file =~ /\.gz/) {
      open FILE,"gunzip -c $file |" ||
	die "can't open $file: $!";
    } else {
      open FILE,"cat $file |" ||
	die "can't open $file: $!"; 
    }
    my $sio = Bio::SeqIO->new(-fh=>\*FILE,-format=>"swiss");
    
    my $desc_file = $file.".".$rand.".desc";
    my $fasta_file = $file.".".$rand.".pep";
    my $sout = Bio::SeqIO->new(-file=>">$fasta_file",-format=>"fasta");
    open (DESC, ">$desc_file");
    while (my $seq = $sio->next_seq){
        my $species = $seq->species;
        if($species){
	  my $sub_species = "";
	  if (defined $species->sub_species) {
	    $sub_species = $species->sub_species;
	  }
	  unless (defined $species->common_name) {
	    $species->common_name("");
	  }
          my $taxon_str = "taxon_id=".$species->ncbi_taxid.";taxon_genus=".$species->genus.
                          ";taxon_species=".$species->species.";taxon_sub_species=".
                          $sub_species.";taxon_common_name=".
                          $species->common_name.";taxon_classification=".join(":",$species->classification);

        print DESC $db."\t".$seq->display_id."\t".$seq->desc."\t".$taxon_str."\n";
        $sout->write_seq($seq);
        }
    }
    close DESC;
    close FILE;

    return ($desc_file,$fasta_file);
}





#!/usr/local/bin/perl -w

# Dump EnsEMBL families into FASTA files, one file per family
# by not using the Compara API (for speed)

use strict;
use Getopt::Long;
use DBI;

my $ens_only     =  0;    # allow Uniprot members as well
my $fasta_len    = 72;    # length of fasta lines
my $db_version   = 57;    # needs to be set manually while compara is in production
my $target_dir   = "family${db_version}_fast_dumps";     # put them there

GetOptions(
    'ens_only!'      => \$ens_only,
    'fasta_len=i'    => \$fasta_len,
    'db_ver=i'       => \$db_version,
    'target_dir=s'   => \$target_dir,
);

mkdir($target_dir);

my $sql = qq{SELECT f.stable_id, f.version, m.stable_id, m.version, m.description, m.taxon_id, g.name, s.sequence
               FROM family f
               JOIN family_member fm USING (family_id)
               JOIN member m USING (member_id)
               JOIN sequence s USING (sequence_id)
          LEFT JOIN genome_db g USING (genome_db_id)
    }.  ( $ens_only ? qq{ WHERE m.source_name='ENSEMBLPEP' } : '' );

warn "Sending the request...\n";

my $dbh= DBI->connect("DBI:mysql:host=ensembldb.ensembl.org;port=5306;database=ensembl_compara_${db_version};mysql_use_result=1", 'anonymous', '');

my $sth = $dbh->prepare($sql);
$sth->execute();

warn "...done\n\n";

while(my($f_stable_id, $f_version, $m_stable_id, $m_version, $m_description, $m_taxon_id, $g_name, $seq) = $sth->fetchrow()) {

    my $family_name = $f_stable_id.'.'.$f_version;
    my $file_name   = "$target_dir/$family_name.fasta";

    warn "----> $file_name\n";

    open(OUTFILE, ">>$file_name");

    print OUTFILE ">$m_stable_id".($m_version ? '.'.$m_version : '').' ['.($g_name or 'taxon_id='.$m_taxon_id)."] $m_description\n";

    $seq=~ s/(.{$fasta_len})/$1\n/g;
    chomp $seq;
    print OUTFILE $seq."\n";

    close OUTFILE;
}

$sth->finish();

warn "DONE DUMPING\n\n";


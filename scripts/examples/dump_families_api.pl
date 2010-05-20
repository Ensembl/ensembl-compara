#!/usr/local/bin/perl -w

# Dump EnsEMBL families into FASTA files, one file per family.
#
# DO NOT USE it to dump the whole lot, as you will blow the memory on your computer and likely to lose patience.
# It is more of an example of how to use the API to do things, but it is not optimal for dumping all and everything.

use strict;
use Getopt::Long;
use Bio::EnsEMBL::Registry;

my $continue     =  0;    # skip already dumped families
my $ens_only     =  0;    # allow Uniprot members as well
my $fasta_len    = 72;    # length of fasta lines
my $db_version   = 57;    # needs to be set manually while compara is in production
my $min_fam_size =  1;    # set to 2 to exclude singletons (or even higher)
my $target_dir   = "family${db_version}_dumps";     # put them there

GetOptions(
    'continue!'      => \$continue,
    'ens_only!'      => \$ens_only,
    'fasta_len=i'    => \$fasta_len,
    'db_ver=i'       => \$db_version,
    'min_fam_size=i' => \$min_fam_size,
    'target_dir=s'   => \$target_dir,
);

Bio::EnsEMBL::Registry->load_registry_from_db(
    '-host'       => 'ensembldb.ensembl.org',
    '-user'       => 'anonymous',
    '-db_version' => $db_version,
);

my $family_adaptor = Bio::EnsEMBL::Registry->get_adaptor('multi', 'compara', 'family');

my $families = $family_adaptor->fetch_all();

warn "Creating directory '$target_dir'\n";
mkdir($target_dir);

foreach my $f (@$families) {

    my $family_name = $f->stable_id().'.'.$f->version();
    my $file_name   = "$target_dir/$family_name.fasta";

    if($continue and (-f $file_name)) {
        warn "[Skipping existing $file_name]\n";
        next;
    }

    my $members = $ens_only
        ? [ map { $_->[0] } @{$f->get_Member_Attribute_by_source('ENSEMBLPEP')} ]
        : [ grep { $_->sequence() } @{$f->get_all_Members()} ];

    next if(scalar(@$members) < $min_fam_size);

    open(FAM, ">$file_name") || die "Could not create file $file_name'";
    
    warn "$file_name (".scalar(@$members)." members)\n";

    foreach my $m (@$members) {
        print FAM '>'.$m->stable_id().($m->version ? '.'.$m->version : '').' ['.($m->genome_db_id ? $m->genome_db->name : 'taxon_id='.$m->taxon_id).'] '.$m->description()."\n";

        my $seq = $m->sequence();
        $seq=~ s/(.{$fasta_len})/$1\n/g;
        chomp $seq;
        print FAM $seq."\n";

        $m->sequence(undef);    # do not cache sequences
    }

    close FAM;
}

warn "DONE DUMPING\n\n";


package EnsEMBL::Web::Document::HTML::FTPtable;

### This module outputs a table of links to the FTP site

use strict;
use warnings;

use EnsEMBL::Web::RegObj;
use base qw(EnsEMBL::Web::Root);


{

sub render {
  my $self = shift;

  my $species_defs = $ENSEMBL_WEB_REGISTRY->species_defs;

  my $rel = $ENV{'ENSEMBL_SERVERNAME'} =~ 'archive' ? 'release-'.$ENV{'VERSION'} : 'current';

  my $html = qq(
<table class="ss tint" cellpadding="4">

<tr>
<th>Species</th>
<th colspan="8" style="text-align:center">Files</th>
</tr>

);
  my @species = $species_defs->valid_species;
  my $row = 0;
  my $class;
  foreach my $spp (sort @species) {
    (my $sp_name = $spp) =~ s/_/ /;
     my $sp_dir =lc($spp);
     my $sp_var = lc($spp).'_variation';
     my $common = $species_defs->get_config($spp, 'SPECIES_COMMON_NAME');
     my $emf = '-';
    if ($sp_dir =~ /homo_sapiens|mus_musculus|rattus_norvegicus/) {
      $emf = qq(<a rel="external" title="Variation and comparative data" href="ftp://ftp.ensembl.org/pub/).$rel.qq(_emf/$sp_var/">EMF</a>);
    }
    $class = $row % 2 == 0 ? 'bg1' : 'bg2';

    $html .= qq(
<tr class="$class">
<td><strong><i>$sp_name</i></strong> ($common)</td>
<td><a rel="external" href="ftp://ftp.ensembl.org/pub/).$rel.qq(_fasta/$sp_dir/dna/">FASTA</a> (DNA)</td>
<td><a rel="external" href="ftp://ftp.ensembl.org/pub/).$rel.qq(_fasta/$sp_dir/cdna/">FASTA</a> (cDNA)</td>
<td><a rel="external" href="ftp://ftp.ensembl.org/pub/).$rel.qq(_fasta/$sp_dir/pep/">FASTA</a> (protein)</td>
<td><a rel="external" href="ftp://ftp.ensembl.org/pub/).$rel.qq(_embl/$sp_dir/">EMBL</a></td>
<td><a rel="external" href="ftp://ftp.ensembl.org/pub/).$rel.qq(_genbank/$sp_dir/">GenBank</a></td>
<td><a rel="external" href="ftp://ftp.ensembl.org/pub/).$rel.qq(_mysql/">MySQL</a></td>
<td><a rel="external" href="ftp://ftp.ensembl.org/pub/).$rel.qq(_gtf/">GTF</a></td>
<td>$emf</td>
</tr>
      );
    $row++;
  }
  my $rev = $class eq 'bg2' ? 'bg2' : 'bg1';
  $class = $class eq 'bg2' ? 'bg1' : 'bg2';
  $html .= qq(
<tr class="$class">
<td><strong>Multi-species</strong></td>
<td>-</td>
<td>-</td>
<td>-</td>
<td>-</td>
<td>-</td>
<td><a rel="external" href="ftp://ftp.ensembl.org/pub/).$rel.qq(_mysql/">mySQL</a></td>
<td>-</td>
<td><a rel="external" href="ftp://ftp.ensembl.org/pub/).$rel.qq(_emf/">EMF</a></td>
</tr>
<tr class="$rev">
<td><strong>Ensembl Mart</strong></td>
<td>-</td>
<td>-</td>
<td>-</td>
<td>-</td>
<td>-</td>
<td><a rel="external" href="ftp://ftp.ensembl.org/pub/).$rel.qq(_mysql/">mySQL</a></td>
<td>-</td>
<td>-</td>
</tr>
</table>
  );

  return $html;
}

}

1;
